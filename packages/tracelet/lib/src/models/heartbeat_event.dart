import 'package:meta/meta.dart';

import 'package:tracelet/src/models/_helpers.dart';
import 'package:tracelet/src/models/location.dart';

/// Event fired on each heartbeat interval.
///
/// Contains the latest known location (which may be stale if the device
/// is stationary and not actively receiving GPS fixes).
@immutable
class HeartbeatEvent {
  /// Creates a new [HeartbeatEvent].
  const HeartbeatEvent({required this.location});

  /// Creates a [HeartbeatEvent] from a platform map.
  factory HeartbeatEvent.fromMap(Map<String, Object?> map) {
    final locationMap = safeMap(map['location']) ?? const <String, Object?>{};

    return HeartbeatEvent(location: Location.fromMap(locationMap));
  }

  /// The latest location at the time of the heartbeat.
  final Location location;

  /// Serializes to a map.
  Map<String, Object?> toMap() {
    return <String, Object?>{'location': location.toMap()};
  }

  @override
  String toString() => 'HeartbeatEvent(location: $location)';
}
