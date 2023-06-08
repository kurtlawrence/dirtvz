import { SpatialObject, Status } from "./spatial-obj";
import { openDB, IDBPDatabase } from "idb";
import { Extents2, TriangleMeshSurface } from './data';
import ObjectPreprocessor from "worker-loader!./worker";

export { Store };

class Store {
  static store_name = "keyval";

  db_name: string;
  db: IDBPDatabase;
  loaded: Map<string, SpatialObject>;

  private constructor(db_name: string, db: IDBPDatabase) {
    this.db_name = db_name;
    this.db = db;
    this.loaded = new Map();
  }

  static async connect(db_name: string): Promise<Store> {
    const db = await openDB(db_name, undefined, {
      terminated: () =>
        console.error("Browser abnormally closed connection to " + db_name),
    });

    console.info(`Opened connection to '${db_name}'`);

    return new Store(db_name, db);
  }

  store_object(key: string, obj: TriangleMeshSurface): SpatialObject {
    // remove old object using the same key
    // this.store.delete(key);

    const worker = new ObjectPreprocessor();

    worker.postMessage({
      obj: TriangleMeshSurface,
    });

    worker.onmessage = (ev) => this.recv_repr(key, ev.data);

	const o = new SpatialObject(key);
	o.status = Status.Preprocessing;

	return o;
  }

  recv_repr(key: string, repr: number) {}
}

// class Representation {
// 	tile_aabb: Extents2
// }
