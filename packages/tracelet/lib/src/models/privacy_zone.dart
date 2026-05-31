import 'package:meta/meta.dart';

import 'package:tracelet/src/models/_helpers.dart';

// ---------------------------------------------------------------------------
// PrivacyZoneAction
// ---------------------------------------------------------------------------

/// Defines the behavior when a location falls inside a [PrivacyZone].
enum PrivacyZoneAction {
  /// Drop the location entirely — not persisted, not dispatched to Dart.
  ///
  /// Use for areas where no location data should be recorded at all
  /// (e.g., employee homes, medical facilities).
  exclude,

  /// Reduce coordinate precision before persistence and dispatch.
  ///
  /// The coordinates are degraded to [PrivacyZone.degradedAccuracyMeters]
  /// meters of precision via coordinate rounding. The original coordinates
  /// are discarded — only the degraded version is stored.
  degrade,

  /// Dispatch the location event to Dart but do **not** persist to the
  /// database or include in HTTP sync.
  ///
  /// Use when the app needs real-time awareness of the device entering
  /// a zone but must not store a traceable record.
  eventOnly,
}

// ---------------------------------------------------------------------------
// PrivacyZone
// ---------------------------------------------------------------------------

/// **Enterprise** — A geographic zone where location tracking behavior changes.
///
/// Privacy Zones enable GDPR/CCPA-compliant geofenced privacy controls.
/// When the device is inside a privacy zone, location data can be excluded,
/// degraded in accuracy, or dispatched without persistence — depending on the
/// configured [action].
///
/// ```dart
/// await Tracelet.addPrivacyZone(PrivacyZone(
///   identifier: 'home',
///   latitude: 37.7749,
///   longitude: -122.4194,
///   radius: 200,
///   action: PrivacyZoneAction.exclude,
/// ));
/// ```
@immutable
class PrivacyZone {
  const PrivacyZone({
    required this.identifier,
    required this.latitude,
    required this.longitude,
    required this.radius,
    this.action = PrivacyZoneAction.exclude,
    this.degradedAccuracyMeters = 1000.0,
  });

  /// Creates a [PrivacyZone] from a platform map.
  factory PrivacyZone.fromMap(Map<String, Object?> map) {
    return PrivacyZone(
      identifier: map['identifier'] as String? ?? '',
      latitude: ensureDouble(map['latitude'], fallback: 0),
      longitude: ensureDouble(map['longitude'], fallback: 0),
      radius: ensureDouble(map['radius'], fallback: 100),
      action: _actionFromValue(map['action']),
      degradedAccuracyMeters: ensureDouble(
        map['degradedAccuracyMeters'] ?? map['degraded_accuracy_meters'],
        fallback: 1000,
      ),
    );
  }

  /// Unique identifier for this privacy zone.
  final String identifier;

  /// Center latitude in decimal degrees.
  final double latitude;

  /// Center longitude in decimal degrees.
  final double longitude;

  /// Radius in meters.
  final double radius;

  /// What happens when a location falls inside this zone.
  final PrivacyZoneAction action;

  /// For [PrivacyZoneAction.degrade]: the target accuracy in meters.
  ///
  /// Coordinates are rounded to this precision. For example, 1000 meters
  /// means coordinates are rounded to approximately 1 km grid cells.
  /// Only used when [action] is [PrivacyZoneAction.degrade].
  ///
  /// Defaults to 1000.0 meters (~1 km).
  final double degradedAccuracyMeters;

  /// Serializes to a map suitable for platform channel transmission.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'identifier': identifier,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'action': action.name,
      'degradedAccuracyMeters': degradedAccuracyMeters,
    };
  }

  @override
  String toString() =>
      'PrivacyZone(identifier: $identifier, center: ($latitude, $longitude), '
      'radius: ${radius}m, action: ${action.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrivacyZone &&
          runtimeType == other.runtimeType &&
          identifier == other.identifier;

  @override
  int get hashCode => identifier.hashCode;

  static PrivacyZoneAction _actionFromValue(Object? value) {
    if (value is int) {
      if (value >= 0 && value < PrivacyZoneAction.values.length) {
        return PrivacyZoneAction.values[value];
      }
      return PrivacyZoneAction.exclude;
    }
    final str = value as String? ?? 'exclude';
    switch (str) {
      case 'degrade':
        return PrivacyZoneAction.degrade;
      case 'eventOnly':
      case 'event_only':
        return PrivacyZoneAction.eventOnly;
      case 'exclude':
      default:
        return PrivacyZoneAction.exclude;
    }
  }
}
