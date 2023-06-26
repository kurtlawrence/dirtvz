import { EsThread } from 'threads-es/controller';
import { WorkerApi as Wapi } from './worker';

export type WorkerApi = Wapi;

export async function spawn() : Promise<EsThread<WorkerApi>> {
	return EsThread.Spawn<WorkerApi>(
		// this way uses output of Webpack entry
		new Worker('/dirtvz-worker.js', {type: 'module'}));
		// this way creates own output
			// new URL('./worker.ts', import.meta.url), {type: 'module'}));
}
