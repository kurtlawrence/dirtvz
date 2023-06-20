
# Features Roadmap

- [x] camera interactions
- [x] information about cursor location in world coords
- [ ] alter lighting properties (UI picker)
- [ ] two toned meshes
- [ ] mesh textures
- [ ] mesh aerial
- [ ] mesh edge rendering
- [ ] grid render
- [ ] make gh repo
- [ ] world axis (persistent and on rotate) -- needs UI toggle
- [ ] background (UI chooser)
- [ ] make axes not pickable
- [ ] button to zoom data extents
- [ ] `p` for plan view (top down), `p` again to north up, `p` again to reset view
- [ ] UI toggle for invert mouse scroll
- [ ] UI help for interactions
- [ ] dynamic filtering tile/lod
- [ ] apply pipeline optimisations and anti-aliasing


# Developing commands

```sh
# Build Rust to WASM (use --debug for debugging, BUT IS VERY SLOW!)
wasm-pack build --out-dir wasmpkg --out-name wasm --target bundler
# Builds Elm
elm make elm/ViewerUI.elm --output=js/viewer-ui.js
# Builds Typescript and bundles
npm run build
# Runs local dev server
npm start
```
