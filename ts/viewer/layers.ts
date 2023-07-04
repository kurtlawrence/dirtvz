import { Color3, Mesh, Scene, StandardMaterial, VertexData } from "@babylonjs/core";
import { Extents3 } from "./../wasm";
import { Properties } from './prop';
import { Store } from '../store';
import { WorkerApi, spawn_pool } from "../worker-spawn";
import { EsThreadPool, Transfer } from "threads-es";
import { has_tile, SpatialObject } from "../spatial-obj";

type ObjKey = string;

export class Layers {
	_store: Store;
	_scene: Scene;
	_loaded: Map<ObjKey, SpatialObject> = new Map();
	_tiles: Map<number, Tile[]> = new Map();
	_def_props: Properties = new Properties();
	_wkr?: EsThreadPool<WorkerApi>;
	_update_ver: number = 0;

	constructor(store: Store, scene: Scene) {
		this._store = store;
		this._scene = scene;
		spawn_pool().then(x => this._wkr = x);
	}

	is_loaded(obj: ObjKey): boolean {
		return this._loaded.has(obj);
	}

	unload(obj: ObjKey) {
		this._loaded.delete(obj);

		for (const ts of this._tiles.values()) {
			for (const t of ts) {
				if (t.objkey == obj)
					t.dispose();
			}
		}
	}

	/* Add a new _surface_ object to the loaded layers.
	 *
	 * This will bulk load the lowest LOD available.
	 * You may want to then update the visible tiles with higher quality LODs.
	 */
	async add_surface(obj: ObjKey) {
		const st = this._store;
		const [sobj, extents] = await Promise.all([
			st.find_object(obj),
			st.extents()
		]);
		if (!sobj || !extents)
			return;

		this._loaded.set(obj, sobj);

		return Promise.all(sobj.roots.map(async tile => {
			const zs = await this._store.get_tile(obj, tile);
			if (zs)
				await this.add_surface_tile(extents, obj, tile, zs);
		}));
	}

	private async add_surface_tile(extents: Extents3, obj: ObjKey, tile: number, zs: Float32Array) {
		let tiles = this._tiles.get(tile);
		if (!tiles) {
			tiles = [];
			this._tiles.set(tile, tiles)
		}

		const mesh = new Mesh(`${obj}/${tile}`, this._scene);
		mesh.freezeWorldMatrix();
		// mesh.isUnIndexed = true; // for flat shading

		apply_prop_to_mesh(mesh, this._def_props, this._scene);

		const vd = await this.build_tile_vertex_data(extents, tile, zs);
		vd.applyToMesh(mesh);
		tiles.push(new Tile(obj, mesh));
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

	async update_inview_tiles(inview_tiles: Iterable<number>, outview_tiles: Iterable<number>, extents: Extents3, onload: () => void) {
		this._update_ver += 1;
		const ver = this._update_ver;
		const inview = new Set(inview_tiles);
		const outview = new Set(outview_tiles);
		const to_remove = Array.from(this._tiles.keys())
			.filter(x => !inview.has(x) && !outview.has(x));

		// first, add all the _new_ in view tiles
		// note that this will update over already existing meshes
		await this.add_tiles(inview, extents, ver, onload);

		// second, dispose of all meshes to remove
		for (const tile_idx of to_remove) {
			if (ver != this._update_ver)
				break; // version changed

			const tiles = this._tiles.get(tile_idx);
			if (tiles) {
				for (const tile of tiles)
					tile.dispose();
				this._tiles.delete(tile_idx);
			}

			onload();
		}

		// finally, load all out of view meshes
		await this.add_tiles(outview, extents, ver, onload);
	}

	private async add_tiles(tiles: Iterable<number>, extents: Extents3, ver: number, onload: () => void) {
		const db = this._store;
		await Promise.all(Array.from(tiles).map(async tile_idx => {
			if (ver != this._update_ver)
				return; // version changed

			if (this._tiles.has(tile_idx))
				return; // no change already loaded

			for (const obj of this._loaded.values()) {
				if (!has_tile(obj, tile_idx))
					continue;

				const zs = await db.get_tile(obj.key, tile_idx);
				if (zs)
					await this.add_surface_tile(extents, obj.key, tile_idx, zs);
			}

			onload();
		}));
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
	mesh: Mesh;

	constructor(key: ObjKey, mesh: Mesh) {
		this.objkey = key;
		this.mesh = mesh;
	}

	dispose() {
		this.mesh.dispose();
	}
}
