import * as BABYLON from "@babylonjs/core";
import { Camera } from './camera';
import { Store } from "./../store";
import { ViewableTiles, Extents3, TileId } from './../wasm';
import { Layers } from "./layers";
import { Light } from './light';
import { Color4, Scene } from "@babylonjs/core";


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
    _dirty: boolean = true;
    extents: Extents3 = Extents3.zero_to_one();

    private static TILE_LOD_TIMEOUT: number = 200; // wait before loading

    private constructor(canvas: HTMLCanvasElement, store: Store) {
        this.canvas = canvas;
        this.engine = new BABYLON.Engine(canvas);
        this.scene = new Scene(this.engine);
        this.camera = new Camera(this.scene);
        this.light = new Light(this.scene, this.camera);
        this.store = store;
        this.layers = new Layers(store, this.scene);
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

        vwr.scene.render(); // do initial render

        // render at 60 fps
        setInterval(() => vwr.maybe_render(), 1000 / 60);
        // Render every frame
        // vwr.engine.runRenderLoop(() => vwr.maybe_render());

        const extents = await store.extents();
        if (extents)
            vwr.extents = extents;

        vwr.init_tiler();
        vwr._hover.extents = vwr.extents;
        vwr.camera.onviewchg = _ => vwr.view_chgd();
        vwr.camera.inner.update();
        vwr.camera.toggle_world_axes(canvas);
        vwr.camera.zoomDataExtents(vwr.extents, canvas);

        vwr.set_background({ ty: 'linear', colours: ['oldlace', 'dimgrey'] });

        return vwr;
    }

    private init_tiler(): ViewableTiles | undefined {
        if (!this.tiler) {
            const xs = this.extents;
            const viewbox = this.camera.viewbox(this.canvas, xs);
            this.tiler = ViewableTiles.new(xs);
            this.tiler.update(viewbox);
        }

        return this.tiler;
    }

    mark_dirty() { this._dirty = true; }

    private maybe_render() {
        const needs_render = this._dirty;
        if (needs_render) {
            this.scene.render();
            this._dirty = false;
        }
    }

    store_extents_changed(extents: Extents3) {
        this.extents = extents;
        this._hover.extents = extents;
        this.tiler = undefined;
        this.init_tiler();
        this.camera.zoomDataExtents(extents, this.canvas);
    }

	canvas_size_changed() {
		console.debug('canvas size changed');
		this.scene.render();
	}


    async toggle_object(key: string) {
        if (this.layers.is_loaded(key)) {
        } else {
            if (await this.init_tiler())
                this.load_object(key);
        }
    }

    private async load_object(key: string) {
        console.time(`loading object ${key}`);
        await this.layers.add_surface(key);
        this._dirty = true;
        console.timeEnd(`loading object ${key}`);
        await this.update_in_view_tiles();
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
        this._dirty = true;
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

        // const timeKey = `update_in_view_tiles ${Math.random()}`;
        // console.time(timeKey);

        // const updateKey = `recalculate viewbox ${Math.random()}`;
        // console.time(updateKey);
        const viewbox = this.camera.viewbox(this.canvas, this.extents);
        this.tiler.update(viewbox);
        // console.timeEnd(updateKey)

        const inview = this.tiler.in_view_tiles();
        const outview = this.tiler.out_view_tiles();

        // console.debug({inview, outview});

        await this.layers.update_inview_tiles(inview, outview, this.extents, () => this.mark_dirty());

        // do last since it does not affect viewing
        // don't mark dirty, does not need a render
        // this.layers.update_lods_outview(viewable_tiles);
        // console.timeEnd(timeKey);
    }
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
        let tile_id;
        let lod_res;
        if (pick.pickedMesh) {
            const x = pick.pickedMesh.name.split('/');
            tile_id = parseFloat(x[x.length - 1]);
            mesh_name = x.slice(0, -1).join('/');
            lod_res = TileId.from_num(tile_id).lod_res();
        }

        const info = {
            pointerx: x,
            pointery: y,
            render_pt,
            world_pt,
            mesh_name,
            tile_id,
            lod_res
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
    mesh_key?: string,
    tile_id?: number,
    lod_res?: number,
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
