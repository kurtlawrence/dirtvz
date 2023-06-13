import { EsThread } from 'threads-es/controller';
import { WorkerApi } from './worker';

export async function spawn() : Promise<EsThread<WorkerApi>> {
	return EsThread.Spawn<WorkerApi>(
		new Worker(
			new URL('./worker.ts', import.meta.url), {type: 'module'}));
}
