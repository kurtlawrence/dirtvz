import { Color3, Mesh, Scene, StandardMaterial, VertexData } from "@babylonjs/core";
import { Extents3 } from "./../wasm";
import * as wasm from './../wasm';
import { Properties } from './prop';
import * as store from '../store';

type ObjKey = string;

export class Layers {
    scene: Scene;
    loaded: Set<ObjKey> = new Set();
    tiles: Map<number, Array<Tile>> = new Map();
	def_props: Properties;

    constructor(scene: Scene) {
        this.scene = scene;
		this.def_props = new Properties();
    }

    is_loaded(objkey: ObjKey): boolean {
        return this.loaded.has(objkey);
    }

    add_loaded(objkey: ObjKey) {
        this.loaded.add(objkey);
    }

    add_surface_tile(obj: ObjKey, tile: store.Tile, lod_idx: number, zs: Float32Array, extents: Extents3) {
		let tile_idx = tile.idx;
        let tiles = this.tiles.get(tile_idx);
        if (!tiles) {
            tiles = [];
            this.tiles.set(tile_idx, tiles)
        }

        const mesh = new Mesh(`${obj}-${tile_idx}-${lod_idx}`, this.scene);
		apply_prop_to_mesh(mesh, this.def_props, this.scene);

		const t = new Tile(obj, lod_idx, tile, mesh);
		t.update_mesh(zs, extents);

		tiles.push(t);
    }

	unload_out_of_view_tiles(inview_tiles: Uint32Array) {
		const inview = new Set(inview_tiles);
		for (const [idx, ts] of this.tiles) {
			if (inview.has(idx))
				continue;

			while (ts.length > 0) {
				const tile = ts.pop();
				tile?.mesh.dispose();
			}
		}
	}

	inview(tile_idx: number): Tile[] | undefined {
		const x = this.tiles.get(tile_idx);
		if (x && x.length > 0) return x;
		else return undefined;
	}
}

function apply_prop_to_mesh(mesh: Mesh, prop: Properties, scene: Scene) {
	const mat = new StandardMaterial('', scene);
	const [r,g,b] = prop.colour;
    const c = Color3.FromInts(r,g,b);
	mat.diffuseColor = c;
	mat.backFaceCulling = false;

	mesh.material = mat;
}

class Tile {
    objkey: ObjKey;
    lod_idx: number;
	store_tile: store.Tile;
    mesh: Mesh;

	constructor(key: ObjKey, lod_idx: number, store_tile: store.Tile, mesh: Mesh) {
		this.objkey = key;
		this.lod_idx = lod_idx;
		this.store_tile = store_tile;
		this.mesh = mesh;
	}

	update_mesh(zs: Float32Array, extents: Extents3) {
        // populate mesh arrays in render space
        // const timerkey = `generating vertex data for ${this.objkey}`;
        // console.time(timerkey);
        const vd = wasm.VertexData.fill_vertex_data_from_tile_zs(extents, this.store_tile.idx, zs);

		if (vd.is_empty()) {
			return;
		}

        const vertex_data = new VertexData();
        vertex_data.positions = vd.positions();
		vertex_data.indices = vd.indices();
		vertex_data.normals = vd.normals();
        // console.timeEnd(timerkey);

        vertex_data.applyToMesh(this.mesh);
	}
}
