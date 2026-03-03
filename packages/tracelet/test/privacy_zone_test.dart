import 'package:flutter_test/flutter_test.dart';
import 'package:tracelet/tracelet.dart';

void main() {
  // ==========================================================================
  // PrivacyZoneConfig
  // ==========================================================================
  group('PrivacyZoneConfig', () {
    test('has sensible defaults', () {
      const config = PrivacyZoneConfig();
      expect(config.enabled, false);
    });

    test('custom values', () {
      const config = PrivacyZoneConfig(enabled: true);
      expect(config.enabled, true);
    });

    test('round-trip serialization preserves all fields', () {
      const original = PrivacyZoneConfig(enabled: true);
      final map = original.toMap();
      final restored = PrivacyZoneConfig.fromMap(map);
      expect(restored.enabled, true);
    });

    test('fromMap with defaults when keys missing', () {
      final restored = PrivacyZoneConfig.fromMap(const <String, Object?>{});
      expect(restored.enabled, false);
    });

    test('toMap produces privacyZoneEnabled key (no collision)', () {
      const config = PrivacyZoneConfig(enabled: true);
      final map = config.toMap();
      expect(map.containsKey('privacyZoneEnabled'), true);
      expect(map['privacyZoneEnabled'], true);
      // Must NOT use plain 'enabled' — avoids collision with AuditConfig
      expect(map.containsKey('enabled'), false);
    });

    test('fromMap accepts both privacyZoneEnabled and enabled keys', () {
      final a = PrivacyZoneConfig.fromMap(const <String, Object?>{
        'privacyZoneEnabled': true,
      });
      expect(a.enabled, true);

      final b = PrivacyZoneConfig.fromMap(const <String, Object?>{
        'enabled': true,
      });
      expect(b.enabled, true);
    });

    test('equality', () {
      const a = PrivacyZoneConfig(enabled: true);
      const b = PrivacyZoneConfig(enabled: true);
      const c = PrivacyZoneConfig(enabled: false);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode consistent with equality', () {
      const a = PrivacyZoneConfig(enabled: true);
      const b = PrivacyZoneConfig(enabled: true);
      expect(a.hashCode, b.hashCode);
    });

    test('toString contains class name and enabled value', () {
      const config = PrivacyZoneConfig(enabled: true);
      expect(config.toString(), contains('PrivacyZoneConfig'));
      expect(config.toString(), contains('true'));
    });
  });

  // ==========================================================================
  // PrivacyZoneAction
  // ==========================================================================
  group('PrivacyZoneAction', () {
    test('enum has three values', () {
      expect(PrivacyZoneAction.values.length, 3);
    });

    test('enum indices match native constants', () {
      expect(PrivacyZoneAction.exclude.index, 0);
      expect(PrivacyZoneAction.degrade.index, 1);
      expect(PrivacyZoneAction.eventOnly.index, 2);
    });
  });

  // ==========================================================================
  // PrivacyZone
  // ==========================================================================
  group('PrivacyZone', () {
    test('constructor with required fields only', () {
      const zone = PrivacyZone(
        identifier: 'home',
        latitude: 37.7749,
        longitude: -122.4194,
        radius: 200,
      );
      expect(zone.identifier, 'home');
      expect(zone.latitude, 37.7749);
      expect(zone.longitude, -122.4194);
      expect(zone.radius, 200);
      expect(zone.action, PrivacyZoneAction.exclude); // default
      expect(zone.degradedAccuracyMeters, 1000.0); // default
    });

    test('constructor with all fields', () {
      const zone = PrivacyZone(
        identifier: 'office',
        latitude: 40.7128,
        longitude: -74.0060,
        radius: 500,
        action: PrivacyZoneAction.degrade,
        degradedAccuracyMeters: 2000.0,
      );
      expect(zone.identifier, 'office');
      expect(zone.action, PrivacyZoneAction.degrade);
      expect(zone.degradedAccuracyMeters, 2000.0);
    });

    test('round-trip serialization preserves all fields', () {
      const original = PrivacyZone(
        identifier: 'test',
        latitude: 51.5074,
        longitude: -0.1278,
        radius: 300,
        action: PrivacyZoneAction.eventOnly,
        degradedAccuracyMeters: 500.0,
      );

      final map = original.toMap();
      final restored = PrivacyZone.fromMap(map);

      expect(restored.identifier, original.identifier);
      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
      expect(restored.radius, original.radius);
      expect(restored.action, original.action);
      expect(restored.degradedAccuracyMeters, original.degradedAccuracyMeters);
    });

    test('toMap produces expected keys', () {
      const zone = PrivacyZone(
        identifier: 'z1',
        latitude: 0.0,
        longitude: 0.0,
        radius: 100,
        action: PrivacyZoneAction.degrade,
        degradedAccuracyMeters: 750.0,
      );
      final map = zone.toMap();
      expect(map['identifier'], 'z1');
      expect(map['latitude'], 0.0);
      expect(map['longitude'], 0.0);
      expect(map['radius'], 100.0);
      expect(map['action'], 'degrade');
      expect(map['degradedAccuracyMeters'], 750.0);
    });

    test('fromMap with minimal fields uses defaults', () {
      final zone = PrivacyZone.fromMap(const <String, Object?>{
        'identifier': 'min',
        'latitude': 1.0,
        'longitude': 2.0,
        'radius': 50,
      });
      expect(zone.identifier, 'min');
      expect(zone.action, PrivacyZoneAction.exclude);
      expect(zone.degradedAccuracyMeters, 1000.0);
    });

    test('fromMap handles string action values', () {
      final zone = PrivacyZone.fromMap(const <String, Object?>{
        'identifier': 'a',
        'latitude': 0,
        'longitude': 0,
        'radius': 100,
        'action': 'eventOnly',
      });
      expect(zone.action, PrivacyZoneAction.eventOnly);
    });

    test('fromMap handles snake_case action value', () {
      final zone = PrivacyZone.fromMap(const <String, Object?>{
        'identifier': 'a',
        'latitude': 0,
        'longitude': 0,
        'radius': 100,
        'action': 'event_only',
      });
      expect(zone.action, PrivacyZoneAction.eventOnly);
    });

    test('fromMap handles integer action values', () {
      final exclude = PrivacyZone.fromMap(const <String, Object?>{
        'identifier': 'a',
        'latitude': 0,
        'longitude': 0,
        'radius': 100,
        'action': 0,
      });
      expect(exclude.action, PrivacyZoneAction.exclude);

      final degrade = PrivacyZone.fromMap(const <String, Object?>{
        'identifier': 'b',
        'latitude': 0,
        'longitude': 0,
        'radius': 100,
        'action': 1,
      });
      expect(degrade.action, PrivacyZoneAction.degrade);

      final eventOnly = PrivacyZone.fromMap(const <String, Object?>{
        'identifier': 'c',
        'latitude': 0,
        'longitude': 0,
        'radius': 100,
        'action': 2,
      });
      expect(eventOnly.action, PrivacyZoneAction.eventOnly);
    });

    test('fromMap handles snake_case degradedAccuracyMeters', () {
      final zone = PrivacyZone.fromMap(const <String, Object?>{
        'identifier': 'a',
        'latitude': 0,
        'longitude': 0,
        'radius': 100,
        'degraded_accuracy_meters': 2000.0,
      });
      expect(zone.degradedAccuracyMeters, 2000.0);
    });

    test('equality by identifier', () {
      const a = PrivacyZone(
        identifier: 'home',
        latitude: 37.7749,
        longitude: -122.4194,
        radius: 200,
      );
      const b = PrivacyZone(
        identifier: 'home',
        latitude: 0, // Different coords
        longitude: 0,
        radius: 100,
      );
      const c = PrivacyZone(
        identifier: 'office',
        latitude: 37.7749,
        longitude: -122.4194,
        radius: 200,
      );
      expect(a, equals(b)); // Same identifier
      expect(a, isNot(equals(c))); // Different identifier
    });

    test('hashCode based on identifier', () {
      const a = PrivacyZone(
        identifier: 'home',
        latitude: 37.7749,
        longitude: -122.4194,
        radius: 200,
      );
      const b = PrivacyZone(
        identifier: 'home',
        latitude: 0,
        longitude: 0,
        radius: 0,
      );
      expect(a.hashCode, b.hashCode);
    });

    test('toString contains identifier', () {
      const zone = PrivacyZone(
        identifier: 'test_zone',
        latitude: 0,
        longitude: 0,
        radius: 100,
      );
      expect(zone.toString(), contains('test_zone'));
    });
  });

  // ==========================================================================
  // Config integration
  // ==========================================================================
  group('Config privacy zone integration', () {
    test('Config default includes privacyZone disabled', () {
      const config = Config();
      expect(config.privacyZone.enabled, false);
    });

    test('Config with privacyZone enabled', () {
      const config = Config(privacyZone: PrivacyZoneConfig(enabled: true));
      expect(config.privacyZone.enabled, true);
    });

    test('Config round-trip preserves privacyZone', () {
      const original = Config(privacyZone: PrivacyZoneConfig(enabled: true));
      final map = original.toMap();
      final restored = Config.fromMap(map);
      expect(restored.privacyZone.enabled, true);
    });

    test('Config toMap includes privacyZone section', () {
      const config = Config(privacyZone: PrivacyZoneConfig(enabled: true));
      final map = config.toMap();
      expect(map.containsKey('privacyZone'), true);
      final section = map['privacyZone'] as Map<String, Object?>;
      expect(section['privacyZoneEnabled'], true);
    });

    test('Config equality considers privacyZone', () {
      const a = Config(privacyZone: PrivacyZoneConfig(enabled: true));
      const b = Config(privacyZone: PrivacyZoneConfig(enabled: true));
      const c = Config(privacyZone: PrivacyZoneConfig(enabled: false));
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('Config hashCode considers privacyZone', () {
      const a = Config(privacyZone: PrivacyZoneConfig(enabled: true));
      const b = Config(privacyZone: PrivacyZoneConfig(enabled: true));
      expect(a.hashCode, b.hashCode);
    });

    test('Config toString includes privacyZone', () {
      const config = Config(privacyZone: PrivacyZoneConfig(enabled: true));
      expect(config.toString(), contains('privacyZone'));
    });
  });
}
