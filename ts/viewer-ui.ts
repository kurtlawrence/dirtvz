import { Viewer } from "./viewer";
import * as loader from './local-loader';

export { viewerUi };

let VWR: Viewer | null;

function viewerUi(element: HTMLElement | string) {
  let node: HTMLElement | null;
  if (element instanceof HTMLElement) node = element;
  else node = document.getElementById(element);

  customElements.define("dirtvis-viewer", CanvasRenderer);

  const flags = {};

  const app = require("./../js/viewer-ui.js").Elm.ViewerUI.init({
    node,
    flags,
  });

  // wire in ports
  // routeNotice(app);

  app.ports.pickSpatialFile.subscribe(() => {
    let input = document.createElement("input");
    input.type = "file";
    input.onchange = (_) => {
      if (input.files && input.files.length > 0) {
		  app.ports.getNotice.send({ lvl: 'Waiting', msg: 'Reading local file'});
        loader.parse_file(input.files[0])
          .then((x) => VWR?.load_object("testkey", x.obj))
          .catch((e) => app.ports.getNotice.send({ lvl: "Err", msg: e.message }));
      }
    };
    input.click();
  });
}

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
    Viewer.init(this.canvas, "test-db").then((x) => (VWR = x));
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

