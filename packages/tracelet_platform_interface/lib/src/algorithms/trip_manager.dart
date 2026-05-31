import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:tracelet_platform_interface/src/rust/api_dart/trip.dart';

/// Rust-powered TripManager.
class TripManager {
  TripManager() {
    if (!kIsWeb) {
      _inner = TripManagerDart();
    }
  }
  TripManagerDart? _inner;
  void Function(Map<String, Object?>)? onTripEnd;

  bool get isTripActive => _inner?.isTripActive() ?? false;

  void onMotionStateChanged({
    required bool isMoving,
    double? latitude,
    double? longitude,
    Object? timestamp,
  }) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    var timestampMs = nowMs;
    if (timestamp is int) {
      timestampMs = timestamp;
    } else if (timestamp is String) {
      timestampMs =
          DateTime.tryParse(timestamp)?.millisecondsSinceEpoch ?? nowMs;
    }

    if (_inner == null) return;

    final tripData = _inner!.onMotionStateChanged(
      isMoving: isMoving,
      latitude: latitude,
      longitude: longitude,
      timestampMs: PlatformInt64Util.from(timestampMs),
      nowMs: PlatformInt64Util.from(nowMs),
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
    var timestampMs = nowMs;
    if (timestamp is int) {
      timestampMs = timestamp;
    } else if (timestamp is String) {
      timestampMs =
          DateTime.tryParse(timestamp)?.millisecondsSinceEpoch ?? nowMs;
    }

    if (_inner == null) return;

    _inner!.onLocationReceived(
      latitude: latitude,
      longitude: longitude,
      timestampMs: PlatformInt64Util.from(timestampMs),
    );
  }

  void reset() {
    _inner?.reset();
  }
}
