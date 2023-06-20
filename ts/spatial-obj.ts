export type SpatialObject = {
  key: string,
  status: Status,
  tiles: Array<number>,
}

export enum Status {
  Unloaded = 'unloaded',
  Preprocessing = 'preprocessing',
  Loaded = 'loaded',
  Ready = 'ready'
}
