import * as BABYLON from '@babylonjs/core'

import { FreeCamera } from "@babylonjs/core/Cameras/freeCamera";
import { Engine } from "@babylonjs/core/Engines/engine";
import { HemisphericLight } from "@babylonjs/core/Lights/hemisphericLight";
import { Vector3 } from "@babylonjs/core/Maths/math.vector";
import { CreateGround } from "@babylonjs/core/Meshes/Builders/groundBuilder";
import { CreateSphere } from "@babylonjs/core/Meshes/Builders/sphereBuilder";
import { Scene } from "@babylonjs/core/scene";


export { Viewer };

class Viewer {

    canvas: HTMLCanvasElement;
    engine: BABYLON.Engine;

    constructor(canvas: HTMLCanvasElement) {
        this.canvas = canvas;
        this.engine = new BABYLON.Engine(canvas);
    }

    init() {
        // Create our first scene.
        var scene = new Scene(this.engine);

        // This creates and positions a free camera (non-mesh)
        var camera = new FreeCamera("camera1", new Vector3(0, 5, -10), scene);

        // This targets the camera to scene origin
        camera.setTarget(Vector3.Zero());

        // This attaches the camera to the canvas
        camera.attachControl(this.canvas, true);

        // This creates a light, aiming 0,1,0 - to the sky (non-mesh)
        var light = new HemisphericLight("light1", new Vector3(0, 1, 0), scene);

        // Default intensity is 1. Let's dim the light a small amount
        light.intensity = 0.7;

        // Our built-in 'sphere' shape.
        var sphere = CreateSphere("sphere1", { segments: 16, diameter: 2 }, scene);

        // Move the sphere upward 1/2 its height
        sphere.position.y = 2;

        // Our built-in 'ground' shape.
        var ground = CreateGround("ground1", { width: 6, height: 6, subdivisions: 2 }, scene);

        // Render every frame
        this.engine.runRenderLoop(() => {
            scene.render();
        });
    }
}