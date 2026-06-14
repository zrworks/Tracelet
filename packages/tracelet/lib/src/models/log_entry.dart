import 'package:tracelet_platform_interface/tracelet_platform_interface.dart';

/// Represents a background log entry stored in the local SQLite database.
class LogEntry {
  /// Creates a [LogEntry].
  const LogEntry({
    required this.id,
    required this.level,
    required this.message,
    required this.timestamp,
  });

  /// Converts from Pigeon [TlLogEntry].
  factory LogEntry.fromTl(TlLogEntry tl) {
    return LogEntry(
      id: tl.id,
      level: tl.level,
      message: tl.message,
      timestamp: tl.timestamp,
    );
  }

  /// The primary key.
  final int id;

  /// Log level string (e.g. DEBUG, INFO).
  final String level;

  /// Log message.
  final String message;

  /// ISO8601 timestamp string.
  final String timestamp;
}
