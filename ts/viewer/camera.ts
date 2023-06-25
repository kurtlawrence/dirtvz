import * as BABYLON from "@babylonjs/core";
import { Vector3, Scene } from "@babylonjs/core";
import { Extents3, Viewbox } from "../wasm";
import { WorldAxes } from "./world-axes";

// the camera draw z level
// we make this somewhat high to make the lighting semi sensible and not change on rotation
const DRAWZ: number = 100;


type ViewChgd = (cam: Camera) => void;

export class Camera {
    inner: BABYLON.ArcRotateCamera;
    scene: Scene;
    invert_wheel_zoom: boolean = false;
    _pan?: Pan;
    _rotate?: Rotate;
    onviewchg: ViewChgd;
    world_axes?: WorldAxes;
    world_axes_cb: any;

    constructor(scene: BABYLON.Scene) {
        this.inner = new BABYLON.ArcRotateCamera('camera', 0, 0, 10, Vector3.Zero(), scene);
        this.scene = scene;
        this.onviewchg = _ => { };
    }

    init(): Camera {
        this.inner.mode = BABYLON.Camera.ORTHOGRAPHIC_CAMERA;
        this.inner.allowUpsideDown = false;
        this.inner.maxZ = DRAWZ + 2;
        return this;
    }

    attachZoomControl(canvas: HTMLCanvasElement): Camera {
        canvas.addEventListener('keydown', (ev) => {
            if (ev.key == '=' || ev.key == '+') {
                // zoom in
                ev.preventDefault();
                this.zoom(0.8); // around center
            } else if (ev.key == '-') {
                // zoom out
                ev.preventDefault();
                this.zoom(1.2); // around center
            }
        });
        canvas.addEventListener('wheel', (ev) => {
            ev.preventDefault();
            const rect = canvas.getBoundingClientRect();
            let x = this.scene.pointerX;
            let y = this.scene.pointerY;
            x = x / rect.width * 2 - 1;
            y = y / rect.height * -2 + 1; // y is reversed (since from top)
            // can reverse this to reverse zooming
            if (ev.deltaY > 0 && !this.invert_wheel_zoom)
                this.zoom(0.8, x, y);
            else
                this.zoom(1.2, x, y);
        });

        return this;
    }

    attachPanControl(canvas: HTMLCanvasElement): Camera {
        canvas.addEventListener('keydown', (ev) => {
            if (ev.ctrlKey) return; // ctrl key not down
            if (ev.key == 'ArrowLeft') {
                ev.preventDefault();
                this.pan(-0.1, 0);
            } else if (ev.key == 'ArrowRight') {
                ev.preventDefault();
                this.pan(0.1, 0);
            } else if (ev.key == 'ArrowUp') {
                ev.preventDefault();
                this.pan(0, 0.1);
            } else if (ev.key == 'ArrowDown') {
                ev.preventDefault();
                this.pan(0, -0.1);
            }
        });
        canvas.addEventListener('pointerdown', ev => {
            if (ev.button == 0 && !ev.ctrlKey) {
                this._pan = new Pan(this, canvas);
            }
        });
        canvas.addEventListener('pointerup', _ => {
            if (this._pan) { this._pan = undefined; }
        });
        canvas.addEventListener('pointermove', _ => {
            if (this._pan) {
                this._pan.do_pan(this);
                this.onviewchg(this);
            }
        });

        return this;
    }

    attachRotateControl(canvas: HTMLCanvasElement): Camera {
        const bearing_by = Math.PI * 5 / 180; // 5 deg in radians
        const dip_by = Math.PI * 5 / 180; // 5 deg in radians
        canvas.addEventListener('keydown', ev => {
            if (!ev.ctrlKey) return; // ctrl key pressed
            if (ev.key == 'ArrowLeft') {
                ev.preventDefault();
                this.rotate(-bearing_by, 0);
            } else if (ev.key == 'ArrowRight') {
                ev.preventDefault();
                this.rotate(bearing_by, 0);
            } else if (ev.key == 'ArrowUp') {
                ev.preventDefault();
                this.rotate(0, dip_by);
            } else if (ev.key == 'ArrowDown') {
                ev.preventDefault();
                this.rotate(0, -dip_by);
            }
        });
        canvas.addEventListener('pointerdown', ev => {
            // on right click OR left click + ctrl key
            if (!this._pan && (ev.button == 2 || ev.button == 0 && ev.ctrlKey)) {
                this._rotate = Rotate.start(this, canvas);
            }
        });
        canvas.addEventListener('pointerup', _ => {
            if (this._rotate) { this._rotate = this._rotate.dispose(); }
        });
        canvas.addEventListener('pointermove', _ => {
            if (this._rotate) {
                this._rotate.do_rotate(this);
                this.onviewchg(this);
            }
        });

        return this;
    }

    get_ortho(): Ortho {
        return {
            otop: this.inner.orthoTop ?? 1,
            obot: this.inner.orthoBottom ?? 0,
            olef: this.inner.orthoLeft ?? 0,
            orig: this.inner.orthoRight ?? 1,
        };
    };

    zoomDataExtents(extents: Extents3, canvas: HTMLCanvasElement) {
        // we need to consider a few things:
        // 1. the canvas aspect ratio impacts which axis is the bounded one
        // 2. the camera needs to maintain 1:1 ratio for x:z

        const scaler = extents.max_dim();
        let dx = 0.5 * extents.size.x / scaler;
        let dy = 0.5 * extents.size.y / scaler;

        const rect = canvas.getBoundingClientRect();
        const canvasAspect = rect.width / rect.height;
        const extentsAspect = dx / dy;
        // render space goes from (0,0) -> (1,1)
        // but since we keep aspect ratio, using (.5, .5) will only center max dim
        const center = new Vector3(dx, 0, dy);

        if (extentsAspect > canvasAspect) {
            // there is more x than canvas aspect ratio, bound x
            dy = dx / canvasAspect;
        } else {
            // there is more y than canvas aspect ratio, bound y
            dx = dy * canvasAspect;
        }

        // Set the camera target and position first
        const camera = this.inner;
        camera.setTarget(center);
        camera.upVector = Vector3.Up();
        // directly 'above' center
        camera.setPosition(new Vector3(center.x, DRAWZ, center.z));
        camera.alpha = Math.PI * 1.5; // z facing north (!y-up), rotate -90 deg (270 deg)

        // after a bit of trial and error, ortho parameters are in SCENE units, which has (0,0) at
        // the the target of the camera!!!!
        camera.orthoRight = dx;
        camera.orthoLeft = -dx;
        camera.orthoTop = dy;
        camera.orthoBottom = -dy;

        this.onviewchg(this);
    }

    /* Zoom the camera.
     * 
     * Zooming is not always done around the center, for instance the when zooming with the mouse
     * control, we want to zoom centered where the mouse is hovering.
     * As such, the `mousex` and `mousey` are the ratios from the center of the canvas.
     * - bottom-left is (-1,-1)
     * - top-right is (1,1)
     *
     * Leave blank to zoom around center.
     * A good factor is 0.8 to zoom in and 1.2 to zoom out.
     */
    zoom(factor: number, mousex?: number, mousey?: number) {
        // zooming adjusts for the mouse deviation from the centre
        // this simulates zoom to mouse location
        // centre is (0,0), top-right is (1,1) and bottom left is (-1,-1)
        // at extents of 1, the movement on that edge is zero
        // for a zoom in, (where the diff is shrunk), the delta is +
        // for a zoom out (where the diff is increased), the delta is -
        // y is referenced here, but it would actually be 'z' since y-up
        const camera = this.inner;
        const { otop, obot, olef, orig } = this.get_ortho();
        let dx = orig - olef;
        let dy = otop - obot;
        const x = olef + dx * 0.5;
        const y = obot + dy * 0.5;
        const slipFactor = 0.5
        const xslip = (mousex ?? 0) * dx * (1 - factor) * slipFactor;
        const yslip = (mousey ?? 0) * dy * (1 - factor) * slipFactor;
        dx *= factor * 0.5; // half in each direction
        dy *= factor * 0.5;

        camera.orthoTop = y + yslip + dy;
        camera.orthoBottom = y + yslip - dy;
        camera.orthoLeft = x + xslip - dx;
        camera.orthoRight = x + xslip + dx;
        this.onviewchg(this);
    }

    /* Pan the screen by a ratio of x and y 'viewports'.
        * Negative numbers move opposite direction.
        */
    pan(x: number, y: number) {
        const { otop, obot, olef, orig } = this.get_ortho();
        const dx = (orig - olef) * x;
        const dy = (otop - obot) * y;

        const cam = this.inner;
        cam.orthoLeft = olef + dx;
        cam.orthoRight = orig + dx;
        cam.orthoTop = otop + dy;
        cam.orthoBottom = obot + dy;
        this.onviewchg(this);
    }

    /* Rotate the camera about the current target.
     * Both values are angles in radians.
     * The `bearing` is about the 'up' axis.
     * The `dip` is about the normal to the 'up' axis.
     */
    rotate(bearing: number, dip: number) {
        this.inner.alpha += bearing;
        this.inner.beta += dip;
        this.onviewchg(this);
    }

    toggle_world_axes(canvas: HTMLCanvasElement) {
        if (this.world_axes) {
            this.world_axes.remove();
            this.world_axes = undefined;
        } else {
            const axes = new WorldAxes(this.scene);
            this.world_axes_cb = () => axes.set_position(canvas);

            this.world_axes = axes;
            this.world_axes_cb(); // call initially to position
            this.inner.onViewMatrixChangedObservable.add(this.world_axes_cb);
            this.inner.onProjectionMatrixChangedObservable.add(this.world_axes_cb);
        }
    }

    /* Calculate the _render_ space extents of the view.
        *
        * This uses 4 screen projections from the corners of the canvas.
        */
    viewbox(canvas: HTMLCanvasElement, extents: Extents3): Viewbox {
        const { width, height } = canvas.getBoundingClientRect();
        const view_dir = this.inner.target.subtract(this.inner.position);

        const raybl = this.scene.createPickingRay(0, height, null, this.inner);
        const raybr = this.scene.createPickingRay(width, height, null, this.inner);
        const raytr = this.scene.createPickingRay(width, 0, null, this.inner);
        const raytl = this.scene.createPickingRay(0, 0, null, this.inner);

        const viewbox_data = view_dir.asArray().concat(
            raybl.origin.asArray(),
            raybr.origin.asArray(),
            raytr.origin.asArray(),
            raytl.origin.asArray(),
        );

        return Viewbox.calculate(extents, new Float64Array(viewbox_data));
    }
}

type Ortho = {
    otop: number,
    obot: number,
    olef: number,
    orig: number
};

class Pan {
    ortho: Ortho;
    stride: number;
    capx: number;
    capy: number;

    constructor(camera: Camera, canvas: HTMLCanvasElement) {
        const ortho = camera.get_ortho();
        const scene = camera.scene;
        const rect = canvas.getBoundingClientRect();
        this.ortho = ortho;
        this.stride = (ortho.orig - ortho.olef) / rect.width;
        this.capx = scene.pointerX;
        this.capy = scene.pointerY;
    }

    do_pan(camera: Camera) {
        // gets the difference in mouse coords, and applies them to the ortho view
        // notice the inverted notions of x and y (since x is from left, and y is from top)
        const xd = (this.capx - camera.scene.pointerX) * this.stride;
        const yd = (camera.scene.pointerY - this.capy) * this.stride;
        const cam = camera.inner;
        const ortho = this.ortho;

        cam.orthoTop = ortho.otop + yd;
        cam.orthoBottom = ortho.obot + yd;
        cam.orthoLeft = ortho.olef + xd;
        cam.orthoRight = ortho.orig + xd;
    }
}

class Rotate {
    capx: number = 0;
    capy: number = 0;
    cap_alpha: number = 0;
    cap_beta: number = 0;
    rect: DOMRect = new DOMRect();
    axes: WorldAxes;

    private constructor(axes: WorldAxes) {
        this.axes = axes;
    }

    static start(camera: Camera, canvas: HTMLCanvasElement): Rotate | undefined {
        const scene = camera.scene;
        const x = scene.pointerX;
        const y = scene.pointerY;

        const pt = scene.pick(x, y).pickedPoint;
        if (!pt)
            return undefined;

        // rotating around camera target using alpha and beta.
        // since we want it to rotate around a _point_, the target changes, but we don't want the
        // view to change. we exploit the ortho settings along with adjustments from where the pointer
        // is picked (screen offsets)
        // where the target was does not matter, only that the point is proportionally offset with the new
        // ortho settings

        const { orig, olef, otop, obot } = camera.get_ortho();
        const width = orig - olef;
        const height = otop - obot;

        const cam = camera.inner;
        const rect = canvas.getBoundingClientRect();

        const posVec = cam.position.subtract(cam.target);
        cam.setTarget(pt);
        cam.setPosition(pt.add(posVec));
        cam.orthoLeft = x / rect.width * width * -1.0;
        cam.orthoRight = cam.orthoLeft + width;
        cam.orthoTop = y / rect.height * height;
        cam.orthoBottom = cam.orthoTop - height;

        const axes = new WorldAxes(scene);
        axes.set_position(canvas, cam.target);

        const r = new Rotate(axes);
        r.capx = x;
        r.capy = y;
        r.cap_alpha = cam.alpha;
        r.cap_beta = cam.beta;
        r.rect = rect;

        return r;
    }

    do_rotate(camera: Camera) {
        // mouse x change rotates about 'z' axis. since we are in y-up land, this is rotation about y
        // mouse y change rotates about normal to 'z'(y) and position vector
        // get % of mouse movement
        const dx = (this.capx - camera.scene.pointerX) / this.rect.width;
        const dy = (this.capy - camera.scene.pointerY) / this.rect.height;

        camera.inner.alpha = this.cap_alpha + Math.PI * dx;
        camera.inner.beta = this.cap_beta + Math.PI * dy;
    }

    dispose(): undefined {
        this.axes.remove();
        return undefined;
    }
}