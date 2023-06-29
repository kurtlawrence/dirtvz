# Production Building and Deployment

## Production Building

Production building follows development building closely with a few tweaks to flags and
minification.

```sh
# Build Rust to WASM
wasm-pack build --out-dir wasmpkg --out-name wasm --target bundler
# Builds Elm
elm make elm/ViewerUI.elm --output=js/viewer-ui.js --optimize
# Builds Typescript and bundles
npm run build
```

There should now exist the following files in the `dist/` folder:
```plaintext
*.module.wasm    <-- Note that file name will be different
dirtvz.js        <-- library
dirtvz-ui.js     <-- UI implementation
dirtvz-worker.js <-- WebWorker
index.html       <-- app-site
```

### Minification

All the `.js` files can be minified. `uglifyjs` is used to achieve this.

```sh
uglifyjs dist/*.js --mangle --compress --in-situ
```

## Github Pages `app-site` branch

To update the demo app site at https://kurtlawrence.github.io/dirtvz, a static site needs to be
geneated in the `app-site` branch.
Note that this operation is _destructive_ so it is recommended to be done in a separate directory.

**Step 1. Build production artifacts**

Follow [Production Building](#Production-Building).

**Step 2. Deploy on `app-site` branch**

```sh
mkdir tmp-dirtvz-app-push
cd tmp-dirtvz-app-push
git clone -b app-site git@github.com:kurtlawrence/dirtvz.git .
rm * -v
cp ../dist/* .
git add .
git commit -m "release app site"
git push
cd ..
rm tmp-dirtvz-app-push -rfv
```
