import { memory } from "./wasm";
export { Viewer } from "./viewer";
export { viewerUi } from "./viewer-ui";

export function wasm_buffer_size(): number {
    return memory.buffer.byteLength;
}

export function __grow(delta: number): number {
    return memory.grow(delta);
}