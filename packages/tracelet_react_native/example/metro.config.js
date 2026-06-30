const path = require('path');
const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');
const { getConfig } = require('react-native-builder-bob/metro-config');
const pkg = require('../package.json');

const root = path.resolve(__dirname, '..');

/**
 * Metro configuration that lets the example app consume the local
 * `@ikolvi/tracelet` source directly (no publish step required).
 */
module.exports = getConfig(
  mergeConfig(getDefaultConfig(__dirname), {}),
  {
    root,
    pkg,
    project: __dirname,
  }
);
