import 'dart:ffi';
import 'dart:io';

// Note: This relies on flutter_rust_bridge_for_generated.dart being exposed by flutter_rust_bridge
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:tracelet_platform_interface/src/rust/frb_generated.dart';

/// Initializes the Rust core library.
Future<void> initializeRustLib() async {
  ExternalLibrary? lib;
  if (Platform.isIOS) {
    lib = _loadIosLibrary();
  } else if (Platform.isAndroid) {
    // In Android, TraceletCore is loaded by JNI (System.loadLibrary) before Tracelet.ready() is called.
    // However, JNI loads libraries with RTLD_LOCAL, meaning symbols are not globally visible.
    // We MUST explicitly open the library to resolve symbols reliably.
    lib = ExternalLibrary.open('libtracelet_core.so');
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

/// Resolves the TraceletCore Rust library on iOS.
///
/// Strategy (deterministic, no silent fallbacks):
///
/// 1. **Dynamic TraceletCore framework first** — TraceletCore ships as a
///    dynamic framework (`TraceletCore.framework`). Its FRB/uniffi symbols
///    live in the framework's *own* signed, embedded binary, so they are
///    never removed by the consuming app's archive strip
///    (`STRIP_INSTALLED_PRODUCT=YES`, `STRIP_STYLE=all`) and do not depend on
///    being exported from the app executable. We `dlopen` it explicitly — the
///    iOS analogue of the Android `ExternalLibrary.open(...)` path. This is the
///    only path that is robust under Swift Package Manager, where the plugin
///    cannot push `STRIP_INSTALLED_PRODUCT=NO` onto the consumer's app target.
///
/// 2. **Process symbols (legacy static linking)** — older builds linked the
///    Rust core as a static library into the Runner binary;
///    `DynamicLibrary.process()` resolves them directly (fragile to stripping).
///
/// 3. **Plugin dynamic framework fallback** — when the consumer Podfile uses
///    `use_frameworks! :linkage => :dynamic`, symbols live inside the
///    `tracelet_ios.framework` bundle.
///
/// If no strategy resolves it, we throw with diagnostic information instead of
/// silently initializing a broken state.
ExternalLibrary _loadIosLibrary() {
  // Strategy 1: Dynamic TraceletCore framework (strip-proof, preferred).
  try {
    return ExternalLibrary.open('TraceletCore.framework/TraceletCore');
  } catch (_) {
    // Not embedded as a dynamic framework — try legacy strategies.
  }

  // Strategy 2: Legacy static linking — symbols already in the process.
  try {
    final process = DynamicLibrary.process();
    // Probe for a known FRB symbol to confirm it's actually resolvable.
    process.lookup<NativeFunction<Void Function()>>(
      'frb_pde_ffi_dispatcher_primary',
    );
    return ExternalLibrary.process(iKnowHowToUseIt: true);
  } catch (_) {
    // Symbols not in process — try the plugin's own dynamic framework.
  }

  // Strategy 3: Plugin compiled as a dynamic framework.
  try {
    return ExternalLibrary.open('tracelet_ios.framework/tracelet_ios');
  } catch (_) {
    // Not a dynamic framework either.
  }

  // Nothing resolved — give actionable diagnostics.
  throw StateError(
    'TraceletCore Rust library could not be loaded on iOS.\n'
    'Could not open "TraceletCore.framework/TraceletCore", the FRB symbol '
    '"frb_pde_ffi_dispatcher_primary" was not found in the process symbol '
    'table, and "tracelet_ios.framework/tracelet_ios" could not be opened.\n\n'
    'Possible causes:\n'
    '  1. TraceletCore.framework was not embedded — ensure the binary target '
    'is set to "Embed & Sign" (SPM does this automatically for app targets).\n'
    '  2. The TraceletCore.xcframework is missing from the build — '
    'run "pod install" / resolve SPM packages and rebuild.\n'
    '  3. (Legacy static builds only) DEAD_CODE_STRIPPING / '
    'STRIP_INSTALLED_PRODUCT removed the Rust symbols from the app binary.\n',
  );
}
