import 'package:meta/meta.dart';
import 'package:tracelet/src/models/_helpers.dart';
import 'package:tracelet/src/models/location.dart';
import 'package:tracelet_platform_interface/tracelet_platform_interface.dart';

/// Event fired when a geofence transition occurs.
///
/// Contains the geofence identifier, the transition action (enter/exit/dwell),
/// and the location at the time of the event.
@immutable
class GeofenceEvent {
  /// Creates a new [GeofenceEvent].
  const GeofenceEvent({
    required this.identifier,
    required this.action,
    required this.location,
    this.extras = const <String, Object?>{},
  });

  /// Creates a [GeofenceEvent] from a platform map.
  ///
  /// Accepts two shapes:
  ///  * **Flat** — `{identifier, action, location, extras}`, produced by the
  ///    foreground Pigeon event streams.
  ///  * **Structured** — the SDK's raw payload as delivered to a headless
  ///    (killed-state) isolate, where the geofence fields are nested under
  ///    `'geofence'` and the location coords are at the top-level `'coords'`.
  ///
  /// Handling both is essential: a headless geofence event parsed as the flat
  /// shape would read `null` for every field and silently default to
  /// [GeofenceAction.enter], so EXIT transitions in the background would look
  /// like ENTER (or be dropped entirely).
  factory GeofenceEvent.fromMap(Map<String, Object?> map) {
    // In the structured payload the geofence fields live under 'geofence'.
    final source = safeMap(map['geofence']) ?? map;

    final actionRaw = source['action'];
    var action = GeofenceAction.enter;
    if (actionRaw is int) {
      action = GeofenceAction
          .values[actionRaw.clamp(0, GeofenceAction.values.length - 1)];
    } else if (actionRaw is String) {
      action = GeofenceAction.values.firstWhere(
        (e) => e.name == actionRaw.toLowerCase(),
        orElse: () => GeofenceAction.enter,
      );
    }

    // Location: the flat shape wraps the location under 'location'; the
    // structured payload exposes the coords at the top-level 'coords'.
    final locationMap =
        safeMap(map['location']) ??
        (map['coords'] != null
            ? <String, Object?>{'coords': map['coords']}
            : const <String, Object?>{});
    final extrasRaw = source['extras'];

    return GeofenceEvent(
      identifier: source['identifier'] as String? ?? '',
      action: action,
      location: Location.fromMap(locationMap),
      extras: extrasRaw is Map
          ? extrasRaw.map<String, Object?>(
              (Object? k, Object? v) => MapEntry(k.toString(), v),
            )
          : const <String, Object?>{},
    );
  }

  /// The identifier of the geofence.
  final String identifier;

  /// The transition action.
  final GeofenceAction action;

  /// The location at the time of the event.
  final Location location;

  /// Extra data from the geofence definition.
  final Map<String, Object?> extras;

  /// Serializes to a map.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'identifier': identifier,
      'action': action.name,
      'location': location.toMap(),
      'extras': extras,
    };
  }

  @override
  String toString() => 'GeofenceEvent($identifier, action: $action)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeofenceEvent &&
          runtimeType == other.runtimeType &&
          identifier == other.identifier &&
          action == other.action;

  @override
  int get hashCode => Object.hash(identifier, action);
}
