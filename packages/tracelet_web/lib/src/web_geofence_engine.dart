import 'dart:async';

import 'package:tracelet_platform_interface/tracelet_platform_interface.dart'
    show GeoUtils;

import 'web_event_dispatcher.dart';

/// Emulated geofence engine for web.
///
/// Since browsers have no native geofencing API, we compute enter/exit/dwell
/// transitions in Dart by checking the distance from the current position to
/// each registered geofence on every location fix.
class WebGeofenceEngine {
  WebGeofenceEngine(this._events);

  final WebEventDispatcher _events;

  /// Registered geofences: identifier → geofence map.
  final Map<String, Map<String, Object?>> _geofences =
      <String, Map<String, Object?>>{};

  /// Pre-converted polygon vertices cache: identifier → vertices.
  /// Avoids re-converting `List<Object?>` → `List<List<double>>` on every fix.
  final Map<String, List<List<double>>> _cachedVertices =
      <String, List<List<double>>>{};

  /// Geofences the device is currently inside: identifier → entry time.
  final Map<String, DateTime> _insideGeofences = <String, DateTime>{};

  /// Dwell timers: identifier → timer.
  final Map<String, Timer> _dwellTimers = <String, Timer>{};

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  bool addGeofence(Map<String, Object?> geofence) {
    final id = geofence['identifier'] as String?;
    if (id == null || id.isEmpty) return false;
    _geofences[id] = Map<String, Object?>.from(geofence);

    // Pre-convert polygon vertices once at add-time (D-H5).
    final verticesRaw = geofence['vertices'] as List<Object?>?;
    if (verticesRaw != null && verticesRaw.length >= 3) {
      final converted = <List<double>>[];
      for (final v in verticesRaw) {
        if (v is List) {
          final latV = (v[0] as num?)?.toDouble();
          final lngV = (v[1] as num?)?.toDouble();
          if (latV != null && lngV != null) {
            converted.add(<double>[latV, lngV]);
          }
        }
      }
      if (converted.length >= 3) {
        _cachedVertices[id] = converted;
      } else {
        _cachedVertices.remove(id);
      }
    } else {
      _cachedVertices.remove(id);
    }
    return true;
  }

  bool addGeofences(List<Map<String, Object?>> geofences) {
    for (final g in geofences) {
      addGeofence(g);
    }
    return true;
  }

  bool removeGeofence(String identifier) {
    _geofences.remove(identifier);
    _cachedVertices.remove(identifier);
    _insideGeofences.remove(identifier);
    _dwellTimers[identifier]?.cancel();
    _dwellTimers.remove(identifier);
    return true;
  }

  bool removeGeofences() {
    _geofences.clear();
    _cachedVertices.clear();
    _insideGeofences.clear();
    for (final t in _dwellTimers.values) {
      t.cancel();
    }
    _dwellTimers.clear();
    return true;
  }

  List<Map<String, Object?>> getGeofences() {
    return _geofences.values.toList();
  }

  Map<String, Object?>? getGeofence(String identifier) {
    return _geofences[identifier];
  }

  bool geofenceExists(String identifier) {
    return _geofences.containsKey(identifier);
  }

  // ---------------------------------------------------------------------------
  // Proximity check (called on each location fix)
  // ---------------------------------------------------------------------------

  /// Check all registered geofences against the current position.
  void checkGeofences(
    double lat,
    double lon,
    Map<String, Object?> locationMap,
  ) {
    for (final entry in _geofences.entries) {
      final id = entry.key;
      final fence = entry.value;
      final fenceLat = (fence['latitude'] as num?)?.toDouble();
      final fenceLon = (fence['longitude'] as num?)?.toDouble();
      final radius = (fence['radius'] as num?)?.toDouble() ?? 200;
      final notifyOnEntry = fence['notifyOnEntry'] as bool? ?? true;
      final notifyOnExit = fence['notifyOnExit'] as bool? ?? true;
      final notifyOnDwell = fence['notifyOnDwell'] as bool? ?? false;
      final loiteringDelay = fence['loiteringDelay'] as int? ?? 0;

      if (fenceLat == null || fenceLon == null) continue;

      // Check if this is a polygon geofence (has cached vertices)
      final cachedVerts = _cachedVertices[id];
      final bool isInside;

      if (cachedVerts != null) {
        // Polygon geofence: use cached pre-converted vertices.
        isInside = GeoUtils.isPointInPolygon(
          lat: lat,
          lng: lon,
          vertices: cachedVerts,
        );
      } else {
        // Circular geofence: use Haversine distance check
        final distance = GeoUtils.haversine(lat, lon, fenceLat, fenceLon);
        isInside = distance <= radius;
      }

      final wasInside = _insideGeofences.containsKey(id);

      if (isInside && !wasInside) {
        // ENTER
        _insideGeofences[id] = DateTime.now();
        if (notifyOnEntry) {
          _events.emitGeofence(<String, Object?>{
            'identifier': id,
            'action': 'ENTER',
            'location': locationMap,
            'extras': fence['extras'],
          });
        }
        // Start dwell timer if configured.
        if (notifyOnDwell && loiteringDelay > 0) {
          _dwellTimers[id]?.cancel();
          _dwellTimers[id] = Timer(Duration(milliseconds: loiteringDelay), () {
            if (_insideGeofences.containsKey(id)) {
              _events.emitGeofence(<String, Object?>{
                'identifier': id,
                'action': 'DWELL',
                'location': locationMap,
                'extras': fence['extras'],
              });
            }
          });
        }
      } else if (!isInside && wasInside) {
        // EXIT
        _insideGeofences.remove(id);
        _dwellTimers[id]?.cancel();
        _dwellTimers.remove(id);
        if (notifyOnExit) {
          _events.emitGeofence(<String, Object?>{
            'identifier': id,
            'action': 'EXIT',
            'location': locationMap,
            'extras': fence['extras'],
          });
        }
      }
    }
  }

  /// Release all timers.
  void dispose() {
    for (final t in _dwellTimers.values) {
      t.cancel();
    }
    _dwellTimers.clear();
  }
}
