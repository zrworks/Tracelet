module.exports = {
  dependency: {
    platforms: {
      android: {
        sourceDir: 'android',
        packageImportPath: 'import com.ikolvi.tracelet.reactnative.TraceletPackage;',
        packageInstance: 'new TraceletPackage()',
      },
      ios: {},
    },
  },
};
