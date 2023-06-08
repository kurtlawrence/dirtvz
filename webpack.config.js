const path = require("path");
const CopyPlugin = require("copy-webpack-plugin");
// const WasmPackPlugin = require("@wasm-tool/wasm-pack-plugin");

const dist = path.resolve(__dirname, "dist");

module.exports = {
  mode: "development",
  entry: {
    index: "./ts/index.ts",
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
      // workers
      {
        test: /\.worker\.ts$/,
        use: { loader: "worker-loader" },
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
    library: "dirtvis",
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
