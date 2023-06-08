export { Point3, Extents2 };
export { TriangleMeshSurface } from './wasm';

class Point3 {
  constructor(public x: number, public y: number, public z: number) {}
}

type Extents2 = { origin: Point3; size: Point3 };
