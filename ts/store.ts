import { SpatialObject, Status } from "./spatial-obj";
import { openDB, IDBPDatabase } from "idb";
import { TriangleMeshSurface, Extents3 } from './wasm';

export { Store };

const STORE_NAME = "keyval";

type Key = string | Array<string | number>;

class Store {

	db_name: string;
	db: IDBPDatabase;

	private constructor(db_name: string, db: IDBPDatabase) {
		this.db_name = db_name;
		this.db = db;
	}

	static async connect(db_name: string): Promise<Store> {
		const db = await openDB(db_name, 2, {
			upgrade(db) {
				db.createObjectStore(STORE_NAME);
			},
			terminated: () =>
				console.error("Browser abnormally closed connection to " + db_name),
		});

		console.info(`Opened connection to '${db_name}'`);

		return new Store(db_name, db);
	}

	private async put(key: Key, obj: any) {
		await this.db.put(STORE_NAME, obj, key);
	}

	private async get<T>(key: Key): Promise<T | undefined> {
		return await this.db.get(STORE_NAME, key);
	}

	private async put_bytes(key: Key, bytes: Uint8Array) {
		await this.put(key, bytes.buffer);
	}

	private async get_bytes(key: Key): Promise<Uint8Array | undefined> {
		let bytes = await this.get<ArrayBuffer>(key);
		if (bytes) return new Uint8Array(bytes);
		else return undefined;
	}

	async store_object(key: string, obj: TriangleMeshSurface): Promise<SpatialObject> {
		// remove any previous object with that key
		await this.delete_object(key);

		let bytes = obj.to_bytes();
		await this.put_bytes(['raw', key], bytes);

		const o = new SpatialObject(key);
		o.status = Status.Preprocessing;
		await this.update_object_list(o);

		return o;
	}

	async get_object(key: string): Promise<TriangleMeshSurface | undefined> {
		let bytes = await this.get_bytes(['raw', key]);
		if (bytes) return TriangleMeshSurface.from_bytes(bytes);
		else return undefined;
	}

	async delete_object(key: string): Promise<void> {
		let objkey = key;

		// this will be done in a single transation
		const tx = this.db.transaction(STORE_NAME, 'readwrite');
		const store = tx.objectStore(STORE_NAME);

		// remove the raw data
		await store.delete(['raw', objkey]);

		// update the object list
		let objs: Array<SpatialObject> = (await store.get('object-list') ?? []);
		let sobj_idx = objs.findIndex(x => x.key == objkey);
		if (sobj_idx == -1)
		{
			await tx.done;
			return;
		}

		// this removes the obj at sobj_idx, and also returns it
		let sobj = objs.splice(sobj_idx, 1)[0];
		await store.put(objs, 'object-list');

		for (const tile_idx of sobj.tiles) {
			let tilekey = ['tile', objkey, tile_idx];
			let tile: Tile | undefined = await store.get(tilekey);
			if (!tile)
				continue;

			await store.delete(tilekey);

			for (const lod of tile.lods) {
				let lodkey = ['lod', objkey, tile_idx, lod.idx];
				await store.delete(lodkey);
			}
		}

		await tx.done;

		console.info(`Deleted '${objkey}' from database`);
	}

	async get_object_list(): Promise<Array<SpatialObject>> {
		return await this.get('object-list') ?? [];
	}

	async find_object(objkey: string) : Promise<SpatialObject | undefined> {
		return (await this.get_object_list()).find(x => x.key == objkey);
	}

	async update_object_list(sobj: SpatialObject) {
		const tx = this.db.transaction(STORE_NAME, 'readwrite');
		const store = tx.objectStore(STORE_NAME);
		let objs: Array<SpatialObject> = (await store.get('object-list') ?? []);
		let idx = objs.findIndex(o => o.key == sobj.key);
		if (idx > -1) {
			objs[idx] = sobj;
		} else {
			objs.push(sobj);
		}
		await store.put(objs, 'object-list');
		await tx.done;
	}

	async extents(): Promise<Extents3 | undefined> {
		let bytes = await this.get_bytes('data-extents');
		if (bytes) return Extents3.from_bytes(bytes);
		else return undefined;
	}

	async set_extents(extents: Extents3) {
		await this.put_bytes('data-extents', extents.to_bytes());
		let objs = await this.get_object_list();
		objs.forEach(x => x.status = Status.Preprocessing);

		const tx = this.db.transaction(STORE_NAME, 'readwrite');
		const store = tx.objectStore(STORE_NAME);
		await store.put(objs, 'object-list');
		await tx.done;

		console.info({ msg: `Data extents set for '${this.db_name}'`, extents: extents.toString() });
	}

	async store_lod(obj: string, tile_idx: number, lod_idx: number, lod_res: number, zs: Float32Array) {
		let sobj = (await this.get_object_list()).find(x => x.key == obj);
		if (!sobj)
			return;

		add_tile_idx(sobj, tile_idx);

		let tilekey = ['tile', obj, tile_idx];
		let tile = await this.get<Tile>(tilekey) ?? new Tile(tile_idx);

		add_lod(tile, lod_idx, lod_res);

		let lodkey = ['lod', obj, tile_idx, lod_idx];
		await this.put_bytes(lodkey, new Uint8Array(zs.buffer));
		await this.put(tilekey, tile);
		await this.update_object_list(sobj);
	}
}

class Tile {
	lods: Array<Lod> = [];
	constructor(public idx: number) { }
}

type Lod = {
	idx: number,
	res: number,
};

function add_tile_idx(sobj: SpatialObject, tile_idx: number) {
	if (sobj.tiles.includes(tile_idx))
		return;

	sobj.tiles.push(tile_idx);
	sobj.tiles.sort();
}

function add_lod(tile: Tile, lod_idx: number, lod_res: number) {
	let lod = tile.lods.find(x => x.idx == lod_idx);
	if (lod)
		lod.res = lod_res;
	else {
		tile.lods.push({ idx: lod_idx, res: lod_res });
		tile.lods.sort((a, b) => a.res - b.res);
	}
}