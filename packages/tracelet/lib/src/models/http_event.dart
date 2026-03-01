import 'package:meta/meta.dart';

import '_helpers.dart';

/// Event fired during HTTP sync operations.
///
/// Reports success/failure, HTTP status code, server response text, and
/// retry metadata for diagnosing transient failures.
@immutable
class HttpEvent {
  /// Creates a new [HttpEvent].
  const HttpEvent({
    required this.success,
    required this.status,
    this.responseText = '',
    this.isRetry = false,
    this.retryCount = 0,
  });

  /// Whether the HTTP request succeeded (2xx).
  final bool success;

  /// The HTTP status code returned by the server.
  final int status;

  /// The raw response body text from the server.
  final String responseText;

  /// Whether this event is a retry attempt (not the first try).
  final bool isRetry;

  /// The current retry attempt number (0 = first attempt).
  final int retryCount;

  /// Creates an [HttpEvent] from a platform map.
  factory HttpEvent.fromMap(Map<String, Object?> map) {
    return HttpEvent(
      success: ensureBool(map['success'], fallback: false),
      status: ensureInt(map['status'], fallback: 0),
      responseText: map['responseText'] as String? ?? '',
      isRetry: ensureBool(map['isRetry'], fallback: false),
      retryCount: ensureInt(map['retryCount'], fallback: 0),
    );
  }

  /// Serializes to a map.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'success': success,
      'status': status,
      'responseText': responseText,
      'isRetry': isRetry,
      'retryCount': retryCount,
    };
  }

  @override
  String toString() =>
      'HttpEvent(success: $success, status: $status, retryCount: $retryCount)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HttpEvent &&
          runtimeType == other.runtimeType &&
          success == other.success &&
          status == other.status &&
          isRetry == other.isRetry &&
          retryCount == other.retryCount;

  @override
  int get hashCode => Object.hash(success, status, isRetry, retryCount);
}
