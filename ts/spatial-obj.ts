/**
 * A reference to a loaded object in a `Viewer`.
 *
 * The main object is stored in the `Store`.
 */
export class SpatialObject {
  key: string;
  status: Status = Status.Unloaded;
  tiles: Array<number> = [];

  constructor(key: string) {
    this.key = key;
  }
}

export enum Status {
  Unloaded = 'unloaded',
  Preprocessing = 'preprocessing',
  Loaded = 'loaded',
  Ready = 'ready'
}
