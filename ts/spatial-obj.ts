export type SpatialObject = {
    key: string,
    status: Status,
    roots: Array<number>,
    tiles: Array<number>,
}

export enum Status {
    Unloaded = 'unloaded',
    Preprocessing = 'preprocessing',
    Loaded = 'loaded',
    Ready = 'ready',
	Deleting = 'deleting',
}

function cmpr(a: number, b: number): number {
    return a - b;
}

export function add_root(o: SpatialObject, tile: number) {
    o.roots.push(tile);
    o.roots.sort(cmpr);
}

export function has_root(o: SpatialObject, tile: number) {
    return bsearch(o.roots, tile) >= 0;
}

export function add_tile(o: SpatialObject, tile: number) {
    o.tiles.push(tile);
    o.tiles.sort(cmpr);
}

export function has_tile(o: SpatialObject, tile: number) {
    return bsearch(o.tiles, tile) >= 0;
}

function bsearch(array: number[], value: number): number {
    let index = 0;
    let limit = array.length - 1;
    while (index <= limit) {
        const i = Math.ceil((index + limit) / 2);
        const e = array[i];
        if (value > e) {
            index = i + 1;
        } else if (value < e) {
            limit = i - 1;
        } else {
            return i; // value == e
        }
    }

    return -1;
}
