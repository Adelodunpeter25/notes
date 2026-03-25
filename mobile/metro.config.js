const { getDefaultConfig } = require("expo/metro-config");
const { withNativeWind } = require("nativewind/metro");
const path = require("path");

const projectRoot = __dirname;
const sharedRoot = path.resolve(projectRoot, "../shared");

const config = getDefaultConfig(projectRoot);

config.watchFolders = [sharedRoot];

config.resolver.nodeModulesPaths = [
  path.resolve(projectRoot, "node_modules"),
];

config.resolver.extraNodeModules = {
  "@shared": path.resolve(sharedRoot, "types"),
  "@shared-utils": path.resolve(sharedRoot, "utils"),
};

module.exports = withNativeWind(config, {
  input: "./src/theme/global.css",
});
