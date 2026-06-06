import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracelet/tracelet.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Rust Config Parity and Initialization Test', (tester) async {
    // 1. Verify Rust Parity via Debug MethodChannel (Android only, but safe to call)
    const channel = MethodChannel('com.tracelet/debug');
    try {
      final result = await channel.invokeMapMethod<String, dynamic>(
        'debugVerifyRustParity',
      );
      if (result != null) {
        final missingGeo = List<String>.from(
          (result['missingGeo'] as Iterable<dynamic>?) ?? [],
        );
        final missingMotion = List<String>.from(
          (result['missingMotion'] as Iterable<dynamic>?) ?? [],
        );

        expect(
          missingGeo,
          isEmpty,
          reason: 'Missing GeoConfig properties in Rust: $missingGeo',
        );
        expect(
          missingMotion,
          isEmpty,
          reason: 'Missing MotionConfig properties in Rust: $missingMotion',
        );
      }
    } on MissingPluginException {
      // iOS might not have this method channel implemented, which is fine.
      // ignore: avoid_print
      print(
        'Skipping reflection parity test on iOS (Method channel not implemented)',
      );
    } catch (e) {
      fail('Failed to verify rust parity: $e');
    }

    // 2. Initialize Tracelet with a complex config to ensure syncConfigToRustFlat doesn't crash
    try {
      await Tracelet.ready(
        const Config(
          geo: GeoConfig(
            desiredAccuracy: DesiredAccuracy.low,
            distanceFilter: 15.5,
            stationaryRadius: 28,
            locationTimeout: 45,
            disableElasticity: true,
            elasticityMultiplier: 2,
            stopAfterElapsedMinutes: 15,
            maxMonitoredGeofences: 50,
            enableTimestampMeta: true,
            enableAdaptiveMode: true,
            periodicLocationInterval: 60,
            periodicDesiredAccuracy: DesiredAccuracy.high,
            enableSparseUpdates: true,
            sparseDistanceThreshold: 75,
            sparseMaxIdleSeconds: 600,
            batteryBudgetPerHour: 2.5,
            enableDeadReckoning: true,
            deadReckoningActivationDelay: 5,
            deadReckoningMaxDuration: 60,
            filter: LocationFilter(
              trackingAccuracyThreshold: 80,
              maxImpliedSpeed: 90,
              odometerAccuracyThreshold: 40,
              policy: LocationFilterPolicy.ignore,
              rejectMockLocations: true,
              mockDetectionLevel: 2,
              useKalmanFilter: true,
            ),
            resolveAddress: true,
          ),
          motion: MotionConfig(
            stopTimeout: 10,
            motionTriggerDelay: 200,
            disableMotionActivityUpdates: true,
            activityRecognitionInterval: 20000,
            minimumActivityRecognitionConfidence: 80,
            disableStopDetection: true,
            stopDetectionDelay: 5,
            stopOnStationary: true,
            activityTypes: [
              LocationActivityType.fitness,
              LocationActivityType.automotiveNavigation,
            ],
            stationaryRadius: 30,
            useSignificantChangesOnly: true,
            shakeThreshold: 3.5,
            stillThreshold: 1.5,
            stillSampleCount: 10,
            motionDetectionMode: MotionDetectionMode.smart,
            speedMovingThreshold: 2,
            speedStationaryDelay: 120,
            stationaryTrackingMode: StationaryTrackingMode.geofences,
            stationaryPeriodicInterval: 300,
            stationaryPeriodicAccuracy: DesiredAccuracy.medium,
            speedWakeConfirmCount: 2,
          ),
        ),
      );
    } catch (e) {
      fail('Tracelet.ready() crashed during config synchronization: $e');
    }

    // Clean up
    await Tracelet.stop();
  });
}
