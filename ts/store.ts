import { SpatialObject, Status, add_root, has_root, has_tile, add_tile } from "./spatial-obj";
import { IDBPDatabase } from "idb";
import * as idb from "idb";
import { TriangleMeshSurface, Extents3, TileId } from './wasm';

enum Key {
	DataExtents = 'data-extents',
	ObjList = 'object-list',
}

const stores = ['root', 'raw-objs', 'tiles'] as const;
type StoreName = typeof stores[number];

export class Store {
	db_name: string;
	db: IDBPDatabase;

	private constructor(db_name: string, db: IDBPDatabase) {
		this.db_name = db_name;
		this.db = db;
	}

	static async connect(db_name: string): Promise<Store> {
		const db = await idb.openDB(db_name, 1, {
			upgrade(db) {
				for (const n of stores)
					db.createObjectStore(n);
			},
			terminated: () =>
				console.error("Browser abnormally closed connection to " + db_name),
		});

		console.info(`Opened connection to '${db_name}'`);

		return new Store(db_name, db);
	}

	private async transact<T, M extends IDBTransactionMode>(
		store_name: StoreName,
		mode: M,
		tfn: (store: TypedStore<M>) => Promise<T>): Promise<T> {
		const tx = this.db.transaction(store_name, mode, { durability: 'relaxed' });
		const store = new TypedStore<M>(tx.store);
		const x = await tfn(store);
		await tx.done;
		return x;
	}

	async extents(): Promise<Extents3 | undefined> {
		return this.transact('root', 'readonly', store =>
			store.get_bytes(Key.DataExtents)
				.then(bytes => {
					if (bytes) return Extents3.from_bytes(bytes);
					else return undefined;
				}));
	}

	async set_extents(extents: Extents3) {
		await this.transact('root', 'readwrite', async store => {
			await store.put_bytes(Key.DataExtents, extents.to_bytes());
			const objs: SpatialObject[] = await store.get(Key.ObjList) ?? [];
			objs.forEach(x => x.status = Status.Preprocessing);
			store.put(Key.ObjList, objs);
			console.info({ msg: `Data extents set for '${this.db_name}'`, extents: extents.toString() });
		});
	}

	async store_object(key: string, obj: TriangleMeshSurface): Promise<SpatialObject> {
		// remove any previous object with that key
		await this.delete_object(key);

		// write the bytes out
		await this.transact('raw-objs', 'readwrite', store => {
			const bytes = obj.to_bytes();
			return store.put_bytes(key, bytes);
		});

		const o = { key, status: Status.Preprocessing, roots: [], tiles: [] };
		await this.update_object_list(o);

		return o;
	}

	async get_object(key: string): Promise<TriangleMeshSurface | undefined> {
		return this.transact('raw-objs', 'readonly', async store => {
			const bytes = await store.get_bytes(key);
			if (bytes) return TriangleMeshSurface.from_bytes(bytes);
			else return undefined;
		});
	}

	async mark_deletion(obj: string) {
		const sobj = await this.find_object(obj);
		if (!sobj)
			return;
		
		sobj.status = Status.Deleting;
		return this.update_object_list(sobj);
	}

	async delete_object(obj: string) {
		const sobj = await this.find_object(obj);
		const update_sobjs = this.transact('root', 'readwrite', async store => {
			const sobjs = await store.get<SpatialObject[]>(Key.ObjList) ?? [];
			return store.put(Key.ObjList, sobjs.filter(x => x.key != obj));
		});

		const rm_raw = this.transact('raw-objs', 'readwrite', store =>
			store.delete(obj));

		const rm_tiles = this.transact('tiles', 'readwrite', async store => {
			if (!sobj)
				return;

			for (const t of sobj.tiles)
				await store.delete(obj_tile_key(obj, t));
		});

		return Promise.all([update_sobjs, rm_raw, rm_tiles]);
	}


	async get_object_list(): Promise<SpatialObject[]> {
		return this.transact('root', 'readonly', async store => {
			return await store.get<SpatialObject[]>(Key.ObjList) ?? [];
		});
	}

	async update_object_list(sobj: SpatialObject) {
		return this.transact('root', 'readwrite', async store => {
			const objs: SpatialObject[] = (await store.get(Key.ObjList) ?? []);
			const idx = objs.findIndex(o => o.key == sobj.key);
			if (idx > -1) {
				objs[idx] = sobj;
			} else {
				objs.push(sobj);
			}
			await store.put(Key.ObjList, objs);
		});
	}

	async find_object(objkey: string): Promise<SpatialObject | undefined> {
		return (await this.get_object_list()).find(x => x.key == objkey);
	}

	async store_tile(obj: string, tile_idx: number, zs: Float32Array) {
		await this.transact('tiles', 'readwrite', store =>
			store.put_bytes(obj_tile_key(obj, tile_idx), new Uint8Array(zs.buffer)));

		await this.transact('root', 'readwrite', async store => {
			const sobjs: SpatialObject[] = await store.get(Key.ObjList) ?? [];
			const sobj = sobjs.find(x => x.key == obj);
			if (!sobj)
				return;

			if (!has_tile(sobj, tile_idx))
				add_tile(sobj, tile_idx);
			if (TileId.is_root(tile_idx) && !has_root(sobj, tile_idx))
				add_root(sobj, tile_idx);

			store.put(Key.ObjList, sobjs);
		});
	}

	async get_tile(obj: string, tile_idx: number): Promise<Float32Array | undefined> {
		return this.transact('tiles', 'readonly', async store => {
			const bytes = await store.get_bytes(obj_tile_key(obj, tile_idx));
			if (bytes) return new Float32Array(bytes.buffer);
			else return undefined;
		});
	}
}

class TypedStore<M extends IDBTransactionMode> {
	store: idb.IDBPObjectStore<any, any, any, M>

	constructor(store: idb.IDBPObjectStore<any, any, any, M>) {
		this.store = store;
	}

	async get<T>(key: string): Promise<T | undefined> {
		return this.store.get(key);
	}

	async put(key: string, obj: any) {
		// @ts-ignore
		await this.store.put(obj, key);
	}

	async get_bytes(key: string): Promise<Uint8Array | undefined> {
		let bytes = await this.get<ArrayBuffer>(key);
		if (bytes) return new Uint8Array(bytes);
		else return undefined;
	}

	async put_bytes(key: string, bytes: Uint8Array) {
		await this.put(key, bytes.buffer);
	}

	async delete(key: string) {
		// @ts-ignore
		await this.store.delete(key);
	}
}

function obj_tile_key(obj: string, tile: number): string {
	return `${obj}/${tile}`;
}
