import { HemisphericLight, Scene, Vector3, Color3, DirectionalLight } from "@babylonjs/core";
import { Camera } from "./camera";

export class Light {
    sun: DirectionalLight;
    ambient: HemisphericLight;

    constructor(scene: Scene, camera: Camera) {
        const sun = new DirectionalLight('sun', Vector3.Down(), scene);
        sun.intensity = 0.1;
        this.sun = sun;

        this.ambient = new HemisphericLight('ambient-up', Vector3.Up(), scene);
        this.ambient.intensity = 0.9;
        this.ambient.specular = Color3.Black();
    }

    /** Redirection light along bearing and slope.
     *  We assume that the numbers are in **degrees** and the orientation describes the
     *  direction that the light is coming from (like wind direction).
     *  Note also that bearing **starts** at 'up', that is 0 degrees is an angle of 90.
     */
    redirect(bearing: number, slope: number) {
        let t = bearing + 90; // turn into polar angle
        t = t * Math.PI / 180; // convert to radians
        const b = slope * Math.PI / 180;

        // start with the xz polar coords (we are in Yup land)
        const dir = new Vector3(Math.cos(t), 0, Math.sin(t));

        dir
            .scaleInPlace(Math.cos(b)) // scale by the slope's xz mag
            .addInPlaceFromFloats(0, Math.sin(b), 0) // add the slope's rise
            .normalize();

        this.ambient.direction = dir;
        this.sun.direction = dir.negate();
    }
}
