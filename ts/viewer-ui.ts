import { Viewer } from "./viewer";
import { spawn } from './worker-spawn';
import { Store } from './store';
import { Status } from "./spatial-obj";

export { viewerUi };

let VWR: Viewer | null;
const DBNAME: string = 'test-db';

async function viewerUi(element: HTMLElement | string) {
  let node: HTMLElement | null;
  if (element instanceof HTMLElement) node = element;
  else node = document.getElementById(element);

  customElements.define("dirtvis-viewer", CanvasRenderer);

  const flags = {};

  const app = require('./../js/viewer-ui.js').Elm.ViewerUI.init({
    node,
    flags,
  });

  // wire in ports
  // routeNotice(app);

  const store = await Store.connect(DBNAME);

  // fire off the initial object list
  store.get_object_list().then(app.ports.objectList.send);

  start_preprocessing_interval(app, store, 1000);

  app.ports.pickSpatialFile.subscribe(() => {
    let input = document.createElement("input");
    input.type = "file";
    input.onchange = (_) => {
      if (input.files && input.files.length > 0) {
        let file = input.files[0];
        app.ports.getNotice.send(ElmMsg.waiting('Reading local file'));

        spawn()
          .then(loader => loader.methods.read_load_and_store_from_spatial_file(DBNAME, file))
          .then(() => store.get_object_list())
          .then(app.ports.objectList.send)
          .then(() => app.ports.getNotice.send(ElmMsg.ok('Stored object')))
          .catch((e) => app.ports.getNotice.send(ElmMsg.err(e.message)));
      }
    };
    input.click();
  });

  app.ports.deleteSpatialObject.subscribe((key: string) => {
    store.delete_object(key)
      .then(() => app.ports.getNotice.send(ElmMsg.ok(`Deleted ${key}`)))
      .then(() => store.get_object_list())
      .then(app.ports.objectList.send);
  })
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
    Viewer.init(this.canvas, DBNAME).then((x) => (VWR = x));
  }

  disconnectedCallback() {
    VWR = null;
    this.removeChild(this.canvas);
  }
}

function routeNotice(app: any) {
  app.ports.setNotice.subscribe((notice: any) =>
    app.ports.getNotice.send(notice)
  );
}

async function start_preprocessing_interval(app: any, store: Store, millis: number) {
  const worker = await spawn();
  // maintain a set to avoid overlapping preprocessing
  const processing = new Set();
  // run every `millis`
  setInterval(async () => {
    // get objs that are preprocessing
    let tostart = (await store.get_object_list())
      .filter(x => x.status == Status.Preprocessing && !processing.has(x.key));
    // and add to set
    tostart.forEach(x => processing.add(x.key));

    tostart.forEach(x => {
      // fork off the processing onto a worker
      const timerkey = `preprocess: ${x.key}`;
      console.time(timerkey);
      worker.methods.preprocess_spatial_object(store.db_name, x.key)
        .then(async () => {
          console.timeEnd(timerkey);
          // once it is done, update the store and set
          let obj = await store.find_object(x.key) ?? x;
          obj.status = Status.Ready;
          await store.update_object_list(obj);
          processing.delete(x.key);
          // return some progress.
          return store.get_object_list().then(app.ports.objectList.send);
        })
        .catch(e => console.error({ msg: `preprocessing failed for ${x.key}`, inner: e }));
    });
  }, millis);
}
