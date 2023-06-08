import { TriangleMeshSurface } from './data';


export class SpatialObject {
	constructor(public name: string | null, public obj: TriangleMeshSurface) {}
}

export async function parse_file(file: File) : Promise<SpatialObject> {
	let name = file.name;

	let ext = name.split('.').slice(1).pop();
	if (ext === undefined)
		ext = '';
	let name2 = name.substring(0, name.length - ext.length);

	let data = await file.arrayBuffer().then(x => new Uint8Array(x));

	switch (ext){
	   case '':
	      throw new Error('file has no extension');

	   case '00t':
	       let mesh = TriangleMeshSurface.empty();
	       mesh.from_vulcan_00t(data);
		   return new SpatialObject(name2, mesh);

	   default:
	      throw new Error('extension `' + ext + '` is currently unsupported');
	}
}
