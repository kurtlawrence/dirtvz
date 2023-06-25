import { Color3, Mesh, Scene, StandardMaterial, VertexData } from "@babylonjs/core";
import { Extents3 } from "./../wasm";
import { Properties } from './prop';
import * as store from '../store';
import { Store } from '../store';
import { spawn, WorkerApi } from "../worker-spawn";
import { EsThreadPool, Transfer } from "threads-es";

type ObjKey = string;

export class Layers {
	_store: Store;
	_scene: Scene;
	_loaded: Map<ObjKey, store.Tile[]> = new Map();
	_tiles: Map<number, Array<Tile>> = new Map();
	_def_props: Properties = new Properties();
	_wkr?: EsThreadPool<WorkerApi>;

	constructor(store: Store, scene: Scene) {
		this._store = store;
		this._scene = scene;
		EsThreadPool.Spawn(spawn).then(x => this._wkr = x);
	}

	is_loaded(obj: ObjKey): boolean {
		return this._loaded.has(obj);
	}

	/* Add a new _surface_ object to the loaded layers.
	 *
	 * This will bulk load the lowest LOD available.
	 * You may want to then update the visible tiles with higher quality LODs.
	 */
	async add_surface(obj: ObjKey, tile_load_cb?: () => void) {
		const st = this._store;
		const [tiles, extents] = await Promise.all([
			st.find_object(obj)
			.then(x => x ? st.get_object_tiles(x) : Promise.resolve(undefined)),
			st.extents()
		]);
		if (!tiles || !extents)
			return;

		await Promise.all(tiles.map(async (tile) => {
			const zs = await this._store.get_lod(obj, tile, 0);
			if (zs) {
				await this.add_surface_tile(extents, obj, tile, zs);
				if (tile_load_cb)
					tile_load_cb();
			}
		}));
	}

	private async add_surface_tile(extents: Extents3, obj: ObjKey, tile: store.Tile, zs: Float32Array) {
		const tile_idx = tile.idx;
		let tiles = this._tiles.get(tile_idx);
		if (!tiles) {
			tiles = [];
			this._tiles.set(tile_idx, tiles)
		}

		const mesh = new Mesh('', this._scene);
		mesh.freezeWorldMatrix();
		// mesh.isUnIndexed = true; // for flat shading

		apply_prop_to_mesh(mesh, this._def_props, this._scene);

		const vd = await this.build_tile_vertex_data(extents, tile_idx, zs);
		tiles.push(new Tile(obj, tile, mesh, vd));
	}

	private async build_tile_vertex_data(extents: Extents3, tile_idx: number, zs: Float32Array): Promise<VertexData> {
		const xts = extents.to_bytes();
		const vertex_data = new VertexData();
		const vd = await this._wkr?.queue(x => x.methods.build_vertex_data(
			tile_idx,
			Transfer(zs.buffer),
			Transfer(xts.buffer)
		));

		if (!vd || vd.empty) 
			return vertex_data;

		vertex_data.positions = new Float32Array(vd.positions);
		vertex_data.indices = new Uint32Array(vd.indices);
		vertex_data.normals = new Float32Array(vd.normals);

		return vertex_data;
	}

	async update_lods_inview(tile_idx: number, lod_res: number, extents: Extents3) {
		const tiles = this._tiles.get(tile_idx);
		if (!tiles)
			return;

		for (const tile of tiles) {
			const lod = choose_lod(tile.store_tile, lod_res);
			if (lod.idx == tile.lod_idx)
				continue; // no change, skip updating

			tile.lod_idx = lod.idx;
			if (lod.idx == 0) {
				// the change can use the cached lowest lod
				tile.apply_lowest_lod_vd();
			} else {
				const zs = await
				this._store.get_lod(tile.objkey, tile.store_tile, lod.idx);
				if (!zs)
					continue;

				const vd = await this.build_tile_vertex_data(extents, tile_idx, zs);

				// only apply if the lod hasn't changed again!
				if (vd && tile.lod_idx == lod.idx) {
					tile.apply_vd(vd);
				}
			}
		}
	}

	update_lods_outview(inview_tiles: Iterable<number>) {
		const inview = new Set(inview_tiles);
		for (const [tile_idx, tiles] of this._tiles) {
			if (inview.has(tile_idx))
				continue;

			for (const tile of tiles) {
				tile.apply_lowest_lod_vd();
			}
		}
	}
}

function apply_prop_to_mesh(mesh: Mesh, prop: Properties, scene: Scene) {
	const mat = new StandardMaterial('', scene);
	const [r, g, b] = prop.colour;
	const c = Color3.FromInts(r, g, b);
	mat.diffuseColor = c;
	mat.backFaceCulling = false;

	mesh.material = mat;
}

class Tile {
	objkey: ObjKey;
	store_tile: store.Tile;
	lod_idx: number;
	low_lod_vd: VertexData;
	mesh: Mesh;

	/* Construct a new tile with the lowest lod vertex data.
     * 
	 * Note that this will name the mesh and apply the vertex data for you.
	 */
	constructor(key: ObjKey, store_tile: store.Tile, mesh: Mesh, persistent_vd: VertexData) {
		this.objkey = key;
		this.store_tile = store_tile;
		this.lod_idx = 0;
		this.mesh = mesh;
		this.low_lod_vd = persistent_vd;

		this.apply_lowest_lod_vd();
	}

	name(): string {
		return `${this.objkey}-${this.store_tile.idx}-${this.lod_idx}`;
	}

	apply_lowest_lod_vd() {
		this.lod_idx = 0;
		this.apply_vd(this.low_lod_vd);
	}

	apply_vd(vd: VertexData) {
		this.mesh.name = this.name();
		vd.applyToMesh(this.mesh);
	}
}

function choose_lod(tile: store.Tile, res: number) {
    // we leverage the fact that these are ordered in _ascending resolution_.
    // the choice is the minimum res **greater** than the request res.
    const lods = tile.lods;
    return lods.find(x => x.res >= res) ?? lods[lods.length - 1];
}

