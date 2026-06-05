import 'dart:io';

// Note: This relies on flutter_rust_bridge_for_generated.dart being exposed by flutter_rust_bridge
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:tracelet_platform_interface/src/rust/frb_generated.dart';

Future<void> initializeRustLib() async {
  ExternalLibrary? lib;
  if (Platform.isIOS) {
    try {
      // If tracelet_ios is compiled as a dynamic framework (use_frameworks!), symbols are in the framework.
      lib = ExternalLibrary.open('tracelet_ios.framework/tracelet_ios');
    } catch (_) {
      // Fallback: If compiled as a static framework, symbols are in the main executable.
      lib = ExternalLibrary.process(iKnowHowToUseIt: true);
    }
  } else if (Platform.isAndroid) {
    // In Android, TraceletCore is loaded by JNI (System.loadLibrary) before Tracelet.ready() is called.
    lib = ExternalLibrary.process(iKnowHowToUseIt: true);
  } else if (Platform.isMacOS) {
    // For local tests running on macOS host, resolve relative to the current script
    var rootDir = Directory.current.path;
    if (rootDir.endsWith('/benchmark')) {
      rootDir = Directory.current.parent.path;
    } else if (rootDir.contains('/packages/')) {
      rootDir = rootDir.split('/packages/').first;
    }
    lib = ExternalLibrary.open(
      '$rootDir/sdk/rust-core/target/release/libtracelet_core.dylib',
    );
  }
  await RustLib.init(externalLibrary: lib);
}
