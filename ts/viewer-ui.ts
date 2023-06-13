import { Viewer } from "./viewer";
import { spawn } from './worker-spawn';
import { Store } from './store';

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

  app.ports.pickSpatialFile.subscribe(() => {
    let input = document.createElement("input");
    input.type = "file";
    input.onchange = (_) => {
      if (input.files && input.files.length > 0) {
        let file = input.files[0];
        app.ports.getNotice.send(ElmMsg.waiting('Reading local file'));

		spawn()
		.then(loader => loader.methods.read_load_and_store_from_spatial_file(DBNAME, file))
		.then(() => app.ports.getNotice.send(ElmMsg.ok('Stored object')))
		.then(async () => await store.get_object_list())
		.then(app.ports.objectList.send)
        .catch((e) => app.ports.getNotice.send(ElmMsg.err(e.message)));
      }
    };
    input.click();
  });
}

class ElmMsg {
	constructor(public lvl: string, public msg: string) {}

	static err(msg: string) : ElmMsg {
		return new ElmMsg("Err", msg);
	}

	static ok(msg: string) : ElmMsg {
		return new ElmMsg("Ok", msg);
	}

	static waiting(msg: string) : ElmMsg {
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

