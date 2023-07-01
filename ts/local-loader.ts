import { TriangleMeshSurface } from './wasm';

export class SpatialObject {
	constructor(public name: string | null, public obj: TriangleMeshSurface) { }
}

export async function parse_file(file: File): Promise<SpatialObject> {
	let name = file.name;

	let ext = name.split('.').slice(1).pop();
	if (ext === undefined)
		ext = '';
	let len = name.length - ext.length - (ext.length == 0 ? 0 : 1);
	let name2 = name.substring(0, len);

	let data = await file.arrayBuffer().then(x => new Uint8Array(x));
	if (data.byteLength > 2.2e9)
		throw new Error('file is too large: a 2.2 GB limit is imposed');

	switch (ext) {
		case '':
			throw new Error('file has no extension');

		case '00t':
			if (data.byteLength > 100e6)
			 	throw new Error('file is too large: 00t must be smaller than 100 MB');

			try {
				let mesh = TriangleMeshSurface.from_vulcan_00t(data);
				return new SpatialObject(name2, mesh);
			} catch (error) {
				throw new Error('unable to Vulcan file: ' + error);
			}

		default:
			throw new Error('extension `' + ext + '` is currently unsupported');
	}
}
