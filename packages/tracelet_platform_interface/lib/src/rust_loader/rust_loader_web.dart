/// Web implementation for loading the Rust core (no-op on web).
bool tryLoadRustCore() => false;

/// Initializes the Rust core library.
Future<void> initializeRustLib() async {
  // Web does not use the Rust core natively, it uses the Dart-based TraceletWebPlugin.
  // Returning immediately prevents flutter_rust_bridge from trying to load missing .js/.wasm files.
  return;
}
