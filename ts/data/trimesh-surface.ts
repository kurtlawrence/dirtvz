import { Point3 } from './spatial';

export { TriangleMeshSurface };

/**
	* A _surface_ spatial object consisting of a bunch of triangles.
	*
	* This object is meant to be fed into the `Viewer` object.
	* Since it will usually be transferred across the network, it is optimised for space.
	* It consists of an array of 'points' (x,y,z coordinates as 32-bit floats), an array of 'faces'
    * (32-bit indices of p1,p2,p3), and a translation `Point3`.
	*
	* The points are 32-bit to save on space. The translation point is recommended to be the lower
	* AABB point. Each point will be translated like so:
		* `translate` + `(x,y,z)`
	*/
class TriangleMeshSurface {
	constructor(public points: Float32Array, public indices: Uint32Array, public translate: Point3) {}
}

