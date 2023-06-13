import { exposeApi } from 'threads-es/worker';
import * as local_loader from './local-loader';
import { Store } from './store';

const api = {
	read_load_and_store_from_spatial_file
};

export type WorkerApi = typeof api;

exposeApi(api);

async function read_load_and_store_from_spatial_file(db_name: string, file: File) {
	let obj = await local_loader.parse_file(file);

	let db = await Store.connect(db_name);
	db.store_object(obj.name ?? 'new-object', obj.obj);
}

