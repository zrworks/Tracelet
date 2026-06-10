import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracelet/tracelet.dart';

/// Integration tests for Issue #141 — `encryptDatabase: true` must NOT break the
/// location data path (the report was: with encryption on, no location events /
/// no readable data flow through).
///
/// These exercise the full Dart → native → Rust AES-GCM → readback round-trip on
/// a real device/emulator. Run with:
///   flutter test integration_test/issue_141_encryption_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> insertSample(double lat, double lng) {
    return Tracelet.insertLocation({
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'coords': {'latitude': lat, 'longitude': lng, 'accuracy': 5.0},
      'activity': {'type': 'walking', 'confidence': 100},
    });
  }

  group('Issue 141 — encrypted database round-trip', () {
    testWidgets('encryptDatabase:true WITH key — insert/read round-trips', (
      tester,
    ) async {
      await Tracelet.ready(
        const Config(
          geo: GeoConfig(distanceFilter: 0),
          security: SecurityConfig(
            encryptDatabase: true,
            encryptionKey: 'issue-141-test-key',
          ),
        ),
      );
      await Tracelet.destroyLocations();

      await insertSample(48.8566, 2.3522);
      await insertSample(48.8570, 2.3530);

      final locations = await Tracelet.getLocations();

      expect(
        locations.length,
        2,
        reason: 'encrypted inserts must be readable back',
      );
      // Decryption must yield the real coordinates, not the 0.0 plaintext
      // columns that encrypted rows are stored with.
      expect(locations.first.coords.latitude, closeTo(48.8566, 1e-6));
      expect(locations.first.coords.longitude, closeTo(2.3522, 1e-6));
      expect(locations.first.coords.latitude, isNot(0.0));

      await Tracelet.stop();
    });

    testWidgets('encryptDatabase:true WITHOUT key — still works (the #141 repro)', (
      tester,
    ) async {
      // The reporter's exact config: encryption on, no key supplied.
      await Tracelet.ready(
        const Config(
          geo: GeoConfig(distanceFilter: 0),
          security: SecurityConfig(encryptDatabase: true),
        ),
      );
      await Tracelet.destroyLocations();

      await insertSample(10.5, 20.5);

      final locations = await Tracelet.getLocations();
      expect(
        locations.length,
        1,
        reason: 'encryptDatabase:true must not break the data path (#141)',
      );
      expect(locations.first.coords.latitude, closeTo(10.5, 1e-6));

      await Tracelet.stop();
    });

    testWidgets('parity: encrypted vs unencrypted both round-trip', (
      tester,
    ) async {
      // Unencrypted control (default security).
      await Tracelet.ready(const Config());
      await Tracelet.destroyLocations();
      await insertSample(1.5, 2.5);
      final plain = await Tracelet.getLocations();
      await Tracelet.stop();

      // Encrypted.
      await Tracelet.ready(
        const Config(
          security: SecurityConfig(
            encryptDatabase: true,
            encryptionKey: 'parity-key',
          ),
        ),
      );
      await Tracelet.destroyLocations();
      await insertSample(1.5, 2.5);
      final encrypted = await Tracelet.getLocations();
      await Tracelet.stop();

      expect(plain.length, encrypted.length);
      expect(plain.first.coords.latitude, encrypted.first.coords.latitude);
    });
  });
}
