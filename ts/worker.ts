import { exposeApi } from 'threads-es/worker';
import * as local_loader from './local-loader';
import { Store } from './store';
import * as wasm from './wasm';

const api = {
	read_load_and_store_from_spatial_file,
	preprocess_spatial_object
};

export type WorkerApi = typeof api;

exposeApi(api);

async function read_load_and_store_from_spatial_file(db_name: string, file: File) {
	let obj = await local_loader.parse_file(file);

	let db = await Store.connect(db_name);
	await db.store_object(obj.name ?? 'new-object', obj.obj);
}

async function preprocess_spatial_object(db_name: string, objkey: string) {
	let db = await Store.connect(db_name);
	let mesh = await db.get_object(objkey);
	if (!mesh)
		return;

	let extents = await db.extents();
	if (!extents) {
		extents = mesh.aabb();
		await db.set_extents(extents);
	}

	console.time('generating tiles hash');
	let hash = mesh.generate_tiles_hash(extents);
	let tiles = hash.tiles();
	console.timeEnd('generating tiles hash');

	let lods = [50, 25];

	for (let idx = 0; idx < lods.length; idx++) {
		const lod = lods[idx];
		console.debug(`Processing LOD ${lod}`);

		for (const tile_idx of tiles) {
			console.debug(`Processing tile index ${tile_idx}`);

			let zs = hash.sample(lod, tile_idx);
			if (zs) {
				console.debug('Received sampled values');
				await db.store_lod(objkey, tile_idx, idx, lod, zs);
			}
		}
	}
}
