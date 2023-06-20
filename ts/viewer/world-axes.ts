import { AxesViewer, Matrix, Scene, Vector3 } from '@babylonjs/core';

export class WorldAxes {
    inner: AxesViewer;
    scene: Scene;

    constructor(scene: Scene) {
        this.inner = new AxesViewer(scene, undefined, undefined, undefined, undefined, undefined, 2);
        this.scene = scene;
    }

    set_position(canvas: HTMLCanvasElement, world_pos?: Vector3) {
        const { width, height } = canvas.getBoundingClientRect();
        const vm = this.scene.getViewMatrix();
        const pm = this.scene.getProjectionMatrix();
        if (!vm || !pm) {
            return;
        }

        let p, sizev;
        if (world_pos) {
            p = world_pos;
            sizev = Vector3.Unproject(
                new Vector3(120, height - 120, 0.1),
                width,
                height,
                Matrix.Identity(),
                vm,
                pm,
            ).subtractInPlace(
                Vector3.Unproject(
                    new Vector3(20, height - 20, 0.1),
                    width,
                    height,
                    Matrix.Identity(),
                    vm,
                    pm,
                )
            );
        } else {
            p = Vector3.Unproject(
                new Vector3(20, height - 20, 0.1),
                width,
                height,
                Matrix.Identity(),
                vm,
                pm,
            );
            // we cheat and just project another ray to get a consistent pixel size
            sizev = Vector3.Unproject(
                new Vector3(120, height - 120, 0.1),
                width,
                height,
                Matrix.Identity(),
                vm,
                pm,
            ).subtractInPlace(p);
        }

        const size = 0.4 * Math.sqrt(sizev.x * sizev.x + sizev.z * sizev.z);

        this.inner.scaleLines = size;
        this.update(p);
    }

    private update(pos: Vector3) {
        this.inner.update(
            pos,
            Vector3.Right(),
            Vector3.Up(),
            Vector3.Forward(),
        );
    }

    remove() {
        this.inner.dispose();
    }
}

