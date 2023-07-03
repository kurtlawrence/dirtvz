import { Viewer } from "./viewer/viewer";
import { spawn, spawn_pool } from './worker-spawn';
import { Store } from './store';
import { Status } from "./spatial-obj";

export { viewerUi };

let VWR: Viewer | undefined;
let APP: any;
const DBNAME: string = 'test-db';

async function viewerUi(element: HTMLElement | string) {
    let node: HTMLElement | null;
    if (element instanceof HTMLElement) node = element;
    else node = document.getElementById(element);

    customElements.define("dirtvis-viewer", CanvasRenderer);

    const flags = {};

    APP = require('./../js/viewer-ui.js').Elm.ViewerUI.init({
        node,
        flags,
    });

    // wire in ports
    // routeNotice(app);

    const store = await Store.connect(DBNAME);

    // fire off the initial object list
    store.get_object_list().then(APP.ports.objectList.send);

    start_preprocessing_interval(APP, store, 1000);

    APP.ports.pickSpatialFile.subscribe(() => {
        let input = document.createElement("input");
        input.type = "file";
        input.onchange = (_) => {
            if (input.files && input.files.length > 0) {
                let file = input.files[0];
                ElmMsg.waiting('Reading local file').send();

                spawn()
                    .then(loader => loader.methods.read_load_and_store_from_spatial_file(DBNAME, file))
                    .then(() => store.get_object_list())
                    .then(APP.ports.objectList.send)
                    .then(() => ElmMsg.ok('Stored object').send())
                    .catch((e) => ElmMsg.err(e.message).send());
            }
        };
        input.click();
    });

    APP.ports.deleteSpatialObject.subscribe((key: string) => {
        store.delete_object(key)
            .then(() => ElmMsg.ok(`Deleted ${key}`).send())
            .then(() => store.get_object_list())
            .then(APP.ports.objectList.send);
    })

    APP.ports.toggleLoaded.subscribe((key: string) => {
        VWR?.toggle_object(key);
    });
}

class ElmMsg {
    constructor(public lvl: string, public msg: string) { }

    static err(msg: string): ElmMsg {
        return new ElmMsg("Err", msg);
    }

    static ok(msg: string): ElmMsg {
        return new ElmMsg("Ok", msg);
    }

    static waiting(msg: string): ElmMsg {
        return new ElmMsg("Waiting", msg);
    }

    send() {
        APP?.ports.getNotice.send(this);
    }
};

class CanvasRenderer extends HTMLElement {
    canvas: HTMLCanvasElement;

    constructor() {
        super();

        const canvas = document.createElement("canvas");
        canvas.style.height = "100%";
        canvas.style.width = "100%";

        this.canvas = canvas;
    }

    connectedCallback() {
        this.appendChild(this.canvas);
        Viewer.init(this.canvas, DBNAME).then((x) => {
            x.onhover(info => APP?.ports.hoverInfo.send(JSON.stringify(info)));
            VWR = x;
        });
    }

    disconnectedCallback() {
        VWR = undefined;
        this.removeChild(this.canvas);
    }
}

function routeNotice(app: any) {
    app.ports.setNotice.subscribe((notice: any) =>
        app.ports.getNotice.send(notice)
    );
}

async function start_preprocessing_interval(app: any, store: Store, millis: number) {
    const worker = await spawn_pool();
    // maintain a set to avoid overlapping preprocessing
    const processing = new Set();
    // run every `millis`
    setInterval(async () => {
        // get objs that are preprocessing
        let tostart = (await store.get_object_list())
            .filter(x => x.status == Status.Preprocessing && !processing.has(x.key));
        // and add to set
        tostart.forEach(x => processing.add(x.key));

        for (const x of tostart) {
            try {
                // fork off the processing onto a worker
                const timerkey = `preprocess: ${x.key}`;
                console.time(timerkey);
                const extents_chgd = await worker.queue(w =>
                    w.methods.preprocess_spatial_object(store.db_name, x.key));
                console.timeEnd(timerkey);

                if (extents_chgd && VWR) {
                    const xs = await store.extents();
                    if (xs)
                        VWR.store_extents_changed(xs);
                }

                // once it is done, update the store and set
                let obj = await store.find_object(x.key) ?? x;
                obj.status = Status.Ready;
                await store.update_object_list(obj);
                processing.delete(x.key);
                // return some progress.
                store.get_object_list().then(app.ports.objectList.send);
            } catch (e) {
                console.error({ msg: `preprocessing failed for ${x.key}`, inner: e });
            }
        }
    }, millis);
}
