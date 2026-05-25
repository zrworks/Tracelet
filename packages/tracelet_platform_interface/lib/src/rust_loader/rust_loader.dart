/// Cross-platform wrapper for RustLib initialization
export 'rust_loader_unsupported.dart'
    if (dart.library.io) 'rust_loader_io.dart'
    if (dart.library.html) 'rust_loader_web.dart';
