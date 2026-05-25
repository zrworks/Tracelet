import '../rust/api_dart/trip.dart';

/// Rust-powered TripManager.
class TripManager {
  late final TripManagerDart _inner;
  void Function(Map<String, Object?>)? onTripEnd;

  TripManager() {
    _inner = TripManagerDart();
  }

  bool get isTripActive => _inner.isTripActive();

  void onMotionStateChanged({
    required bool isMoving,
    double? latitude,
    double? longitude,
    Object? timestamp,
  }) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    int timestampMs = nowMs;
    if (timestamp is int) {
      timestampMs = timestamp;
    } else if (timestamp is String) {
      timestampMs =
          DateTime.tryParse(timestamp)?.millisecondsSinceEpoch ?? nowMs;
    }

    final tripData = _inner.onMotionStateChanged(
      isMoving: isMoving,
      latitude: latitude,
      longitude: longitude,
      timestampMs: BigInt.from(timestampMs),
      nowMs: BigInt.from(nowMs),
    );

    if (tripData != null && onTripEnd != null) {
      final startMap = <String, Object?>{};
      if (tripData.startLocation != null) {
        startMap['latitude'] = tripData.startLocation!.latitude;
        startMap['longitude'] = tripData.startLocation!.longitude;
      }

      final stopMap = <String, Object?>{};
      if (tripData.stopLocation != null) {
        stopMap['latitude'] = tripData.stopLocation!.latitude;
        stopMap['longitude'] = tripData.stopLocation!.longitude;
      }

      final waypoints = tripData.waypoints.map((w) {
        return <String, Object?>{
          'latitude': w.latitude,
          'longitude': w.longitude,
          'timestamp': w.timestampMs is BigInt
              ? (w.timestampMs as dynamic).toInt()
              : w.timestampMs,
        };
      }).toList();

      onTripEnd!({
        'isMoving': false,
        'distance': tripData.distanceMeters,
        'duration': tripData.durationSeconds,
        'startLocation': startMap,
        'stopLocation': stopMap,
        'waypoints': waypoints,
      });
    }
  }

  void onLocationReceived({
    required double latitude,
    required double longitude,
    Object? timestamp,
  }) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    int timestampMs = nowMs;
    if (timestamp is int) {
      timestampMs = timestamp;
    } else if (timestamp is String) {
      timestampMs =
          DateTime.tryParse(timestamp)?.millisecondsSinceEpoch ?? nowMs;
    }
    _inner.onLocationReceived(
      latitude: latitude,
      longitude: longitude,
      timestampMs: BigInt.from(timestampMs),
    );
  }

  void reset() {
    _inner.reset();
  }
}
