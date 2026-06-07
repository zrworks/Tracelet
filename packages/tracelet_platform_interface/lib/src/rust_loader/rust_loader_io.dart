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
/// 1. **Probe process symbols first** — when compiled as a static library
///    (the default CocoaPods mode), all Rust symbols are linked into the
///    Runner binary. `DynamicLibrary.process()` resolves them directly.
///
/// 2. **Dynamic framework fallback** — when the consumer Podfile uses
///    `use_frameworks! :linkage => :dynamic`, symbols live inside the
///    `tracelet_ios.framework` bundle. We try `dlopen` on that path.
///
/// The probe uses `frb_pde_ffi_dispatcher_primary`, a well-known FRB
/// symbol that **must** be present in every build. If neither strategy
/// resolves it, we throw with diagnostic information instead of silently
/// initializing a broken state.
ExternalLibrary _loadIosLibrary() {
  // Strategy 1: Static linking — symbols in process (most common).
  try {
    final process = DynamicLibrary.process();
    // Probe for a known FRB symbol to confirm it's actually resolvable.
    process.lookup<NativeFunction<Void Function()>>(
      'frb_pde_ffi_dispatcher_primary',
    );
    return ExternalLibrary.process(iKnowHowToUseIt: true);
  } catch (_) {
    // Symbols not in process — try dynamic framework.
  }

  // Strategy 2: Dynamic framework (use_frameworks! :linkage => :dynamic).
  try {
    final lib = ExternalLibrary.open('tracelet_ios.framework/tracelet_ios');
    return lib;
  } catch (_) {
    // Not a dynamic framework either.
  }

  // Neither path resolved — give actionable diagnostics.
  throw StateError(
    'TraceletCore Rust library could not be loaded on iOS.\n'
    'The FRB symbol "frb_pde_ffi_dispatcher_primary" was not found in the '
    'process symbol table, and "tracelet_ios.framework/tracelet_ios" could '
    'not be opened as a dynamic library.\n\n'
    'Possible causes:\n'
    '  1. DEAD_CODE_STRIPPING is enabled — set it to NO in your Xcode '
    "project's Build Settings.\n"
    '  2. TraceletCoreDummy.enforceBundling() was not called — ensure '
    'tracelet_ios plugin is registered.\n'
    '  3. The TraceletCore.xcframework is missing from the build — '
    'run "pod install" and rebuild.\n',
  );
}
