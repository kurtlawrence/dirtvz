import * as BABYLON from "@babylonjs/core";
import { Camera } from './camera';
import { Store, Tile } from "./../store";
import { ViewableTiles, Extents3 } from './../wasm';
import { Layers } from "./layers";
import { Light } from './light';
import { Color4, Scene } from "@babylonjs/core";
import { SpatialObject } from "../spatial-obj";

export class Viewer {
    canvas: HTMLCanvasElement;
    engine: BABYLON.Engine;
    scene: Scene;
    camera: Camera;
    light: Light;
    store: Store;
    layers: Layers;
    tiler?: ViewableTiles;
    _hover: Hover;
	_viewts?: number;

	private static TILE_LOD_TIMEOUT: number = 200; // wait before loading

    private constructor(canvas: HTMLCanvasElement, store: Store) {
        this.canvas = canvas;
        this.engine = new BABYLON.Engine(canvas);
        this.scene = new Scene(this.engine);
        this.camera = new Camera(this.scene);
        this.light = new Light(this.scene, this.camera);
        this.store = store;
        this.layers = new Layers(this.scene);
        this._hover = new Hover(this.scene);
    }

    /**
     * Create and attach viewer engine to a canvas element.
     *
     * @param canvas The element to render to.
     * @param db_name The name of the database to connect to. Databases can be shared
     * amongst viewers. Each database defines a data extents for which objects are
     * translated about.
     */
    static async init(
        canvas: HTMLCanvasElement,
        db_name: string
    ): Promise<Viewer> {
        const store = await Store.connect(db_name);
        const vwr = new Viewer(canvas, store);
        // await vwr.engine.initAsync(); // needed for WGPU engine

        // transparent background
        vwr.scene.clearColor = new Color4(0, 0, 0, 0);

        vwr.camera.init()
            .attachZoomControl(canvas)
            .attachPanControl(canvas)
            .attachRotateControl(canvas);

        canvas.addEventListener('pointermove', _ => { vwr._hover.pointermove() });

        // Render every frame
        vwr.engine.runRenderLoop(() => {
            vwr.scene.render();
        });

        const extents = await store.extents() ?? Extents3.zero_to_one();
        vwr.camera.zoomDataExtents(extents, canvas);
        vwr.init_tiler();
        vwr._hover.extents = extents;
        vwr.camera.toggle_world_axes(canvas);
		vwr.camera.onviewchg = _ => vwr.view_chgd();

        vwr.set_background({ty: 'linear', colours: ['oldlace', 'dimgrey']});

        return vwr;
    }

    private async init_tiler(): Promise<ViewableTiles | undefined> {
        if (!this.tiler) {
            let xs = await this.store.extents();
            if (xs) {
                const viewbox = this.camera.viewbox(this.canvas, xs);
                this.tiler = ViewableTiles.new(xs);
				this.tiler.update(viewbox.extents, new Float64Array(viewbox.view_dir.asArray()));
            }
        }

        return this.tiler;
    }

    async toggle_object(key: string) {
        if (this.layers.is_loaded(key)) {
        } else {
            if (await this.init_tiler())
                this.load_object(key);
        }
    }

    private async load_object(key: string) {
        if (!this.tiler)
            return;

        const sobj = await this.store.find_object(key);
        if (!sobj)
            return;

        const extents = await this.store.extents();
        if (!extents)
            return;

        this.layers.add_loaded(key);

        const viewable_tiles = this.tiler.in_view_tiles();
        const viewable_lods = this.tiler.in_view_lods();

        for (let i = 0; i < viewable_tiles.length; i++) {
            const tile_idx = viewable_tiles[i];
			const lod = viewable_lods[i];
			await this.load_object_tile(sobj, tile_idx, lod, extents);
        }
    }

    onhover(cb: HoverCb) {
        this._hover.action = cb;
    }

    set_background(bg: Background) {
        switch (bg.ty) {
            case 'linear':
                this.canvas.style.background = "linear-gradient(" + bg.colours.join(',') + ")";
                break;
        
            default:
                break;
        }

    }

	private view_chgd() {
		this._viewts = Date.now() + Viewer.TILE_LOD_TIMEOUT;
		const cb = () => {
			if (!this._viewts || Date.now() < this._viewts)
				return;
			this._viewts = undefined;
			this.update_in_view_tiles();
		};
        setTimeout(cb, Viewer.TILE_LOD_TIMEOUT + 5); // immediate re-render
		setTimeout(cb, 1000); // check again after a second
	}

	private async update_in_view_tiles() {
		if (!this.tiler) {
			// tiler not initialised, fire off to initialise it and return, not waiting
			// a subsequent update will process it
			this.init_tiler();
			return;
		}

		const extents = await this.store.extents();
		if (!extents)
			return;

		const viewbox = this.camera.viewbox(this.canvas, extents);
		this.tiler.update(viewbox.extents, new Float64Array(viewbox.view_dir.asArray()));

        const viewable_tiles = this.tiler.in_view_tiles();
        const viewable_lods = this.tiler.in_view_lods();
		const layers = this.layers;

		console.debug(viewable_tiles);

		let loaded;

        for (let i = 0; i < viewable_tiles.length; i++) {
            const tile_idx = viewable_tiles[i];
			const lod_res = viewable_lods[i];

			const tiles = layers.inview(tile_idx);
			if (tiles) {
				// tile already in view, check if lod idx has changed
				for (const t of tiles) {
					const lod = choose_lod(t.store_tile, lod_res);
					if (lod.idx == t.lod_idx)
						continue; // no change

					const zs = await this.store.get_lod(t.objkey, tile_idx, lod.idx);
					if (zs)
						t.update_mesh(zs, extents);
				}
			} else {
				// tile is not in view, populate with loaded objects
				// cache the sobjs to reduce hitting the db
				if (!loaded) {
					loaded = [];
				    for (const key of layers.loaded) {
						const x = await this.store.find_object(key);
						if (x) loaded.push(x);
					}
				}

				for (const obj of loaded) {
					await this.load_object_tile(obj, tile_idx, lod_res, extents);
				}
			}
        }
		
		// lastly, remove out of view meshes
		// do last since it does not affect viewing
		layers.unload_out_of_view_tiles(viewable_tiles);
	}

	private async load_object_tile(obj: SpatialObject, tile_idx: number, lod_res: number, extents: Extents3) {
            // check that object has tile
            if (!obj.tiles.includes(tile_idx))
                return;

            const tile = await this.store.get_tile(obj.key, tile_idx);
            if (!tile)
                return;

            const lod = choose_lod(tile, lod_res);
            const zs = await this.store.get_lod(obj.key, tile_idx, lod.idx);
            if (zs)
                this.layers.add_surface_tile(obj.key, tile, lod.idx, zs, extents);
	}
}

function choose_lod(tile: Tile, res: number) {
    // we leverage the fact that these are ordered in _ascending resolution_.
    // the choice is the minimum res **greater** than the request res.
    const lods = tile.lods;
    return lods.find(x => x.res >= res) ?? lods[lods.length - 1];
}

function update_in_view_tiles(vwr: Viewer) {
}

class Hover {
    action: HoverCb;
    scene: Scene;
    extents?: Extents3;
    ts?: number;

    private static TIMEOUT = 10;

    constructor(scene: Scene) {
        this.action = _ => { };
        this.scene = scene;
    }

    pointermove() {
        this.ts = Date.now() + Hover.TIMEOUT;
        const x = this.scene.pointerX;
        const y = this.scene.pointerY;

        setTimeout(() => this.callback(x, y), Hover.TIMEOUT);
    }

    callback(x: number, y: number) {
        if (!this.ts || !this.extents || Date.now() < this.ts)
            return;

        this.ts = undefined;

        const pick = this.scene.pick(x, y, undefined, false); // get closest

        let render_pt;
        if (pick.pickedPoint) {
            const pt = pick.pickedPoint;
            render_pt = {
                x: pt.x,
                y: pt.y,
                z: pt.z,
            };
        }

        let world_pt;
        if (render_pt) {
            let p = this.extents.render_to_world(render_pt.x, render_pt.y, render_pt.z);
            world_pt = {
                x: p.x,
                y: p.y,
                z: p.z
            };
        }

        let mesh_name;
        if (pick.pickedMesh) {
            mesh_name = pick.pickedMesh.name;
        }

        const info = {
            pointerx: x,
            pointery: y,
            render_pt,
            world_pt,
            mesh_name
        };

        this.action(info);
    }
}

type HoverCb = (info: HoverInfo) => void;

export type HoverInfo = {
    pointerx: number,
    pointery: number,
    render_pt?: Xyz,
    world_pt?: Xyz,
    mesh_name?: string
}

export type Xyz = {
    x: number,
    y: number,
    z: number
}

export type Background = {
    ty: 'single' | 'linear' | 'radial',
    colours: string[]
};
