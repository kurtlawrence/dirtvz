import { EsThread, EsThreadPool } from 'threads-es/controller';
import { WorkerApi as Wapi } from './worker';

export type WorkerApi = Wapi;

export async function spawn() : Promise<EsThread<WorkerApi>> {
	return EsThread.Spawn<WorkerApi>(
		// this way uses output of Webpack entry
		new Worker('./dirtvz-worker.js', {type: 'module'}));
}

export async function spawn_pool() : Promise<EsThreadPool<WorkerApi>> {
	return EsThreadPool.Spawn(spawn);
}
