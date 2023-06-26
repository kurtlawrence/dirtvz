// import { fileURLToPath } from 'url';
const path = require('path');
const CopyPlugin = require('copy-webpack-plugin');
// const WasmPackPlugin = require("@wasm-tool/wasm-pack-plugin");

// const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dist = path.resolve(__dirname, "dist");

// const config = {
module.exports = {
  mode: "development",
  entry: {
    dirtvz: "./ts/index.ts",
    "dirtvz-ui": "./ts/viewer-ui.ts",
	"dirtvz-worker": './ts/worker.ts',
  },
  resolve: {
    extensions: [".ts", ".js"],
  },
  module: {
    rules: [
      {
        test: /\.ts?$/,
        loader: "ts-loader",
        exclude: "/node_modules",
      },
    ],
  },
  // wasm support
  experiments: {
    asyncWebAssembly: true,
  },
  output: {
    path: dist,
    filename: "[name].js",
    library: "dirtvz",
    libraryTarget: "umd",
  },
  devServer: {
    static: { directory: dist },
    client: {
      overlay: false,
    },
  },
  plugins: [
    new CopyPlugin({
      patterns: [path.resolve(__dirname, "static")],
    }),

//     new WasmPackPlugin({
//       crateDirectory: __dirname,
//       outName: "wasm",
//    }),
  ],
};

// export default config;
