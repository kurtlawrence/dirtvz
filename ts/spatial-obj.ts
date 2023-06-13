export { SpatialObject, Status };

/**
 * A reference to a loaded object in a `Viewer`.
 *
 * The main object is stored in the `Store`.
 */
class SpatialObject {
  key: string;
  public status: Status = Status.Unloaded;

  constructor(key: string) {
    this.key = key;
  }
}

enum Status {
  Unloaded = 'unloaded',
  Preprocessing = 'preprocessing',
  Loaded = 'loaded',
}
