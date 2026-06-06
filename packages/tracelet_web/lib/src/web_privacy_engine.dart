import 'package:tracelet_platform_interface/tracelet_platform_interface.dart'
    show GeoUtils;

/// Web implementation of the PrivacyZoneManager.
///
/// Keeps a list of privacy zones in memory. When a location falls inside
/// a privacy zone, it can be suppressed entirely.
class WebPrivacyEngine {
  final List<Map<String, Object?>> _zones = [];
  bool _enabled = false;

  /// Applies privacy-related configuration settings.
  void applyConfig(Map<String, Object?> config) {
    final privacyZone = config['privacyZone'];
    if (privacyZone is Map) {
      _enabled = (privacyZone['enabled'] as bool?) ?? _enabled;
    }
  }

  /// Adds a new privacy zone.
  Future<bool> addPrivacyZone(Map<String, Object?> zone) async {
    final identifier = zone['identifier'] as String?;
    if (identifier == null) return false;

    // Remove if exists to replace it
    _zones.removeWhere((z) => z['identifier'] == identifier);
    _zones.add(Map<String, Object?>.from(zone));
    return true;
  }

  /// Adds multiple privacy zones.
  Future<bool> addPrivacyZones(List<Map<String, Object?>> zones) async {
    for (final zone in zones) {
      await addPrivacyZone(zone);
    }
    return true;
  }

  /// Removes a privacy zone by its identifier.
  Future<bool> removePrivacyZone(String identifier) async {
    final before = _zones.length;
    _zones.removeWhere((z) => z['identifier'] == identifier);
    return _zones.length < before;
  }

  /// Removes all registered privacy zones.
  Future<bool> removePrivacyZones() async {
    _zones.clear();
    return true;
  }

  /// Retrieves all registered privacy zones.
  Future<List<Map<String, Object?>>> getPrivacyZones() async {
    return List<Map<String, Object?>>.from(_zones);
  }

  /// Checks if a given coordinate is within any active privacy zone.
  /// If [true] is returned, the location should be suppressed.
  bool isLocationInPrivacyZone(double lat, double lon) {
    if (!_enabled || _zones.isEmpty) return false;

    for (final zone in _zones) {
      final zLat = (zone['latitude'] as num?)?.toDouble() ?? 0.0;
      final zLon = (zone['longitude'] as num?)?.toDouble() ?? 0.0;
      final radius = (zone['radius'] as num?)?.toDouble() ?? 100.0;

      final distance = GeoUtils.haversine(lat, lon, zLat, zLon);
      if (distance <= radius) {
        return true;
      }
    }
    return false;
  }
}
