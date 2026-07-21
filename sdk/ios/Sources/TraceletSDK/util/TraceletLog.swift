import Foundation

/// Process-wide entry point for Tracelet logging.
///
/// Routes every log line through the configured `TraceletLogger` (which respects
/// the configured log level and persists to the Rust SQLite log store) once the
/// SDK has `attach`ed one. Before the SDK is initialized — e.g. inside a
/// background relaunch or a manager that spins up early — it falls back to
/// `NSLog` so nothing is silently dropped.
///
/// Use this instead of `NSLog` everywhere. The only place that legitimately
/// calls `NSLog` directly is `TraceletLogger` itself (the sink) and this
/// fallback.
public enum TraceletLog {
    private static let lock = NSLock()
    private static var delegate: TraceletLogger?
    private static var mirror: ((String, String) -> Void)?
    private static let timestampLock = NSLock()
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS 'GMT'Z"
        return formatter
    }()

    /// Wire the real logger once the SDK is initialized.
    public static func attach(_ logger: TraceletLogger) {
        lock.lock(); delegate = logger; lock.unlock()
    }

    /// Drop the logger reference (e.g. on reset/teardown).
    public static func detach() {
        lock.lock(); delegate = nil; lock.unlock()
    }

    /// Mirrors native log lines to an external observer (for example, Flutter)
    /// so they can appear in the host app console in addition to `NSLog`.
    public static func setMirror(_ observer: ((String, String) -> Void)?) {
        lock.lock(); mirror = observer; lock.unlock()
    }

    private static var current: TraceletLogger? {
        lock.lock(); defer { lock.unlock() }; return delegate
    }

    static func forwardToMirror(level: String, message: String) {
        lock.lock()
        let observer = mirror
        lock.unlock()
        observer?(level, message)
    }

    private static func timestamp() -> String {
        timestampLock.lock()
        defer { timestampLock.unlock() }
        return timestampFormatter.string(from: Date())
    }

    public static func error(_ message: @autoclosure () -> String) {
        if let d = current {
            d.error(message())
        } else {
            let built = message()
            forwardToMirror(level: "ERROR", message: built)
            NSLog("[Tracelet] [\(timestamp())] [ERROR] \(built)")
        }
    }

    public static func warning(_ message: @autoclosure () -> String) {
        if let d = current {
            d.warning(message())
        } else {
            let built = message()
            forwardToMirror(level: "WARNING", message: built)
            NSLog("[Tracelet] [\(timestamp())] [WARNING] \(built)")
        }
    }

    public static func info(_ message: @autoclosure () -> String) {
        if let d = current {
            d.info(message())
        } else {
            let built = message()
            forwardToMirror(level: "INFO", message: built)
            NSLog("[Tracelet] [\(timestamp())] [INFO] \(built)")
        }
    }

    public static func debug(_ message: @autoclosure () -> String) {
        if let d = current {
            d.debug(message())
        } else {
            let built = message()
            forwardToMirror(level: "DEBUG", message: built)
            NSLog("[Tracelet] [\(timestamp())] [DEBUG] \(built)")
        }
    }

    public static func verbose(_ message: @autoclosure () -> String) {
        if let d = current {
            d.verbose(message())
        } else {
            let built = message()
            forwardToMirror(level: "VERBOSE", message: built)
            NSLog("[Tracelet] [\(timestamp())] [VERBOSE] \(built)")
        }
    }
}
