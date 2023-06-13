import { SpatialObject, Status } from "./spatial-obj";
import { openDB, IDBPDatabase } from "idb";
import { Extents2, TriangleMeshSurface } from './data';

export { Store };
  
const STORE_NAME = "keyval";

class Store {

  db_name: string;
  db: IDBPDatabase;

  private constructor(db_name: string, db: IDBPDatabase) {
    this.db_name = db_name;
    this.db = db;
  }

  static async connect(db_name: string): Promise<Store> {
    const db = await openDB(db_name, 2, {
		upgrade(db) {
			db.createObjectStore(STORE_NAME);
		},
      terminated: () =>
        console.error("Browser abnormally closed connection to " + db_name),
    });

    console.info(`Opened connection to '${db_name}'`);

    return new Store(db_name, db);
  }

  private async put(key: string, obj: any) {
	  await this.db.put(STORE_NAME, obj, key);
  }

  private async get<T>(key: string) : Promise<T | undefined> {
	  return await this.db.get(STORE_NAME, key);
  }

  async store_object(key: string, obj: TriangleMeshSurface): Promise<SpatialObject> {
	  let bytes = obj.to_bytes();
	  await this.put(key, bytes);

    const o = new SpatialObject(key);
	o.status = Status.Preprocessing;
	await this.update_object_list(o);

	return o;
  }

  async get_object_list() : Promise<Array<SpatialObject>> {
	  return await this.get('object-list') ?? [];
  }

  private async update_object_list(sobj: SpatialObject) {
	  let objs = await this.get_object_list();
	  let idx = objs.findIndex(o => o.key == sobj.key);
	  if (idx > -1) {
		  objs[idx] = sobj;
	  } else {
		  objs.push(sobj);
	  }
	  await this.put('object-list', objs);
  }

  recv_repr(key: string, repr: number) {}
}

// class Representation {
// 	tile_aabb: Extents2
// }
