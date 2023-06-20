// import * as BABYLON from 'babylonjs'; // uncomment when developing

class CAD {
    canvas: HTMLCanvasElement;
    engine: BABYLON.Engine;
    scene: BABYLON.Scene;
    camera: BABYLON.ArcRotateCamera;
    layers: Array<BABYLON.AbstractMesh>;
    measure: Measure | null;
    measureTranslation: BABYLON.Vector3;
    skybox: BABYLON.Mesh;

    constructor(canvas: HTMLCanvasElement, engine: BABYLON.Engine) {
        this.layers = [];
        this.canvas = canvas;
        this.engine = engine;
        this.scene = new BABYLON.Scene(this.engine);
        this.camera = new BABYLON.ArcRotateCamera('camera', 0, 0, 20, BABYLON.Vector3.Zero(), this.scene);
        this.measureTranslation = BABYLON.Vector3.Zero();
    }

    init() {
        this.initCamera();
        this.initLight();
        this.initPipeline();
        this.initMeasure();
        this.initWindowEvents();
        this.engine.runRenderLoop(() => this.scene.render());
    }

    initCamera() {
        let canvas = this.canvas;

        canvas.addEventListener('dblclick', ev => this.zoomAll());
        canvas.addEventListener('contextmenu', ev => {
            ev.preventDefault();
            return false;
        });
    }

    initLight() {
        const dir = new BABYLON.Vector3(0, 1, 0);
        const specColour = new BABYLON.Color3(0.2, 0.188, 0.166);
        const light1 = new BABYLON.HemisphericLight('hemispheric-light-1', dir, this.scene);
        light1.specular = specColour;
        light1.intensity = 0.9;
    }

    initPipeline() {
        const pipeline = new BABYLON.DefaultRenderingPipeline(
            "defaultPipeline", // The name of the pipeline
            true, // Do you want the pipeline to use HDR texture?
            this.scene, // The scene instance
            [this.camera] // The list of cameras to be attached to
        );
        pipeline.samples = 8;
        pipeline.fxaaEnabled = false;
        pipeline.sharpenEnabled = true;
        pipeline.bloomEnabled = true;
    }

    initMeasure() {
        this.canvas.addEventListener('keypress', ev => {
            if (ev.key == 'm') {
                if (this.measure) {
                    this.measure.stop();
                    this.measure = null;
                }
                else {
                    this.measure = Measure.start(this.canvas, this.scene, this.measureTranslation);
                }
            }
        });

        this.scene.onPointerMove = (ev, info) => {
            if (this.measure) { this.measure.hoverInfo(); }
        };

        this.scene.onPointerDown = (ev, info) => {
            const pt = this.scene.pick(this.scene.pointerX, this.scene.pointerY);
            if (this.measure && pt.pickedPoint) {
                this.measure.placePoint(pt.pickedPoint);
            }
        };
    }

    initWindowEvents() {
        window.addEventListener('resize', () => {
            this.engine.resize();
            this.zoomAll();
        });
    }

    zoomAll() {
        // zoom all needs to consider a few things:
        // 1. need to capture all meshes, note that we are in y-up land, so x/z is considered bounds
        // 2. the canvas aspect ratio impacts which axis is the bounded one
        // 3. the camera needs to maintain 1:1 for x:z ratio
        const bnds = BABYLON.Mesh.MinMax(this.layers);

        const cntr = BABYLON.Vector3.Center(bnds.min, bnds.max); // centroid of bounds
        const diff = bnds.max.subtract(bnds.min).scale(0.6); // 50% with add 20% padding
        let dx: number;
        let dy: number; // note that this will be done on z!!!

        const rect = this.canvas.getBoundingClientRect();
        const canvasAspect = rect.width / rect.height;
        const extentsAspect = diff.x / diff.z; // on z!!!!!

        // notice that the unbound dim uses the bound dim!
        if (extentsAspect > canvasAspect) {
            // there is more x than canvas aspect ratio, bound x
            dx = diff.x;
            dy = diff.x / canvasAspect;
        } else {
            // there is more y(z!) than canvas aspect ratio, bound y
            dy = diff.z;
            dx = diff.z * canvasAspect;
        }

        // Set the camera target and position first
        // target in the cntr
        // position is cntr xy but in air (with draw depth) (y-up land)
        this.camera.setTarget(cntr);
        this.camera.upVector = BABYLON.Vector3.Up();
        this.camera.setPosition(new BABYLON.Vector3(cntr.x, cntr.y + CAD.DRAWZ * 0.2, cntr.z));
        this.camera.alpha = Math.PI * 1.5; // z facing north (in y-up land)

        // after a bit of trial and error, ortho parameters are in SCENE units, which has (0,0) at
        // the the target of the camera!!!!
        this.camera.orthoRight = dx;
        this.camera.orthoLeft = -dx;
        this.camera.orthoTop = dy;
        this.camera.orthoBottom = -dy;
    }

    showWorldAxis(size) {
        var makeTextPlane = function (scene, text, color, size) {
            var dynamicTexture = new BABYLON.DynamicTexture("DynamicTexture", 50, scene, true);
            dynamicTexture.hasAlpha = true;
            dynamicTexture.drawText(text, 5, 40, "bold 36px Arial", color, "transparent", true);
            var plane = BABYLON.Mesh.CreatePlane("TextPlane", size, scene, true);
            plane.material = new BABYLON.StandardMaterial("TextPlaneMaterial", scene);
            plane.material.backFaceCulling = false;
            // plane.material.specularColor = new BABYLON.Color3(0, 0, 0);
            // plane.material.diffuseTexture = dynamicTexture;
            return plane;
        };
        var axisX = BABYLON.Mesh.CreateLines("axisX", [
            BABYLON.Vector3.Zero(), new BABYLON.Vector3(size, 0, 0), new BABYLON.Vector3(size * 0.95, 0.05 * size, 0),
            new BABYLON.Vector3(size, 0, 0), new BABYLON.Vector3(size * 0.95, -0.05 * size, 0)
        ], this.scene);
        axisX.color = new BABYLON.Color3(1, 0, 0);
        axisX.renderingGroupId = 1;
        var xChar = makeTextPlane(this.scene, "X", "red", size / 10);
        xChar.position = new BABYLON.Vector3(0.9 * size, -0.05 * size, 0);
        var axisY = BABYLON.Mesh.CreateLines("axisY", [
            BABYLON.Vector3.Zero(), new BABYLON.Vector3(0, size, 0), new BABYLON.Vector3(-0.05 * size, size * 0.95, 0),
            new BABYLON.Vector3(0, size, 0), new BABYLON.Vector3(0.05 * size, size * 0.95, 0)
        ], this.scene);
        axisY.color = new BABYLON.Color3(0, 1, 0);
        axisY.renderingGroupId = 1;
        var yChar = makeTextPlane(this.scene, "Y", "green", size / 10);
        yChar.position = new BABYLON.Vector3(0, 0.9 * size, -0.05 * size);
        var axisZ = BABYLON.Mesh.CreateLines("axisZ", [
            BABYLON.Vector3.Zero(), new BABYLON.Vector3(0, 0, size), new BABYLON.Vector3(0, -0.05 * size, size * 0.95),
            new BABYLON.Vector3(0, 0, size), new BABYLON.Vector3(0, 0.05 * size, size * 0.95)
        ], this.scene);
        axisZ.color = new BABYLON.Color3(0, 0, 1);
        axisZ.renderingGroupId = 1;
        var zChar = makeTextPlane(this.scene, "Z", "blue", size / 10);
        zChar.position = new BABYLON.Vector3(0, 0.05 * size, 0.9 * size);
    }

    addSkyBox() {
        // get center
        const bnds = BABYLON.Mesh.MinMax(this.layers);
        const cntr = BABYLON.Vector3.Center(bnds.min, bnds.max); // centroid of bounds
        const size = CAD.DRAWZ * 0.5;
        cntr.y -= size * 0.03; // reduce it's height a little (y-up land!!!)

        if (this.skybox) {
            this.scene.removeMesh(this.skybox);
        }

        this.skybox = BABYLON.MeshBuilder.CreateBox("skyBox", { size }, this.scene);
        this.skybox.position = cntr;
        this.skybox.isPickable = false;

        const skyboxMaterial = new BABYLON.StandardMaterial("skyBox", this.scene);
        skyboxMaterial.backFaceCulling = false;
        skyboxMaterial.reflectionTexture = new BABYLON.CubeTexture("/:assets/gl/skybox2", this.scene);
        skyboxMaterial.reflectionTexture.coordinatesMode = BABYLON.Texture.SKYBOX_MODE;
        skyboxMaterial.diffuseColor = new BABYLON.Color3(0, 0, 0);
        skyboxMaterial.specularColor = new BABYLON.Color3(0, 0, 0);
        this.skybox.material = skyboxMaterial;
    }

    loadMesh(name: string): Promise<BABYLON.Mesh> {
        const mesh = new BABYLON.Mesh(name, this.scene);

        let positions: Float32Array;
        let indices: Uint32Array;
        let normals: Float32Array;

        let a = fetchBinData('mesh', name, 'positions').then(x => positions = new Float32Array(x));
        let b = fetchBinData('mesh', name, 'indices').then(x => indices = new Uint32Array(x));
        let c = fetchBinData('mesh', name, 'normals').then(x => normals = new Float32Array(x));

        return Promise.all([a, b, c]).then(x => {
            console.debug('Received all components of a mesh: ' + name);

            const vertexData = new BABYLON.VertexData();

            console.debug({
                msg: 'Mesh data metrics',
                poslen: positions.length,
                indlen: indices.length,
                normlen: normals.length,
            });

            vertexData.positions = positions;
            vertexData.indices = indices;
            vertexData.normals = normals;

            vertexData.applyToMesh(mesh);

            // PERF: the meshes do NOT share vertices (in an index sense) since to get flat shading
            // there is a distinct position for each vertex (for the normals). This makes the mesh not 
            // send over indices, rather just the raw position data.
            mesh.convertToUnIndexedMesh();

            this.layers.push(mesh);

            return mesh;
        });
    }

    assignMeshAsDustEmitter(mesh: BABYLON.Mesh): BABYLON.Mesh {
        const capacity = 5e3;
        const myParticleSystem = new BABYLON.ParticleSystem("dust-particles", capacity, this.scene);
        myParticleSystem.particleTexture = groundTexture(this.scene);
        const emitter = new BABYLON.MeshParticleEmitter(mesh);
        emitter.useMeshNormalsForDirection = false;
        emitter.direction1 = new BABYLON.Vector3(1, 0, 1);
        emitter.direction1 = new BABYLON.Vector3(1, 0, 0);
        myParticleSystem.particleEmitterType = emitter;
        myParticleSystem.emitter = mesh;
        myParticleSystem.minSize = 0.1;
        myParticleSystem.maxSize = 0.6;
        myParticleSystem.minEmitPower = 50;
        myParticleSystem.maxEmitPower = 100;
        myParticleSystem.emitRate = 200;
        myParticleSystem.minLifeTime = 0.3;
        myParticleSystem.maxLifeTime = 6;
        myParticleSystem.minAngularSpeed = 0;
        myParticleSystem.maxAngularSpeed = 2;
        myParticleSystem.start(); //Starts the emission of particles

        return mesh;
    }

    optimiseScene() {
        // apply properties to meshes to reduce cpu load
        this.layers.forEach(mesh => {
            mesh.material.freeze(); // PERF: reduce shader overhead
            mesh.freezeWorldMatrix(); // PERF: we alter camera not mesh on view changes
            mesh.refreshBoundingInfo();
            mesh.doNotSyncBoundingInfo = true; // PERF: Calced once, should be good.
        });

        this.scene.autoClear = false; // PERF: We always are looking inside skybox
        this.scene.autoClearDepthAndStencil = false; // PERF: We always are looking inside skybox
    }
}

class Measure {
    canvasRect: DOMRect;
    scene: BABYLON.Scene;
    gui: BABYLON.GUI.AdvancedDynamicTexture;
    hoverRect: BABYLON.GUI.Rectangle;
    hoverLabel: BABYLON.GUI.TextBlock;
    mesh: BABYLON.LinesMesh;
    meshIdx: Array<number>;
    meshPos: Array<number>;
    prev: BABYLON.Vector3 | null;
    translation: BABYLON.Vector3;

    static start(canvas: HTMLCanvasElement, scene: BABYLON.Scene, translate: BABYLON.Vector3): Measure {
        console.debug('In Measure mode');

        const gui = BABYLON.GUI.AdvancedDynamicTexture.CreateFullscreenUI("UI");

        const mesh = BABYLON.MeshBuilder.CreateDashedLines('measure-lines', {
            points: [BABYLON.Vector3.Zero()],
            updatable: true,
        }, scene);
        mesh.isPickable = false;
        mesh.color = new BABYLON.Color3(1, 1, 1);

        const m = new Measure();
        m.translation = translate;
        m.canvasRect = canvas.getBoundingClientRect();
        m.scene = scene;
        m.gui = gui;

        m.mesh = mesh;
        m.meshPos = [0, 0, 0];
        m.meshIdx = [0];

        m.newHoverInfo();
        m.hoverInfo();

        return m;
    }

    stop() {
        this.disposeLinesMesh();
        this.gui.removeControl(this.hoverRect);

        this.hoverLabel.dispose();
        this.hoverRect.dispose();
        this.gui.dispose();
    }

    newHoverInfo() {
        var hoverRect = new BABYLON.GUI.Rectangle();
        hoverRect.heightInPixels = 30;
        hoverRect.widthInPixels = 250;
        hoverRect.cornerRadius = 5;
        hoverRect.color = "black";
        hoverRect.thickness = 0;
        hoverRect.background = "#e3e3e3e0";
        hoverRect.isPointerBlocker = false;

        var hoverLabel = new BABYLON.GUI.TextBlock();
        hoverLabel.fontSize = "16px";
        hoverRect.addControl(hoverLabel);

        this.hoverRect = hoverRect;
        this.hoverLabel = hoverLabel;
    }

    disposeLinesMesh() {
        this.scene.removeMesh(this.mesh);
        this.mesh.dispose();
    }

    hoverInfo() {
        const pickInfo = this.scene.pick(this.scene.pointerX, this.scene.pointerY);

        if (pickInfo.pickedPoint) {
            this.gui.addControl(this.hoverRect);
            this.hoverRect.left = this.scene.pointerX - this.canvasRect.width * 0.5;
            this.hoverRect.top = this.scene.pointerY - this.canvasRect.height * 0.5 - 40;
            this.hoverLabel.text = this.hoverText(pickInfo.pickedPoint);
            this.resizeHoverInfo();
            this.updateHoverPos(pickInfo.pickedPoint);
        } else {
            this.gui.removeControl(this.hoverRect);
            this.updateMeshData(true);
        }
    }

    updateHoverPos(pt: BABYLON.Vector3) {
        let len = this.meshPos.length;
        this.meshPos[len - 3] = pt.x;
        this.meshPos[len - 2] = pt.y;
        this.meshPos[len - 1] = pt.z;
        this.updateMeshData(false);
    }

    placePoint(point: BABYLON.Vector3) {
        this.newHoverInfo();
        this.prev = point;
        // extend positions
        this.meshPos.push(point.x);
        this.meshPos.push(point.y);
        this.meshPos.push(point.z);
        const idx = this.meshIdx[this.meshIdx.length - 1] + 1;
        this.meshIdx.push(idx);
        this.meshIdx.push(idx); // line meshes seem to take data as (p1,p2,p2,p3)
        this.updateMeshData(false);
    }

    updateMeshData(dropLast: boolean) {
        let end = this.meshIdx.length;
        if (dropLast) { end -= 2; }
        let d = new BABYLON.VertexData();
        d.indices = this.meshIdx.slice(0, end);
        d.positions = this.meshPos;
        d.applyToMesh(this.mesh);
    }

    resizeHoverInfo() {
        let height = 30;
        let width = 250;
        if (this.hoverLabel.lines) {
            height = Math.min(this.hoverLabel.lines.length * 24 + 6, 80);
            width = 0;
            this.hoverLabel.lines.forEach(x => width = Math.max(x.width, width));
        }
        this.hoverRect.heightInPixels = height;
        this.hoverRect.widthInPixels = width + 40;
    }

    hoverText(pt: BABYLON.Vector3): string {
        let tPt = pt.subtract(this.translation);
        // y-up land
        let msg = `(${tPt.x.toFixed(1)}, ${tPt.z.toFixed(1)}, ${tPt.y.toFixed(2)})`;

        // add vector info if available
        if (this.prev) {
            const todeg = 180.0 / Math.PI;
            // vector
            const v = pt.subtract(this.prev);
            msg += '\n';
            msg += `<${v.x.toFixed(1)}, ${v.z.toFixed(1)}, ${v.y.toFixed(2)}>`;
            // info
            let dist = v.length();
            let bearing = 90 - Math.atan(v.z / v.x) * todeg;
            if (v.x < 0.0) { bearing += 180; }
            let run = Math.sqrt(Math.pow(v.x, 2) + Math.pow(v.z, 2));
            let grade = Number.POSITIVE_INFINITY; // (%)
            let angle = 90;
            if (v.y < 0) {
                grade = Number.NEGATIVE_INFINITY;
                angle = -90;
            }
            if (run > 1e-5) {
                grade = v.y / run;
                angle = Math.atan(grade) * todeg;
            }
            if (grade < 1e-5 && grade > -1e-5) { grade = 0; }
            grade *= 100; // hundred basis

            msg += '\n';
            msg += `[${dist.toFixed(1)} m, ${bearing.toFixed(1)}°, ${grade.toPrecision(3)}% (${angle.toFixed(1)}°)]`;
        }

        return msg;
    }
}

function addEdgeRendering(mesh: BABYLON.Mesh): BABYLON.Mesh {
    const x = 105 / 255; // dimgrey
    mesh.enableEdgesRendering(0.997); // around 3°
    mesh.edgesColor = new BABYLON.Color4(x, x, x, 0.3); // with transparency
    return mesh;
}

// Applies ground texture to the mesh
function applyGroundTexture(scene: BABYLON.Scene, mesh: BABYLON.Mesh): BABYLON.Mesh {
    applyUVs(mesh, 50); // 50 m texture tiling

    const gText = groundTexture(scene);
    const rockNormalMap = new BABYLON.Texture('https://www.babylonjs-playground.com/textures/rockn.png', scene);
    const mat = new BABYLON.StandardMaterial("mat", scene);

    mat.diffuseTexture = gText;
    mat.bumpTexture = rockNormalMap;
    mat.specularColor = new BABYLON.Color3(0.59, 0.46, 0.31);
    mat.backFaceCulling = false;

    mesh.material = mat;

    return mesh;
}

function applyMeshColour(scene: BABYLON.Scene, mesh: BABYLON.Mesh, colour: BABYLON.Color3): BABYLON.Mesh {
    const mat = new BABYLON.StandardMaterial('mesh-colour-material', scene);

    mat.diffuseColor = colour;
    mat.backFaceCulling = false;

    mesh.material = mat;

    return mesh;
}

// Apply UV maps to mesh by setting the u/v to correspond to the x/z position values,
// normalised to bounds of the mesh.
// Divides x/z by size such that a size of 1 would be 1:1 mapping (1m) while a size of 10
// would be a 10:1 mapping (10m tiling)
function applyUVs(mesh: BABYLON.Mesh, size: number) {
    mesh.refreshBoundingInfo();
    const min = mesh.getBoundingInfo().boundingBox.minimumWorld;

    const positions = mesh.getVerticesData(BABYLON.VertexBuffer.PositionKind);
    const uvs = [];

    for (let p = 0; p < positions.length / 3; p++) {
        uvs.push((positions[p * 3] - min.x) / size); // x
        uvs.push((positions[p * 3 + 2] - min.z) / size); // z
    }
    mesh.setVerticesData(BABYLON.VertexBuffer.UVKind, uvs);
}

function groundTexture(scene: BABYLON.Scene): BABYLON.Texture {
    return new BABYLON.Texture('https://1.bp.blogspot.com/-dXMlsHE-rUI/UbWXQcc8aVI/AAAAAAAAEHw/fHwfk_zjVNQ/s1600/Seamless+ground+dirt+texture.jpg', scene);
}

// Returns an array buffer, up to implementors to understand how that data should be interpreted.
function fetchBinData(ty: string, name: string, field: string) {
    const url = '/results/' + ty + '/' + name + '/' + field;
    return fetch(url, {}).then(resp => {
        if (!resp.ok) {
            throw new Error('fetch returned not ok');
        } else {
            return resp.arrayBuffer();
        }
    });
}

class Assets {
    surface: BABYLON.Mesh;
    shaped: BABYLON.Mesh;
    cut: BABYLON.Mesh;
    fill: BABYLON.Mesh;
    floor: BABYLON.Mesh;

    static fetch(cad: CAD, loadingMsgEl: HTMLElement | null): Assets {
        const assets = new Assets();

        fetch('/results/init').then(resp => resp.json())
            .then((r: { msg: string, translation: number[] }) => {
                if (r.msg == 'no results') {
                    console.warn('No shaping results yet');
                    if (loadingMsgEl) {
                        loadingMsgEl.innerHTML = 'No shaping results yet';
                    }
                } else if (r.msg.length != 0) {
                    console.warn('Shaping resulted in error', r.msg);
                    if (loadingMsgEl) {
                        loadingMsgEl.innerHTML = 'Shaping resulted in error: ' + r.msg;
                    }
                } else {
                    cad.measureTranslation = new BABYLON.Vector3(
                        r.translation[0], r.translation[2], r.translation[1] // y-up =/
                    );

                    // proceed to do subsequent loads
                    let a = cad.loadMesh('surface')
                        .then(m => {
                            assets.surface = m;
                            cad.addSkyBox();
                            cad.zoomAll();
                            return m;
                        })
                        .then(m => applyGroundTexture(cad.scene, m))
                        .then(addEdgeRendering);
                        // .then(m => cad.assignMeshAsDustEmitter(m)); // disable dust emitting since I think it bogs performance
                    let b = cad.loadMesh('shaped')
                        .then(m => { assets.shaped = m; return m; })
                        .then(m => applyMeshColour(cad.scene, m, new BABYLON.Color3(0.5, 1, 0.5)))
                        .then(mesh => {
                            // const x = 105 / 255; // dimgrey
                            const x = 40 / 255;
                            mesh.enableEdgesRendering(1); // most edges
                            mesh.edgesColor = new BABYLON.Color4(x, x, x, 1.0); // with transparency
                            return mesh;
                        });
                    let c = cad.loadMesh('cut')
                        .then(m => { assets.cut = m; return m; })
                        .then(m => applyMeshColour(cad.scene, m, new BABYLON.Color3(1, 0, 0)))
                        .then(addEdgeRendering);
                    let d = cad.loadMesh('fill')
                        .then(m => { assets.fill = m; return m; })
                        .then(m => applyMeshColour(cad.scene, m, new BABYLON.Color3(0, 1, 0)))
                        .then(addEdgeRendering);

                    Promise.all([a, b, c, d]).then(_ => {
                        cad.optimiseScene();
                        if (loadingMsgEl) {
                            loadingMsgEl.innerHTML = 'Assets';
                        }
                    });
                }
            })

        return assets;
    }
}
