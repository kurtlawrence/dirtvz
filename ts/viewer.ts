import * as BABYLON from '@babylonjs/core'

import { FreeCamera } from "@babylonjs/core/Cameras/freeCamera";
import { HemisphericLight } from "@babylonjs/core/Lights/hemisphericLight";
import { Vector3 } from "@babylonjs/core/Maths/math.vector";
import { CreateGround } from "@babylonjs/core/Meshes/Builders/groundBuilder";
import { CreateSphere } from "@babylonjs/core/Meshes/Builders/sphereBuilder";
import { Scene } from "@babylonjs/core/scene";
import { TriangleMeshSurface } from './data/trimesh-surface';
import { SpatialObject } from './spatial-obj';
import { Store } from './store';


export { Viewer };

class Viewer {

    canvas: HTMLCanvasElement;
    engine: BABYLON.Engine;
    store: Store;

    private constructor(canvas: HTMLCanvasElement, store: Store) {
        this.canvas = canvas;
        this.engine = new BABYLON.Engine(canvas);
        this.store = store;
    }

    /**
     * Create and attach viewer engine to a canvas element.
     * 
     * @param canvas The element to render to.
     * @param db_name The name of the database to connect to. Databases can be shared
     * amongst viewers. Each database defines a data extents for which objects are
     * translated about.
     */
    static async init(canvas: HTMLCanvasElement, db_name: string): Promise<Viewer> {
        const store = await Store.connect(db_name);
        const vwr = new Viewer(canvas, store);
        // await vwr.engine.initAsync(); // needed for WGPU engine

        // Create our first scene.
        var scene = new Scene(vwr.engine);

        // This creates and positions a free camera (non-mesh)
        var camera = new FreeCamera("camera1", new Vector3(0, 5, -10), scene);

        // This targets the camera to scene origin
        camera.setTarget(Vector3.Zero());

        // This attaches the camera to the canvas
        camera.attachControl(vwr.canvas, true);

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
        vwr.engine.runRenderLoop(() => {
            scene.render();
        });

        return vwr;
    }

    load_object(key: string, obj: TriangleMeshSurface): SpatialObject {



        throw new Error("");



    }
}
