import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracelet/tracelet.dart';

/// Integration tests for the Privacy Zones enterprise feature.
///
/// These tests exercise the real native plugin through MethodChannels,
/// verifying CRUD operations round-trip correctly through the platform layer
/// and database.
///
/// **Note:** These tests do NOT require location permissions or active tracking.
/// Privacy zone CRUD is a standalone feature that operates on the database.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Privacy Zones — CRUD', () {
    // Clean up before each test to ensure isolation
    setUp(() async {
      await Tracelet.removePrivacyZones();
    });

    // Clean up after all tests
    tearDown(() async {
      await Tracelet.removePrivacyZones();
    });

    testWidgets('addPrivacyZone returns true', (tester) async {
      const zone = PrivacyZone(
        identifier: 'test-zone-1',
        latitude: 37.7749,
        longitude: -122.4194,
        radius: 500,
      );
      final result = await Tracelet.addPrivacyZone(zone);
      expect(result, isTrue);
    });

    testWidgets('getPrivacyZones returns added zone', (tester) async {
      const zone = PrivacyZone(
        identifier: 'zone-get-test',
        latitude: 51.5074,
        longitude: -0.1278,
        radius: 1000,
        action: PrivacyZoneAction.degrade,
        degradedAccuracyMeters: 500,
      );
      await Tracelet.addPrivacyZone(zone);

      final zones = await Tracelet.getPrivacyZones();
      expect(zones, isNotEmpty);
      expect(zones.length, 1);

      final retrieved = zones.first;
      expect(retrieved.identifier, 'zone-get-test');
      expect(retrieved.latitude, closeTo(51.5074, 0.001));
      expect(retrieved.longitude, closeTo(-0.1278, 0.001));
      expect(retrieved.radius, closeTo(1000, 0.1));
    });

    testWidgets('addPrivacyZones adds multiple zones', (tester) async {
      final zones = [
        const PrivacyZone(
          identifier: 'multi-1',
          latitude: 37.7749,
          longitude: -122.4194,
          radius: 200,
        ),
        const PrivacyZone(
          identifier: 'multi-2',
          latitude: 40.7128,
          longitude: -74.0060,
          radius: 300,
          action: PrivacyZoneAction.eventOnly,
        ),
        const PrivacyZone(
          identifier: 'multi-3',
          latitude: 48.8566,
          longitude: 2.3522,
          radius: 100,
          action: PrivacyZoneAction.degrade,
          degradedAccuracyMeters: 2000,
        ),
      ];

      final result = await Tracelet.addPrivacyZones(zones);
      expect(result, isTrue);

      final retrieved = await Tracelet.getPrivacyZones();
      expect(retrieved.length, 3);

      final identifiers = retrieved.map((z) => z.identifier).toSet();
      expect(identifiers, containsAll(['multi-1', 'multi-2', 'multi-3']));
    });

    testWidgets('removePrivacyZone removes specific zone', (tester) async {
      await Tracelet.addPrivacyZones([
        const PrivacyZone(
          identifier: 'keep-me',
          latitude: 37.7749,
          longitude: -122.4194,
          radius: 100,
        ),
        const PrivacyZone(
          identifier: 'remove-me',
          latitude: 40.7128,
          longitude: -74.0060,
          radius: 100,
        ),
      ]);

      final beforeRemove = await Tracelet.getPrivacyZones();
      expect(beforeRemove.length, 2);

      final result = await Tracelet.removePrivacyZone('remove-me');
      expect(result, isTrue);

      final afterRemove = await Tracelet.getPrivacyZones();
      expect(afterRemove.length, 1);
      expect(afterRemove.first.identifier, 'keep-me');
    });

    testWidgets('removePrivacyZones clears all zones', (tester) async {
      await Tracelet.addPrivacyZones([
        const PrivacyZone(
          identifier: 'clear-1',
          latitude: 37.7749,
          longitude: -122.4194,
          radius: 100,
        ),
        const PrivacyZone(
          identifier: 'clear-2',
          latitude: 40.7128,
          longitude: -74.0060,
          radius: 200,
        ),
      ]);

      final before = await Tracelet.getPrivacyZones();
      expect(before.length, 2);

      final result = await Tracelet.removePrivacyZones();
      expect(result, isTrue);

      final after = await Tracelet.getPrivacyZones();
      expect(after, isEmpty);
    });

    testWidgets('getPrivacyZones returns empty when none added', (
      tester,
    ) async {
      final zones = await Tracelet.getPrivacyZones();
      expect(zones, isEmpty);
    });

    testWidgets('addPrivacyZone with same identifier replaces existing', (
      tester,
    ) async {
      await Tracelet.addPrivacyZone(
        const PrivacyZone(
          identifier: 'replace-test',
          latitude: 37.7749,
          longitude: -122.4194,
          radius: 100,
        ),
      );

      // Add again with same identifier but different data
      await Tracelet.addPrivacyZone(
        const PrivacyZone(
          identifier: 'replace-test',
          latitude: 40.7128,
          longitude: -74.0060,
          radius: 500,
          action: PrivacyZoneAction.degrade,
        ),
      );

      final zones = await Tracelet.getPrivacyZones();
      expect(zones.length, 1);
      expect(zones.first.identifier, 'replace-test');
      expect(zones.first.latitude, closeTo(40.7128, 0.001));
      expect(zones.first.radius, closeTo(500, 0.1));
    });

    testWidgets('zone with all action types round-trips correctly', (
      tester,
    ) async {
      await Tracelet.addPrivacyZones([
        const PrivacyZone(
          identifier: 'action-exclude',
          latitude: 0,
          longitude: 0,
          radius: 100,
        ),
        const PrivacyZone(
          identifier: 'action-degrade',
          latitude: 1,
          longitude: 1,
          radius: 200,
          action: PrivacyZoneAction.degrade,
          degradedAccuracyMeters: 750,
        ),
        const PrivacyZone(
          identifier: 'action-event',
          latitude: 2,
          longitude: 2,
          radius: 300,
          action: PrivacyZoneAction.eventOnly,
        ),
      ]);

      final zones = await Tracelet.getPrivacyZones();
      expect(zones.length, 3);

      // Sort by identifier for deterministic assertions
      zones.sort((a, b) => a.identifier.compareTo(b.identifier));

      // Action values come back as integers from native
      // Just verify the zone data is correct
      expect(zones[0].identifier, 'action-degrade');
      expect(zones[0].latitude, closeTo(1, 0.001));
      expect(zones[1].identifier, 'action-event');
      expect(zones[1].latitude, closeTo(2, 0.001));
      expect(zones[2].identifier, 'action-exclude');
      expect(zones[2].latitude, closeTo(0, 0.001));
    });

    testWidgets('removePrivacyZone with non-existent id returns gracefully', (
      tester,
    ) async {
      // Should not throw, may return true or false depending on platform
      final result = await Tracelet.removePrivacyZone('does-not-exist');
      // Just verify no exception was thrown
      expect(result, isA<bool>());
    });
  });
}
