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
        Config.fromMap(const {
          'geo': {
            'desiredAccuracy': 2, // low
            'distanceFilter': 15.5,
            'stationaryRadius': 28.0,
            'locationTimeout': 45,
            'disableElasticity': true,
            'elasticityMultiplier': 2.0,
            'stopAfterElapsedMinutes': 15,
            'maxMonitoredGeofences': 50,
            'enableTimestampMeta': true,
            'enableAdaptiveMode': true,
            'periodicLocationInterval': 60,
            'periodicDesiredAccuracy': 0, // high
            'enableSparseUpdates': true,
            'sparseDistanceThreshold': 75.0,
            'sparseMaxIdleSeconds': 600,
            'batteryBudgetPerHour': 2.5,
            'enableDeadReckoning': true,
            'deadReckoningActivationDelay': 5,
            'deadReckoningMaxDuration': 60,
            'filter': {
              'trackingAccuracyThreshold': 80,
              'maxImpliedSpeed': 90,
              'odometerAccuracyThreshold': 40,
              'policy': 1, // ignore
              'rejectMockLocations': true,
              'mockDetectionLevel': 2,
              'useKalmanFilter': true,
            },
            'resolveAddress': true,
          },
          'motion': {
            'stopTimeout': 10,
            'motionTriggerDelay': 200,
            'disableMotionActivityUpdates': true,
            'activityRecognitionInterval': 20000,
            'minimumActivityRecognitionConfidence': 80,
            'disableStopDetection': true,
            'stopDetectionDelay': 5,
            'stopOnStationary': true,
            'activityTypes': [2, 1], // fitness, automotiveNavigation
            'stationaryRadius': 30.0,
            'useSignificantChangesOnly': true,
            'shakeThreshold': 3.5,
            'stillThreshold': 1.5,
            'stillSampleCount': 10,
            'motionDetectionMode': 2, // smart
            'speedMovingThreshold': 2.0,
            'speedStationaryDelay': 120,
            'stationaryTrackingMode': 1, // geofences
            'stationaryPeriodicInterval': 300,
            'stationaryPeriodicAccuracy': 1, // medium
            'speedWakeConfirmCount': 2,
          },
          'app': {
            'stopOnTerminate': false,
            'startOnBoot': true,
            'heartbeatInterval': 120,
            'remoteConfigTimeout': 30000,
            'remoteConfigRefreshInterval': 720,
            'remoteConfigUrl': 'https://example.com/config',
            'remoteConfigHeaders': {'Authorization': 'Bearer test'},
            'schedule': ['0 8 * * 1-5', '0 17 * * 1-5'],
          },
          'android': {
            'locationUpdateInterval': 2000,
            'fastestLocationUpdateInterval': 1000,
            'deferTime': 5000,
            'allowIdenticalLocations': true,
            'geofenceModeHighAccuracy': true,
            'periodicUseForegroundService': true,
            'periodicUseExactAlarms': true,
            'scheduleUseAlarmManager': true,
            'foregroundService': {
              'enabled': true,
              'channelId': 'custom_channel',
              'channelName': 'Custom Tracelet',
              'notificationTitle': 'Custom Title',
              'notificationText': 'Custom Text',
              'notificationColor': '#FF0000',
              'notificationSmallIcon': 'ic_custom',
              'notificationLargeIcon': 'ic_custom_large',
              'notificationPriority': 3, // high
              'notificationOngoing': false,
              'showNotificationOnPauseOnly': true,
              'actions': ['Pause', 'Sync'],
            },
          },
          'ios': {
            'activityType': 2, // fitness
            'useSignificantChangesOnly': true,
            'showsBackgroundLocationIndicator': true,
            'pausesLocationUpdatesAutomatically': true,
            'locationAuthorizationRequest': 'WhenInUse',
            'disableLocationAuthorizationAlert': true,
            'preventSuspend': true,
          },
          'http': {
            'url': 'https://example.com/sync',
            'method': 1, // put
            'headers': {'X-Tracelet': 'test'},
            'params': {'user_id': 123},
            'extras': {'session': 'abc'},
            'httpRootProperty': 'locations',
            'autoSync': false,
            'batchSync': true,
            'maxBatchSize': 100,
            'autoSyncThreshold': 10,
            'autoSyncDelay': 5000,
            'httpTimeout': 30000,
            'locationsOrderDirection': 1, // descending
            'disableAutoSyncOnCellular': true,
            'maxRetries': 5,
            'retryBackoffBase': 2000,
            'retryBackoffCap': 30000,
            'enableDeltaCompression': true,
            'deltaCoordinatePrecision': 6,
            'sslPinningFingerprints': ['sha256/123456'],
            'sslPinningCertificates': ['base64cert'],
          },
          'logger': {
            'logLevel': 3, // debug
            'logMaxDays': 5,
            'debug': true,
          },
          'geofence': {
            'radius': 100.0,
            'notifyOnEntry': true,
            'notifyOnExit': true,
            'notifyOnDwell': true,
            'loiteringDelay': 30000,
          },
          'persistence': {'maxDaysToRetain': 10, 'maxRecordsToRetain': 10000},
          'audit': {
            'enableAuditTrail': true,
            'enableSignatureValidation': true,
            'maxAuditRecords': 5000,
          },
          'privacyZone': {'enablePrivacyZones': true},
          'security': {
            'enableEncryption': true,
            'encryptionAlgorithm': 'AES256',
          },
          'attestation': {'enableAttestation': true},
        }),
      );
    } catch (e) {
      fail('Tracelet.ready() crashed during config synchronization: $e');
    }

    // Clean up
    await Tracelet.stop();
  });
}
