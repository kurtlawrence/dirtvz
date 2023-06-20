import { HemisphericLight, Scene, Vector3, Color3, DirectionalLight, ShadowGenerator } from "@babylonjs/core";
import { Camera } from "./camera";

export class Light {
    sun: DirectionalLight;
    ambient: HemisphericLight;

    constructor(scene: Scene, camera: Camera) {
        const sundir = new Vector3(-0.5, -1, 0);
        const sun = new DirectionalLight('sun', Vector3.Down(), scene);
        sun.intensity = 0.1;
        this.sun = sun;

        this.ambient = new HemisphericLight('ambient-up', Vector3.Up(), scene);
        this.ambient.intensity = 0.9;
        this.ambient.specular = Color3.Black();
    }
}
