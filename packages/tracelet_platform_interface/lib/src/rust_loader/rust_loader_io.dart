import 'dart:io';

// Note: This relies on flutter_rust_bridge_for_generated.dart being exposed by flutter_rust_bridge
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:tracelet_platform_interface/src/rust/frb_generated.dart';

Future<void> initializeRustLib() async {
  ExternalLibrary? lib;
  if (Platform.isIOS) {
    // In iOS, TraceletCore is bundled statically via the cocoapods xcframework,
    // so we resolve symbols directly from the process instead of trying to open
    // 'tracelet_core.framework/tracelet_core'.
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
