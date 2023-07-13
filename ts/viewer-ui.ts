import { Viewer } from "./viewer/viewer";
import { spawn, spawn_pool } from './worker-spawn';
import { Store } from './store';
import { FlatTreeItem, Status } from "./spatial-obj";
import { prog_channel } from "./prg-stream";

export { viewerUi };

let VWR: Viewer | undefined;
let APP: any;
const DBNAME: string = 'test-db';

async function viewerUi(element: HTMLElement | string) {
    let node: HTMLElement | null;
    if (element instanceof HTMLElement) node = element;
    else node = document.getElementById(element);

    customElements.define("dirtvz-viewer", CanvasRenderer);

    const flags = {
        object_tree: PersistObjectTree.get(DBNAME),
    };

    APP = require('./../js/viewer-ui.js').Elm.ViewerUI.init({
        node,
        flags,
    });

    // wire in ports
    // routeNotice(app);

    const store = await Store.connect(DBNAME);

    // fire off the initial object list
    store.get_object_list().then(APP.ports.object_list.send);

    start_preprocessing_interval(APP, store, 1000);

    APP.ports.pick_spatial_file.subscribe(() => {
        let input = document.createElement("input");
        input.type = "file";
        input.onchange = (_) => {
            if (input.files && input.files.length > 0) {
                let file = input.files[0];
                ElmMsg.waiting('Reading local file').send();

                spawn()
                    .then(loader => loader.methods.read_load_and_store_from_spatial_file(DBNAME, file))
                    .then(toadd => {
                        APP.ports.merge_object_flat_tree.send(toadd);
                        return store.get_object_list();
                    })
                    .then(APP.ports.object_list.send)
                    .then(() => ElmMsg.ok('Stored object').send())
                    .catch((e) => ElmMsg.err(e.message).send());
            }
        };
        input.click();
    });

    APP.ports.delete_spatial_object.subscribe(async (key: string) => {
        console.debug(`Asked to delete ${key}`);
        VWR?.unload_object(key);
        await store.mark_deletion(key);
        store.get_object_list().then(APP.ports.object_list.send);

        await store.delete_object(key);
        ElmMsg.ok(`Deleted ${key}`).send();
        store.get_object_list().then(APP.ports.object_list.send);
    });

    APP.ports.object_load.subscribe((key: string) => {
        console.debug(`Please load ${key}`);
        VWR?.load_object(key);
    });
    APP.ports.object_unload.subscribe((key: string) => {
        console.debug(`Please unload ${key}`);
        VWR?.unload_object(key);
    });

    APP.ports.persist_object_tree.subscribe((x: FlatTreeItem[]) =>
        PersistObjectTree.store(DBNAME, x));
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
        APP?.ports.get_notice.send(this);
    }
};

class CanvasRenderer extends HTMLElement {
    canvas: HTMLCanvasElement;
    obs?: ResizeObserver;
    resize_timeout: any;

    constructor() {
        super();

        const canvas = document.createElement("canvas");
        this.canvas = canvas;
        this.canvas.style.display = 'block';
    }

    connectedCallback() {
        this.obs = new ResizeObserver(e => {
            clearTimeout(this.resize_timeout);
            this.resize_timeout = setTimeout(() => this.sizeCanvas(e[0]), 100);
        });
        this.obs.observe(this);
        this.obs.observe(document.body);

        this.appendChild(this.canvas);

        Viewer.init(this.canvas, DBNAME).then((x) => {
            x.onhover(info => {
                // console.debug(info);
                APP?.ports.hover_info.send(JSON.stringify(info));
            });
            VWR = x;
        });
    }

    disconnectedCallback() {
        VWR = undefined;
        this.obs?.disconnect();
        this.obs = undefined;
        this.removeChild(this.canvas);
    }

    sizeCanvas(size: ResizeObserverEntry) {
        this.removeChild(this.canvas);
        const rect = this.getBoundingClientRect();
        this.canvas.height = rect.height;
        this.canvas.width = rect.width;
        this.appendChild(this.canvas);
        VWR?.canvas_size_changed();
    }
}

function routeNotice(app: any) {
    app.ports.set_notice.subscribe((notice: any) =>
        app.ports.get_notice.send(notice)
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
                // begin a progress stream
                const stream = prog_channel({
                    recv(prg) { APP?.ports.recv_progress.send(prg); }
                });

                // fork off the processing onto a worker
                const timerkey = `preprocess: ${x.key}`;
                console.time(timerkey);
                const extents_chgd = await worker.queue(w => {
                    return w.methods.preprocess_spatial_object(store.db_name, x.key, stream);
                });
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
                store.get_object_list().then(app.ports.object_list.send);
            } catch (e) {
                console.error({ msg: `preprocessing failed for ${x.key}`, inner: e });
            }
        }
    }, millis);
}

class PersistObjectTree {
    static store(db_name: string, flat_tree: FlatTreeItem[]) {
        localStorage.setItem(`${db_name}/object-tree`, JSON.stringify(flat_tree));
    }

    static get(db_name: string): FlatTreeItem[] | null {
        const x = localStorage.getItem(`${db_name}/object-tree`);
        if (x)
            return JSON.parse(x);
        else
            return null;
    }
}