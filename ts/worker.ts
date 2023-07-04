import { exposeApi } from 'threads-es/worker';
import { Transfer, TransferDescriptor } from 'threads-es/shared';
import * as local_loader from './local-loader';
import { Store } from './store';
import * as wasm from './wasm';
import * as prgrs from './prg-stream';

const api = {
	read_load_and_store_from_spatial_file,
	preprocess_spatial_object,
	build_vertex_data
};

export type WorkerApi = typeof api;

exposeApi(api);

async function read_load_and_store_from_spatial_file(db_name: string, file: File) {
	let obj = await local_loader.parse_file(file);

	let db = await Store.connect(db_name);
	await db.store_object(obj.name ?? 'new-object', obj.obj);
}

/** Returns if the data extent were changed. */
async function preprocess_spatial_object(
	db_name: string,
    objkey: string,
    progress: prgrs.Channel
): Promise<boolean> {
	const db = await Store.connect(db_name);
	const mesh = await db.get_object(objkey);
	if (!mesh)
		return false;

	let extents = await db.extents();
	let chgd = false;
	if (!extents) {
		extents = mesh.aabb();
		await db.set_extents(extents);
		chgd = true;
	}

	console.time('generating tiles hash');
	const hash = mesh.generate_tiles_hash(extents);
	const tiles = hash.tiles();
	console.timeEnd('generating tiles hash');

	const outof = tiles.length;
	const pr = progress.send.getWriter();
	let iter = 0;

	for (const tile_idx of tiles) {
		const zs = hash.sample(tile_idx);
		if (zs) {
			await db.store_tile(objkey, tile_idx, zs);
			iter += 1;
			await pr.write(prgrs.preprocessing(objkey, iter, outof));
		}
	}

	await pr.ready.then(() => pr.releaseLock());
	await progress.send.close();

	return chgd;
}

export type MeshVertexData = {
	empty: boolean,
	positions: ArrayBuffer,
	indices: ArrayBuffer,
	normals: ArrayBuffer,
};

function build_vertex_data(
	tile_idx: number,
	zs: TransferDescriptor<ArrayBuffer>,
	extents: TransferDescriptor<ArrayBuffer>
): TransferDescriptor<MeshVertexData> {
	const xts = wasm.Extents3.from_bytes(new Uint8Array(extents.send));

	// const timer = `fill vertex data at ${lod_idx}`;
	// console.time(timer);
	const vd = wasm.VertexData.fill_vertex_data_from_tile_zs_smooth(
		xts, tile_idx, new Float32Array(zs.send)
	);

	const empty = vd.is_empty();
	const positions = empty ? new ArrayBuffer(0) : vd.positions().buffer;
	const indices = empty ? new ArrayBuffer(0) : vd.indices().buffer;
	const normals = empty ? new ArrayBuffer(0) : vd.normals().buffer;

	let x: MeshVertexData = {
		empty, positions, indices, normals
	};

	vd.free();

	// console.timeEnd(timer);

	return Transfer(x, [positions, indices, normals]);
}
