# dirtvz 🔎⛰🔍

_Web-based, high performance 3D renderer for the mining industry._


- [App 🔎⛰🔍](https://kurtlawrence.github.io/dirtvz/)

Dirtvz is an experimental web-based 3D renderer targeted specifically at the dataset common within
the mining industry.
Dirtvz excels at rendering large, detailed surfaces using novel concepts of tiling and level of
detail built first class into the API.
Dirtvz consists of a library and an app, where the app is targeted as a 'batteries included' web
app that can be included in user apps with low friction.
The library is for inclusion in larger app stacks.
Dirtvz aims to be both a utility and a practical research project. As web-based 3D rendering
continues to improve, dirtvz aims to explore the practical challenges and present solutions which
can be extended to other projects.

> 🧪 `dirtvz` is in a highly experimental stage, focused on prototyping technologies and
> techniques to enable high performance rendering of large mining datasets through the browser.
> Please note that dirtvz is is in very early stages of prototyping and there are no stability
> guarantees. The included app is still very rudimentary and support for various objects is
> limited.
> See [Features Roadmap](#Features-Roadmap) for checklist to MVP.

# Features Roadmap

This is a quick list of items needing development.
As the project matures, Github issues will be adopted more formally.

- [x] camera interactions
- [x] information about cursor location in world coords
- [ ] alter lighting properties (UI picker)
- [ ] two toned meshes
- [ ] mesh textures
- [ ] mesh aerial
- [ ] mesh edge rendering
- [ ] grid render
- [x] make gh repo
- [ ] world axis (persistent and on rotate) -- needs UI toggle
- [ ] background (UI chooser)
- [ ] make axes not pickable
- [ ] button to zoom data extents
- [ ] `p` for plan view (top down), `p` again to north up, `p` again to reset view
- [ ] UI toggle for invert mouse scroll
- [ ] UI help for interactions
- [x] dynamic filtering tile/lod
- [ ] apply pipeline optimisations and anti-aliasing
- [ ] ? Load raw triangles at finest lod detail
- [ ] world axis behaves poorly at zoom levels
- [ ] world axis clips on edges
- [ ] ? rework database to create a store _per object_
- [ ] progress on preprocessing
- [ ] ? support for large surfaces (progressive sampling?)
- [ ] import preprocessing performance (parallelise or cache sampling points)

# Developing commands

```sh
# Build Rust to WASM
#   use --debug for debugging, BUT IS VERY SLOW!
#   use --features=err-capture to get Rust stack trace printed to console
wasm-pack build --out-dir wasmpkg --out-name wasm --target bundler
# Builds Elm
elm make elm/ViewerUI.elm --output=js/viewer-ui.js
# Builds Typescript and bundles
npm run build
# Runs local dev server
npm start
```
