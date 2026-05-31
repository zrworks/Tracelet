import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracelet/tracelet.dart';

/// Integration test for GitHub issue #58:
///   "Geofence extras missing in callback after 1.8.12 fix (Android)"
///
/// Reproduces the bug end-to-end on a real device: registers a geofence
/// with `extras` and asserts that the `extras` map survives the full
/// Dart → Pigeon → SDK → SQLite → cursorToGeofence → Pigeon → Dart
/// round-trip via the public `Tracelet.getGeofences()` API.
///
/// Root cause was in `pigeon_tracelet.dart::_mapToGeofence` which
/// silently dropped both `extras` and `vertices` when constructing the
/// `TlGeofence` payload sent over the platform channel — so they never
/// reached SQLite at all. The 1.8.12 fix had patched the read path on
/// Android but the write path was already broken at the platform-
/// interface layer.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Geofence extras round-trip (issue #58)', () {
    tearDown(() async {
      await Tracelet.stop();
      await Tracelet.removeGeofences();
    });

    testWidgets(
      'addGeofence persists extras map intact (read back via getGeofences)',
      (tester) async {
        await Tracelet.ready(
          const Config(
            logger: LoggerConfig(debug: true, logLevel: LogLevel.verbose),
          ),
        );

        // Same shape as the reporter's repro in the issue.
        const expectedExtras = <String, Object?>{
          'demo_test': 'Hello from the geofence extras!',
          'Hello': 'World',
        };

        await Tracelet.addGeofence(
          const Geofence(
            identifier: 'test-issue-58',
            latitude: 12.9716,
            longitude: 77.5946,
            radius: 500,
            extras: expectedExtras,
          ),
        );
        // addGeofence may return false if location permission isn't granted
        // for OS-level GeofencingClient registration — but the row is still
        // persisted to SQLite, which is what we're verifying here.

        final stored = await Tracelet.getGeofences();
        final storedGf = stored.firstWhere(
          (g) => g.identifier == 'test-issue-58',
        );
        debugPrint('[TEST] Stored extras: ${storedGf.extras}');

        expect(
          storedGf.extras,
          equals(expectedExtras),
          reason: 'extras must round-trip Dart→Pigeon→SDK→SQLite→Dart intact',
        );
      },
    );
  });
}
