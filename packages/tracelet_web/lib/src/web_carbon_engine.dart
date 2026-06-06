import 'package:tracelet_platform_interface/tracelet_platform_interface.dart'
    show GeoUtils;
import 'package:tracelet_web/src/web_storage_engine.dart';

/// Web implementation of the Carbon Estimator.
///
/// Iterates over persisted locations to estimate carbon emissions based on
/// distance traveled and inferred activity type (defaulting to driving on web).
class WebCarbonEngine {
  /// Documentation for WebCarbonEngine.
  WebCarbonEngine(this._storage);

  final WebStorageEngine _storage;

  // Simple emission factors (grams of CO2 per km)
  static const double _walkingFactor = 0;
  static const double _drivingFactor = 120;
  static const double _unknownFactor = 120;

  /// Documentation for Future<Map<String,.
  Future<Map<String, Object?>> getCarbonReport([
    Map<String, Object?>? query,
  ]) async {
    final locations = await _storage.getLocations(query);

    var totalCarbon = 0.toDouble();
    const totalTrips = 1; // Simplified: 1 trip for the session

    final carbonByMode = <String, double>{
      'walking': 0.0,
      'driving': 0.0,
      'unknown': 0.0,
    };

    final distanceByMode = <String, double>{
      'walking': 0.0,
      'driving': 0.0,
      'unknown': 0.0,
    };

    var prevLat = 0.toDouble();
    var prevLon = 0.toDouble();
    var hasPrev = false;

    for (final loc in locations) {
      final coords = loc['coords'];
      if (coords is Map) {
        final lat = (coords['latitude'] as num?)?.toDouble() ?? 0.0;
        final lon = (coords['longitude'] as num?)?.toDouble() ?? 0.0;

        if (hasPrev) {
          final distanceMeters = GeoUtils.haversine(prevLat, prevLon, lat, lon);
          final distanceKm = distanceMeters / 1000.0;

          // On Web, activity is typically unknown unless manually set
          final activity = loc['activity'];
          var mode = 'unknown';
          if (activity is Map) {
            mode = (activity['type'] as String?)?.toLowerCase() ?? 'unknown';
          }

          var factor = _unknownFactor;
          if (mode == 'walking' || mode == 'running' || mode == 'bicycle') {
            factor = _walkingFactor;
            mode = 'walking';
          } else if (mode == 'in_vehicle') {
            factor = _drivingFactor;
            mode = 'driving';
          }

          final carbonGrams = distanceKm * factor;

          distanceByMode[mode] = (distanceByMode[mode] ?? 0.0) + distanceKm;
          carbonByMode[mode] = (carbonByMode[mode] ?? 0.0) + carbonGrams;
          totalCarbon += carbonGrams;
        }

        prevLat = lat;
        prevLon = lon;
        hasPrev = true;
      }
    }

    return <String, Object?>{
      'totalCarbonGrams': totalCarbon,
      'carbonByMode': carbonByMode,
      'distanceByMode': distanceByMode,
      'totalTrips': locations.isEmpty ? 0 : totalTrips,
    };
  }
}
