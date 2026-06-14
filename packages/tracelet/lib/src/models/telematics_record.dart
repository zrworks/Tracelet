import 'package:tracelet_platform_interface/tracelet_platform_interface.dart';

/// Represents a telematics event (e.g. harsh braking, crash) stored in the database.
class TelematicsRecord {
  /// Creates a [TelematicsRecord].
  const TelematicsRecord({
    required this.id,
    required this.eventType,
    required this.severity,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.synced,
  });

  /// Converts from Pigeon [TlTelematicsRecord].
  factory TelematicsRecord.fromTl(TlTelematicsRecord tl) {
    return TelematicsRecord(
      id: tl.id,
      eventType: tl.eventType,
      severity: tl.severity,
      latitude: tl.latitude,
      longitude: tl.longitude,
      timestamp: tl.timestamp,
      synced: tl.synced,
    );
  }

  /// The primary key.
  final int id;

  /// The type of event (e.g. "harsh_braking", "crash").
  final String eventType;

  /// The severity of the event.
  final double severity;

  /// Event latitude.
  final double latitude;

  /// Event longitude.
  final double longitude;

  /// ISO8601 timestamp string.
  final String timestamp;

  /// Whether it has been synced.
  final bool synced;
}
