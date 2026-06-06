/// Unsupported fallback for loading the Rust core.
bool tryLoadRustCore() => false;

/// Initializes the Rust core library.
Future<void> initializeRustLib() async {
  throw UnsupportedError('Platform not supported');
}
