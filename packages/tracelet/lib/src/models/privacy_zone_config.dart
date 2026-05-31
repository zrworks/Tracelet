import 'package:meta/meta.dart';
import 'package:tracelet/src/models/_helpers.dart';
import 'package:tracelet_platform_interface/tracelet_platform_interface.dart';

/// **Enterprise** — Configuration for Privacy Zones.
///
/// Controls whether privacy zone evaluation is active. Individual zones
/// are managed via `Tracelet.addPrivacyZone()` / `removePrivacyZone()`.
///
/// ```dart
/// Config(
///   privacyZone: PrivacyZoneConfig(enabled: true),
/// )
/// ```
@immutable
class PrivacyZoneConfig {
  const PrivacyZoneConfig({this.enabled = false});

  /// Creates a [PrivacyZoneConfig] from a platform map.
  factory PrivacyZoneConfig.fromMap(Map<String, Object?> map) {
    return PrivacyZoneConfig(
      enabled: ensureBool(
        map['privacyZoneEnabled'] ?? map['enabled'],
        fallback: false,
      ),
    );
  }

  /// Master toggle for privacy zone evaluation.
  ///
  /// When `false` (default), all registered privacy zones are ignored and
  /// locations flow through the normal dispatch pipeline unchanged.
  final bool enabled;

  /// Serializes to a map.
  ///
  /// Uses `privacyZoneEnabled` as the key (rather than plain `enabled`) to
  /// avoid collisions when native platforms flatten all config sections into
  /// a single key-value store.
  Map<String, Object?> toMap() {
    return <String, Object?>{'privacyZoneEnabled': enabled};
  }

  TlPrivacyZoneConfig toTlConfig() => TlPrivacyZoneConfig(enabled: enabled);

  @override
  String toString() => 'PrivacyZoneConfig(enabled: $enabled)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrivacyZoneConfig &&
          runtimeType == other.runtimeType &&
          enabled == other.enabled;

  @override
  int get hashCode => enabled.hashCode;
}
