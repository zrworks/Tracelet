import 'package:flutter_test/flutter_test.dart';
import 'package:tracelet/tracelet.dart';

void main() {
  // ==========================================================================
  // HealthWarning
  // ==========================================================================
  group('HealthWarning', () {
    test('has expected values', () {
      expect(HealthWarning.values.length, 12);
      expect(HealthWarning.locationPermissionDenied.index, 0);
      expect(HealthWarning.locationPermissionDeniedForever.index, 1);
      expect(HealthWarning.locationServicesDisabled.index, 2);
      expect(HealthWarning.powerSaveMode.index, 3);
      expect(HealthWarning.aggressiveOem.index, 4);
      expect(HealthWarning.batteryOptimizationsNotIgnored.index, 5);
      expect(HealthWarning.reducedAccuracy.index, 6);
      expect(HealthWarning.noAccelerometer.index, 7);
      expect(HealthWarning.noSignificantMotion.index, 8);
      expect(HealthWarning.motionPermissionDenied.index, 9);
      expect(HealthWarning.mockLocationsDetected.index, 10);
      expect(HealthWarning.locationPermissionOnlyWhenInUse.index, 11);
    });
  });

  // ==========================================================================
  // HealthCheck
  // ==========================================================================
  group('HealthCheck', () {
    /// Returns a fully-healthy set of platform maps (all green).
    Map<String, Object?> healthyState() => <String, Object?>{
      'enabled': true,
      'trackingMode': 0,
      'isMoving': true,
      'odometer': 12345.6,
      'schedulerEnabled': false,
      'didLaunchInBackground': false,
      'didDeviceReboot': false,
    };

    Map<String, Object?> healthyProvider() => <String, Object?>{
      'enabled': true,
      'status': 3, // always
      'gps': true,
      'network': true,
      'accuracyAuthorization': 0, // full
      'mockLocationsDetected': false,
      'platform': 'android',
    };

    Map<String, Object?> healthySettingsHealth() => <String, Object?>{
      'manufacturer': 'Google',
      'model': 'Pixel 8',
      'isAggressiveOem': false,
      'aggressionRating': 0,
      'isIgnoringBatteryOptimizations': true,
      'autostartAvailable': false,
      'oemSettingsScreens': <Map<String, String>>[],
    };

    Map<String, Object?> healthySensors() => <String, Object?>{
      'platform': 'android',
      'accelerometer': true,
      'gyroscope': true,
      'magnetometer': true,
      'significantMotion': true,
    };

    Map<String, Object?> healthyDeviceInfo() => <String, Object?>{
      'model': 'Pixel 8',
      'manufacturer': 'Google',
      'version': '14',
      'platform': 'android',
      'framework': 'flutter',
    };

    HealthCheck buildHealthy() => HealthCheck.fromMaps(
      state: healthyState(),
      provider: healthyProvider(),
      settingsHealth: healthySettingsHealth(),
      sensors: healthySensors(),
      deviceInfo: healthyDeviceInfo(),
      isPowerSave: false,
      ignoringBatteryOpt: true,
      locationPermissionStatus: 3, // always
      motionPermissionStatus: 3, // granted
      dbCount: 42,
    );

    // -----------------------------------------------------------------------
    // Constructor / fromMaps
    // -----------------------------------------------------------------------
    group('fromMaps', () {
      test('parses all fields from healthy data', () {
        final health = buildHealthy();

        // Tracking state
        expect(health.trackingEnabled, true);
        expect(health.trackingMode, TrackingMode.location);
        expect(health.isMoving, true);
        expect(health.odometer, 12345.6);
        expect(health.schedulerEnabled, false);
        expect(health.didLaunchInBackground, false);
        expect(health.didDeviceReboot, false);

        // Permissions
        expect(health.locationPermission, AuthorizationStatus.always);
        expect(health.motionPermission, 3);
        expect(health.accuracyAuthorization, AccuracyAuthorization.full);

        // Provider
        expect(health.locationServicesEnabled, true);
        expect(health.gpsEnabled, true);
        expect(health.networkEnabled, true);

        // Battery & power
        expect(health.isPowerSaveMode, false);
        expect(health.isIgnoringBatteryOptimizations, true);

        // OEM
        expect(health.manufacturer, 'Google');
        expect(health.model, 'Pixel 8');
        expect(health.isAggressiveOem, false);
        expect(health.aggressionRating, 0);

        // Sensors
        expect(health.hasAccelerometer, true);
        expect(health.hasGyroscope, true);
        expect(health.hasMagnetometer, true);
        expect(health.hasSignificantMotion, true);

        // Database
        expect(health.locationCount, 42);

        // Device
        expect(health.platform, 'android');
        expect(health.osVersion, '14');

        // Diagnostics
        expect(health.mockLocationsDetected, false);
        expect(health.timestamp, isA<DateTime>());
      });

      test('produces no warnings for fully healthy state', () {
        final health = buildHealthy();
        expect(health.warnings, isEmpty);
        expect(health.isHealthy, true);
        expect(health.hasWarnings, false);
        expect(health.warningCount, 0);
      });

      test('parses geofences tracking mode', () {
        final state = healthyState();
        state['trackingMode'] = 1;
        final health = HealthCheck.fromMaps(
          state: state,
          provider: healthyProvider(),
          settingsHealth: healthySettingsHealth(),
          sensors: healthySensors(),
          deviceInfo: healthyDeviceInfo(),
          isPowerSave: false,
          ignoringBatteryOpt: true,
          locationPermissionStatus: 3,
          motionPermissionStatus: 3,
          dbCount: 0,
        );
        expect(health.trackingMode, TrackingMode.geofences);
      });

      test('clamps out-of-range tracking mode index', () {
        final state = healthyState();
        state['trackingMode'] = 99;
        final health = HealthCheck.fromMaps(
          state: state,
          provider: healthyProvider(),
          settingsHealth: healthySettingsHealth(),
          sensors: healthySensors(),
          deviceInfo: healthyDeviceInfo(),
          isPowerSave: false,
          ignoringBatteryOpt: true,
          locationPermissionStatus: 3,
          motionPermissionStatus: 3,
          dbCount: 0,
        );
        // Clamped to max valid index.
        expect(
          health.trackingMode,
          TrackingMode.values[TrackingMode.values.length - 1],
        );
      });

      test('uses model from settingsHealth first, then deviceInfo', () {
        final settings = healthySettingsHealth();
        settings['model'] = 'OEM Model';
        final health = HealthCheck.fromMaps(
          state: healthyState(),
          provider: healthyProvider(),
          settingsHealth: settings,
          sensors: healthySensors(),
          deviceInfo: healthyDeviceInfo(),
          isPowerSave: false,
          ignoringBatteryOpt: true,
          locationPermissionStatus: 3,
          motionPermissionStatus: 3,
          dbCount: 0,
        );
        expect(health.model, 'OEM Model');
      });

      test(
        'falls back to deviceInfo model when settingsHealth model is null',
        () {
          final settings = healthySettingsHealth();
          settings.remove('model');
          final health = HealthCheck.fromMaps(
            state: healthyState(),
            provider: healthyProvider(),
            settingsHealth: settings,
            sensors: healthySensors(),
            deviceInfo: healthyDeviceInfo(),
            isPowerSave: false,
            ignoringBatteryOpt: true,
            locationPermissionStatus: 3,
            motionPermissionStatus: 3,
            dbCount: 0,
          );
          expect(health.model, 'Pixel 8');
        },
      );

      test('uses platform from deviceInfo, falls back to provider', () {
        final device = healthyDeviceInfo();
        device.remove('platform');
        final health = HealthCheck.fromMaps(
          state: healthyState(),
          provider: healthyProvider(),
          settingsHealth: healthySettingsHealth(),
          sensors: healthySensors(),
          deviceInfo: device,
          isPowerSave: false,
          ignoringBatteryOpt: true,
          locationPermissionStatus: 3,
          motionPermissionStatus: 3,
          dbCount: 0,
        );
        expect(health.platform, 'android');
      });
    });

    // -----------------------------------------------------------------------
    // Warnings
    // -----------------------------------------------------------------------
    group('warnings', () {
      test('warns on denied location permission', () {
        final health = HealthCheck.fromMaps(
          state: healthyState(),
          provider: healthyProvider(),
          settingsHealth: healthySettingsHealth(),
          sensors: healthySensors(),
          deviceInfo: healthyDeviceInfo(),
          isPowerSave: false,
          ignoringBatteryOpt: true,
          locationPermissionStatus: 1, // denied
          motionPermissionStatus: 3,
          dbCount: 0,
        );
        expect(
          health.warnings,
          contains(HealthWarning.locationPermissionDenied),
        );
      });

      test('warns on notDetermined location permission', () {
        final health = HealthCheck.fromMaps(
          state: healthyState(),
          provider: healthyProvider(),
          settingsHealth: healthySettingsHealth(),
          sensors: healthySensors(),
          deviceInfo: healthyDeviceInfo(),
          isPowerSave: false,
          ignoringBatteryOpt: true,
          locationPermissionStatus: 0, // notDetermined
          motionPermissionStatus: 3,
          dbCount: 0,
        );
        expect(
          health.warnings,
          contains(HealthWarning.locationPermissionDenied),
        );
      });

      test('warns on deniedForever location permission', () {
        final health = HealthCheck.fromMaps(
          state: healthyState(),
          provider: healthyProvider(),
          settingsHealth: healthySettingsHealth(),
          sensors: healthySensors(),
          deviceInfo: healthyDeviceInfo(),
          isPowerSave: false,
          ignoringBatteryOpt: true,
          locationPermissionStatus: 4, // deniedForever
          motionPermissionStatus: 3,
          dbCount: 0,
        );
        expect(
          health.warnings,
          contains(HealthWarning.locationPermissionDeniedForever),
        );
        expect(
          health.warnings,
          isNot(contains(HealthWarning.locationPermissionDenied)),
        );
      });

      test('warns on whenInUse location permission', () {
        final health = HealthCheck.fromMaps(
          state: healthyState(),
          provider: healthyProvider(),
          settingsHealth: healthySettingsHealth(),
          sensors: healthySensors(),
          deviceInfo: healthyDeviceInfo(),
          isPowerSave: false,
          ignoringBatteryOpt: true,
          locationPermissionStatus: 2, // whenInUse
          motionPermissionStatus: 3,
          dbCount: 0,
        );
        expect(
          health.warnings,
          contains(HealthWarning.locationPermissionOnlyWhenInUse),
        );
      });

      test('warns on disabled location services', () {
        final provider = healthyProvider();
        provider['enabled'] = false;
        final health = HealthCheck.fromMaps(
          state: healthyState(),
          provider: provider,
          settingsHealth: healthySettingsHealth(),
          sensors: healthySensors(),
          deviceInfo: healthyDeviceInfo(),
          isPowerSave: false,
          ignoringBatteryOpt: true,
          locationPermissionStatus: 3,
          motionPermissionStatus: 3,
          dbCount: 0,
        );
        expect(
          health.warnings,
          contains(HealthWarning.locationServicesDisabled),
        );
      });

      test('warns on power save mode', () {
        final health = HealthCheck.fromMaps(
          state: healthyState(),
          provider: healthyProvider(),
          settingsHealth: healthySettingsHealth(),
          sensors: healthySensors(),
          deviceInfo: healthyDeviceInfo(),
          isPowerSave: true,
          ignoringBatteryOpt: true,
          locationPermissionStatus: 3,
          motionPermissionStatus: 3,
          dbCount: 0,
        );
        expect(health.warnings, contains(HealthWarning.powerSaveMode));
      });

      test('warns on aggressive OEM', () {
        final settings = healthySettingsHealth();
        settings['isAggressiveOem'] = true;
        settings['aggressionRating'] = 4;
        final health = HealthCheck.fromMaps(
          state: healthyState(),
          provider: healthyProvider(),
          settingsHealth: settings,
          sensors: healthySensors(),
          deviceInfo: healthyDeviceInfo(),
          isPowerSave: false,
          ignoringBatteryOpt: true,
          locationPermissionStatus: 3,
          motionPermissionStatus: 3,
          dbCount: 0,
        );
        expect(health.warnings, contains(HealthWarning.aggressiveOem));
        expect(health.aggressionRating, 4);
      });

      test('warns when battery optimizations NOT ignored', () {
        final health = HealthCheck.fromMaps(
          state: healthyState(),
          provider: healthyProvider(),
          settingsHealth: healthySettingsHealth(),
          sensors: healthySensors(),
          deviceInfo: healthyDeviceInfo(),
          isPowerSave: false,
          ignoringBatteryOpt: false,
          locationPermissionStatus: 3,
          motionPermissionStatus: 3,
          dbCount: 0,
        );
        expect(
          health.warnings,
          contains(HealthWarning.batteryOptimizationsNotIgnored),
        );
      });

      test('warns on reduced accuracy', () {
        final provider = healthyProvider();
        provider['accuracyAuthorization'] = 1; // reduced
        final health = HealthCheck.fromMaps(
          state: healthyState(),
          provider: provider,
          settingsHealth: healthySettingsHealth(),
          sensors: healthySensors(),
          deviceInfo: healthyDeviceInfo(),
          isPowerSave: false,
          ignoringBatteryOpt: true,
          locationPermissionStatus: 3,
          motionPermissionStatus: 3,
          dbCount: 0,
        );
        expect(health.warnings, contains(HealthWarning.reducedAccuracy));
      });

      test('warns on missing accelerometer', () {
        final sensors = healthySensors();
        sensors['accelerometer'] = false;
        final health = HealthCheck.fromMaps(
          state: healthyState(),
          provider: healthyProvider(),
          settingsHealth: healthySettingsHealth(),
          sensors: sensors,
          deviceInfo: healthyDeviceInfo(),
          isPowerSave: false,
          ignoringBatteryOpt: true,
          locationPermissionStatus: 3,
          motionPermissionStatus: 3,
          dbCount: 0,
        );
        expect(health.warnings, contains(HealthWarning.noAccelerometer));
      });

      test('warns on missing significant motion sensor', () {
        final sensors = healthySensors();
        sensors['significantMotion'] = false;
        final health = HealthCheck.fromMaps(
          state: healthyState(),
          provider: healthyProvider(),
          settingsHealth: healthySettingsHealth(),
          sensors: sensors,
          deviceInfo: healthyDeviceInfo(),
          isPowerSave: false,
          ignoringBatteryOpt: true,
          locationPermissionStatus: 3,
          motionPermissionStatus: 3,
          dbCount: 0,
        );
        expect(health.warnings, contains(HealthWarning.noSignificantMotion));
      });

      test('warns on denied motion permission', () {
        final health = HealthCheck.fromMaps(
          state: healthyState(),
          provider: healthyProvider(),
          settingsHealth: healthySettingsHealth(),
          sensors: healthySensors(),
          deviceInfo: healthyDeviceInfo(),
          isPowerSave: false,
          ignoringBatteryOpt: true,
          locationPermissionStatus: 3,
          motionPermissionStatus: 2, // denied
          dbCount: 0,
        );
        expect(health.warnings, contains(HealthWarning.motionPermissionDenied));
      });

      test('warns on mock locations detected', () {
        final provider = healthyProvider();
        provider['mockLocationsDetected'] = true;
        final health = HealthCheck.fromMaps(
          state: healthyState(),
          provider: provider,
          settingsHealth: healthySettingsHealth(),
          sensors: healthySensors(),
          deviceInfo: healthyDeviceInfo(),
          isPowerSave: false,
          ignoringBatteryOpt: true,
          locationPermissionStatus: 3,
          motionPermissionStatus: 3,
          dbCount: 0,
        );
        expect(health.warnings, contains(HealthWarning.mockLocationsDetected));
      });

      test('accumulates multiple warnings', () {
        final provider = healthyProvider();
        provider['enabled'] = false;
        provider['mockLocationsDetected'] = true;
        final sensors = healthySensors();
        sensors['accelerometer'] = false;

        final health = HealthCheck.fromMaps(
          state: healthyState(),
          provider: provider,
          settingsHealth: healthySettingsHealth(),
          sensors: sensors,
          deviceInfo: healthyDeviceInfo(),
          isPowerSave: true,
          ignoringBatteryOpt: false,
          locationPermissionStatus: 1, // denied
          motionPermissionStatus: 2, // denied
          dbCount: 0,
        );

        expect(health.hasWarnings, true);
        expect(health.warningCount, greaterThanOrEqualTo(5));
        expect(
          health.warnings,
          containsAll([
            HealthWarning.locationPermissionDenied,
            HealthWarning.locationServicesDisabled,
            HealthWarning.powerSaveMode,
            HealthWarning.batteryOptimizationsNotIgnored,
            HealthWarning.noAccelerometer,
            HealthWarning.motionPermissionDenied,
            HealthWarning.mockLocationsDetected,
          ]),
        );
      });
    });

    // -----------------------------------------------------------------------
    // Convenience properties
    // -----------------------------------------------------------------------
    group('convenience', () {
      test('hasBackgroundPermission requires always + services enabled', () {
        final health = buildHealthy();
        expect(health.hasBackgroundPermission, true);
      });

      test('hasBackgroundPermission is false with whenInUse', () {
        final health = HealthCheck.fromMaps(
          state: healthyState(),
          provider: healthyProvider(),
          settingsHealth: healthySettingsHealth(),
          sensors: healthySensors(),
          deviceInfo: healthyDeviceInfo(),
          isPowerSave: false,
          ignoringBatteryOpt: true,
          locationPermissionStatus: 2, // whenInUse
          motionPermissionStatus: 3,
          dbCount: 0,
        );
        expect(health.hasBackgroundPermission, false);
      });

      test('hasBackgroundPermission is false with services disabled', () {
        final provider = healthyProvider();
        provider['enabled'] = false;
        final health = HealthCheck.fromMaps(
          state: healthyState(),
          provider: provider,
          settingsHealth: healthySettingsHealth(),
          sensors: healthySensors(),
          deviceInfo: healthyDeviceInfo(),
          isPowerSave: false,
          ignoringBatteryOpt: true,
          locationPermissionStatus: 3,
          motionPermissionStatus: 3,
          dbCount: 0,
        );
        expect(health.hasBackgroundPermission, false);
      });
    });

    // -----------------------------------------------------------------------
    // Serialization round-trip
    // -----------------------------------------------------------------------
    group('serialization', () {
      test('toMap/fromMap round-trip preserves all fields', () {
        final original = buildHealthy();
        final map = original.toMap();
        final restored = HealthCheck.fromMap(map);

        expect(restored.trackingEnabled, original.trackingEnabled);
        expect(restored.trackingMode, original.trackingMode);
        expect(restored.isMoving, original.isMoving);
        expect(restored.odometer, original.odometer);
        expect(restored.schedulerEnabled, original.schedulerEnabled);
        expect(restored.didLaunchInBackground, original.didLaunchInBackground);
        expect(restored.didDeviceReboot, original.didDeviceReboot);
        expect(restored.locationPermission, original.locationPermission);
        expect(restored.motionPermission, original.motionPermission);
        expect(restored.accuracyAuthorization, original.accuracyAuthorization);
        expect(
          restored.locationServicesEnabled,
          original.locationServicesEnabled,
        );
        expect(restored.gpsEnabled, original.gpsEnabled);
        expect(restored.networkEnabled, original.networkEnabled);
        expect(restored.isPowerSaveMode, original.isPowerSaveMode);
        expect(
          restored.isIgnoringBatteryOptimizations,
          original.isIgnoringBatteryOptimizations,
        );
        expect(restored.manufacturer, original.manufacturer);
        expect(restored.model, original.model);
        expect(restored.isAggressiveOem, original.isAggressiveOem);
        expect(restored.aggressionRating, original.aggressionRating);
        expect(restored.hasAccelerometer, original.hasAccelerometer);
        expect(restored.hasGyroscope, original.hasGyroscope);
        expect(restored.hasMagnetometer, original.hasMagnetometer);
        expect(restored.hasSignificantMotion, original.hasSignificantMotion);
        expect(restored.locationCount, original.locationCount);
        expect(restored.platform, original.platform);
        expect(restored.osVersion, original.osVersion);
        expect(restored.mockLocationsDetected, original.mockLocationsDetected);
      });

      test('toMap/fromMap round-trip preserves warnings', () {
        final provider = healthyProvider();
        provider['enabled'] = false;
        final original = HealthCheck.fromMaps(
          state: healthyState(),
          provider: provider,
          settingsHealth: healthySettingsHealth(),
          sensors: healthySensors(),
          deviceInfo: healthyDeviceInfo(),
          isPowerSave: true,
          ignoringBatteryOpt: false,
          locationPermissionStatus: 1,
          motionPermissionStatus: 2,
          dbCount: 10,
        );

        final map = original.toMap();
        final restored = HealthCheck.fromMap(map);

        expect(restored.warnings.length, original.warnings.length);
        for (var i = 0; i < original.warnings.length; i++) {
          expect(restored.warnings[i], original.warnings[i]);
        }
      });

      test('fromMap handles missing fields gracefully', () {
        final health = HealthCheck.fromMap(<String, Object?>{});
        expect(health.trackingEnabled, false);
        expect(health.trackingMode, TrackingMode.location);
        expect(health.locationPermission, AuthorizationStatus.notDetermined);
        expect(health.locationCount, 0);
        expect(health.platform, '');
        expect(health.warnings, isEmpty);
      });

      test('fromMap handles invalid warning indices', () {
        final health = HealthCheck.fromMap(<String, Object?>{
          'warnings': [0, 999, -1, 2],
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        });
        // Only valid indices 0 and 2 should be included.
        expect(health.warnings.length, 2);
        expect(health.warnings[0], HealthWarning.locationPermissionDenied);
        expect(health.warnings[1], HealthWarning.locationServicesDisabled);
      });

      test('toMap serializes timestamp as ISO 8601', () {
        final health = buildHealthy();
        final map = health.toMap();
        expect(map['timestamp'], isA<String>());
        expect(DateTime.tryParse(map['timestamp'] as String), isNotNull);
      });

      test('toMap serializes warnings as indices', () {
        final provider = healthyProvider();
        provider['enabled'] = false;
        final health = HealthCheck.fromMaps(
          state: healthyState(),
          provider: provider,
          settingsHealth: healthySettingsHealth(),
          sensors: healthySensors(),
          deviceInfo: healthyDeviceInfo(),
          isPowerSave: false,
          ignoringBatteryOpt: true,
          locationPermissionStatus: 3,
          motionPermissionStatus: 3,
          dbCount: 0,
        );
        final map = health.toMap();
        final rawWarnings = map['warnings'] as List<dynamic>;
        expect(
          rawWarnings,
          contains(HealthWarning.locationServicesDisabled.index),
        );
      });
    });

    // -----------------------------------------------------------------------
    // Equality
    // -----------------------------------------------------------------------
    group('equality', () {
      test('equal health checks are equal', () {
        // Both from same healthy data — all fields except timestamp should match.
        final a = HealthCheck(
          trackingEnabled: true,
          trackingMode: TrackingMode.location,
          isMoving: false,
          odometer: 100.0,
          locationPermission: AuthorizationStatus.always,
          locationServicesEnabled: true,
          isPowerSaveMode: false,
          isIgnoringBatteryOptimizations: true,
          manufacturer: 'Google',
          isAggressiveOem: false,
          hasAccelerometer: true,
          hasSignificantMotion: true,
          locationCount: 42,
          platform: 'android',
          timestamp: DateTime.utc(2025, 1, 1),
        );
        final b = HealthCheck(
          trackingEnabled: true,
          trackingMode: TrackingMode.location,
          isMoving: false,
          odometer: 100.0,
          locationPermission: AuthorizationStatus.always,
          locationServicesEnabled: true,
          isPowerSaveMode: false,
          isIgnoringBatteryOptimizations: true,
          manufacturer: 'Google',
          isAggressiveOem: false,
          hasAccelerometer: true,
          hasSignificantMotion: true,
          locationCount: 42,
          platform: 'android',
          timestamp: DateTime.utc(2025, 1, 1),
        );
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different health checks are not equal', () {
        final a = HealthCheck(
          trackingEnabled: true,
          trackingMode: TrackingMode.location,
          timestamp: DateTime.utc(2025, 1, 1),
        );
        final b = HealthCheck(
          trackingEnabled: false,
          trackingMode: TrackingMode.location,
          timestamp: DateTime.utc(2025, 1, 1),
        );
        expect(a, isNot(equals(b)));
      });
    });

    // -----------------------------------------------------------------------
    // toString
    // -----------------------------------------------------------------------
    group('toString', () {
      test('includes key fields', () {
        final health = buildHealthy();
        final str = health.toString();
        expect(str, contains('HealthCheck'));
        expect(str, contains('tracking: true'));
        expect(str, contains('permission: always'));
        expect(str, contains('locationServices: true'));
        expect(str, contains('warnings: 0'));
      });

      test('includes warning count', () {
        final provider = healthyProvider();
        provider['enabled'] = false;
        final health = HealthCheck.fromMaps(
          state: healthyState(),
          provider: provider,
          settingsHealth: healthySettingsHealth(),
          sensors: healthySensors(),
          deviceInfo: healthyDeviceInfo(),
          isPowerSave: true,
          ignoringBatteryOpt: false,
          locationPermissionStatus: 1,
          motionPermissionStatus: 3,
          dbCount: 0,
        );
        final str = health.toString();
        expect(str, contains('warnings: ${health.warningCount}'));
      });
    });

    // -----------------------------------------------------------------------
    // iOS-specific edge cases
    // -----------------------------------------------------------------------
    group('iOS edge cases', () {
      test('handles iOS settingsHealth format', () {
        final iosSettings = <String, Object?>{
          'manufacturer': 'Apple',
          'model': 'iPhone',
          'isAggressiveOem': false,
          'aggressionRating': 0,
          'isIgnoringBatteryOptimizations': true,
          'autostartAvailable': false,
          'oemSettingsScreens': <Map<String, String>>[],
        };
        final health = HealthCheck.fromMaps(
          state: healthyState(),
          provider: <String, Object?>{
            'enabled': true,
            'status': 3,
            'gps': true,
            'network': true,
            'accuracyAuthorization': 0,
            'platform': 'ios',
          },
          settingsHealth: iosSettings,
          sensors: <String, Object?>{
            'platform': 'ios',
            'accelerometer': true,
            'gyroscope': true,
            'magnetometer': true,
            'significantMotion': true,
            'motionActivity': true,
          },
          deviceInfo: <String, Object?>{
            'model': 'iPhone',
            'manufacturer': 'Apple',
            'version': '17.4',
            'platform': 'ios',
          },
          isPowerSave: false,
          ignoringBatteryOpt: true, // always true on iOS
          locationPermissionStatus: 3,
          motionPermissionStatus: 3,
          dbCount: 100,
        );

        expect(health.platform, 'ios');
        expect(health.manufacturer, 'Apple');
        expect(health.isAggressiveOem, false);
        expect(health.isIgnoringBatteryOptimizations, true);
        expect(health.isHealthy, true);
      });

      test('handles iOS state with is_moving key variant', () {
        final iosState = <String, Object?>{
          'enabled': true,
          'trackingMode': 0,
          'is_moving': true, // iOS may use snake_case
          'odometer': 500.0,
          'schedulerEnabled': false,
          'didLaunchInBackground': true,
        };
        final health = HealthCheck.fromMaps(
          state: iosState,
          provider: healthyProvider(),
          settingsHealth: healthySettingsHealth(),
          sensors: healthySensors(),
          deviceInfo: healthyDeviceInfo(),
          isPowerSave: false,
          ignoringBatteryOpt: true,
          locationPermissionStatus: 3,
          motionPermissionStatus: 3,
          dbCount: 0,
        );
        expect(health.isMoving, true);
        expect(health.didLaunchInBackground, true);
      });
    });

    // -----------------------------------------------------------------------
    // Edge cases
    // -----------------------------------------------------------------------
    group('edge cases', () {
      test('handles all-empty maps', () {
        final health = HealthCheck.fromMaps(
          state: <String, Object?>{},
          provider: <String, Object?>{},
          settingsHealth: <String, Object?>{},
          sensors: <String, Object?>{},
          deviceInfo: <String, Object?>{},
          isPowerSave: false,
          ignoringBatteryOpt: true,
          locationPermissionStatus: 0,
          motionPermissionStatus: 0,
          dbCount: 0,
        );
        expect(health.trackingEnabled, false);
        expect(health.locationPermission, AuthorizationStatus.notDetermined);
        expect(health.platform, '');
      });

      test('handles int-as-bool for iOS NSNumber coercion', () {
        final state = <String, Object?>{
          'enabled': 1, // NSNumber bool
          'trackingMode': 0,
          'isMoving': 0, // NSNumber false
          'odometer': 100,
        };
        final health = HealthCheck.fromMaps(
          state: state,
          provider: healthyProvider(),
          settingsHealth: healthySettingsHealth(),
          sensors: healthySensors(),
          deviceInfo: healthyDeviceInfo(),
          isPowerSave: false,
          ignoringBatteryOpt: true,
          locationPermissionStatus: 3,
          motionPermissionStatus: 3,
          dbCount: 0,
        );
        expect(health.trackingEnabled, true);
        expect(health.isMoving, false);
      });

      test('large location count', () {
        final health = HealthCheck.fromMaps(
          state: healthyState(),
          provider: healthyProvider(),
          settingsHealth: healthySettingsHealth(),
          sensors: healthySensors(),
          deviceInfo: healthyDeviceInfo(),
          isPowerSave: false,
          ignoringBatteryOpt: true,
          locationPermissionStatus: 3,
          motionPermissionStatus: 3,
          dbCount: 1000000,
        );
        expect(health.locationCount, 1000000);
      });
    });
  });
}
