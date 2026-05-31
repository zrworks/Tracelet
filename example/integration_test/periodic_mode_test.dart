import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracelet/tracelet.dart';

/// Integration tests for the Periodic Mode feature.
///
/// These tests verify GeoConfig and AndroidConfig serialization for periodic mode properties,
/// tracking mode enum, and configuration combinations. Actual periodic
/// scheduling requires a real device with background execution.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Periodic Mode Properties', () {
    testWidgets('Config accepts periodic mode properties', (tester) async {
      const config = Config(
        geo: GeoConfig(
          periodicLocationInterval: 300,
          periodicDesiredAccuracy: DesiredAccuracy.high,
        ),
        android: AndroidConfig(periodicUseForegroundService: true),
      );

      expect(config.geo.periodicLocationInterval, 300);
      expect(config.geo.periodicDesiredAccuracy, DesiredAccuracy.high);
      expect(config.android.periodicUseForegroundService, isTrue);
      expect(config.android.periodicUseExactAlarms, isFalse);
    });

    testWidgets('Periodic defaults are correct', (tester) async {
      const config = Config();

      expect(config.geo.periodicLocationInterval, 900);
      expect(config.geo.periodicDesiredAccuracy, DesiredAccuracy.medium);
      expect(config.android.periodicUseForegroundService, isFalse);
      expect(config.android.periodicUseExactAlarms, isFalse);
    });

    testWidgets('Config.toMap includes periodic fields', (tester) async {
      const config = Config(
        geo: GeoConfig(
          periodicLocationInterval: 1800,
          periodicDesiredAccuracy: DesiredAccuracy.low,
        ),
        android: AndroidConfig(periodicUseExactAlarms: true),
      );
      final map = config.toMap();
      final geoMap = map['geo']! as Map<String, Object?>;
      final androidMap = map['android']! as Map<String, Object?>;

      expect(geoMap['periodicLocationInterval'], 1800);
      expect(androidMap['periodicUseExactAlarms'], isTrue);
    });
  });

  group('Periodic Mode — Configuration Combinations', () {
    testWidgets('WorkManager config (default)', (tester) async {
      const config = Config();

      // WorkManager: no notification, 15-min minimum
      expect(config.android.periodicUseForegroundService, isFalse);
      expect(config.android.periodicUseExactAlarms, isFalse);
      expect(config.geo.periodicLocationInterval, greaterThanOrEqualTo(60));
    });

    testWidgets('Foreground Service config', (tester) async {
      const config = Config(
        geo: GeoConfig(
          periodicLocationInterval: 300, // 5 min — needs FG service
          periodicDesiredAccuracy: DesiredAccuracy.high,
        ),
        android: AndroidConfig(periodicUseForegroundService: true),
      );

      expect(config.android.periodicUseForegroundService, isTrue);
      expect(config.geo.periodicLocationInterval, 300);
    });

    testWidgets('Exact Alarms config', (tester) async {
      const config = Config(
        geo: GeoConfig(periodicLocationInterval: 1800),
        android: AndroidConfig(periodicUseExactAlarms: true),
      );

      expect(config.android.periodicUseExactAlarms, isTrue);
      expect(config.android.periodicUseForegroundService, isFalse);
    });

    testWidgets('min interval boundary (60s)', (tester) async {
      const config = GeoConfig(periodicLocationInterval: 60);
      expect(config.periodicLocationInterval, 60);
    });

    testWidgets('max interval boundary (43200s = 12hr)', (tester) async {
      const config = GeoConfig(periodicLocationInterval: 43200);
      expect(config.periodicLocationInterval, 43200);
    });
  });

  group('TrackingMode — Enum Values', () {
    testWidgets('TrackingMode.periodic exists', (tester) async {
      expect(TrackingMode.periodic, isNotNull);
      expect(TrackingMode.periodic, isA<TrackingMode>());
    });

    testWidgets('all tracking modes are available', (tester) async {
      expect(TrackingMode.location, isNotNull);
      expect(TrackingMode.geofences, isNotNull);
      expect(TrackingMode.periodic, isNotNull);
    });
  });

  group('Config — Full Periodic Config', () {
    testWidgets('Config round-trips periodic settings through toMap', (
      tester,
    ) async {
      const config = Config(
        geo: GeoConfig(
          periodicLocationInterval: 600,
          periodicDesiredAccuracy: DesiredAccuracy.high,
        ),
        android: AndroidConfig(periodicUseForegroundService: true),
      );

      final map = config.toMap();
      final geoMap = map['geo']! as Map<String, Object?>;
      final androidMap = map['android']! as Map<String, Object?>;
      expect(geoMap['periodicLocationInterval'], 600);
      expect(androidMap['periodicUseForegroundService'], isTrue);
    });

    testWidgets('periodic config combined with app config', (tester) async {
      const config = Config(
        android: AndroidConfig(
          periodicUseForegroundService: true,
          foregroundService: ForegroundServiceConfig(
            notificationTitle: 'Periodic Tracking',
            notificationText: 'Check-in every 15 min',
          ),
        ),
        app: AppConfig(stopOnTerminate: false, startOnBoot: true),
      );

      final map = config.toMap();
      expect(map.containsKey('geo'), isTrue);
      expect(map.containsKey('app'), isTrue);
      expect(map.containsKey('android'), isTrue);
    });
  });
}
