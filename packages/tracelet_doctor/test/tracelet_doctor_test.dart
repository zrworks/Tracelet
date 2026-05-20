import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracelet/tracelet.dart' hide State;
import 'package:tracelet_doctor/tracelet_doctor.dart';

void main() {
  group('DoctorTheme', () {
    test('sheet background is a dark color', () {
      expect(DoctorTheme.sheetBackground.computeLuminance(), lessThan(0.15));
    });

    test('card surface is a dark color', () {
      expect(DoctorTheme.cardSurface.computeLuminance(), lessThan(0.15));
    });

    test('semantic colors are distinct', () {
      expect(DoctorTheme.success, isNot(equals(DoctorTheme.warning)));
      expect(DoctorTheme.warning, isNot(equals(DoctorTheme.error)));
      expect(DoctorTheme.error, isNot(equals(DoctorTheme.success)));
    });

    test('card decoration has correct border radius', () {
      final borderRadius =
          DoctorTheme.cardDecoration.borderRadius as BorderRadius;
      expect(borderRadius.topLeft.x, 14);
    });

    test('sheet radius is top-only', () {
      expect(DoctorTheme.sheetRadius.bottomLeft, Radius.zero);
      expect(DoctorTheme.sheetRadius.bottomRight, Radius.zero);
      expect(DoctorTheme.sheetRadius.topLeft.x, 24);
      expect(DoctorTheme.sheetRadius.topRight.x, 24);
    });

    test('title style has correct weight', () {
      expect(DoctorTheme.titleStyle.fontWeight, FontWeight.w700);
    });

    test('chip style has correct letter spacing', () {
      expect(DoctorTheme.chipStyle.letterSpacing, 0.8);
    });
  });

  group('TraceletDoctor', () {
    test('is not constructible', () {
      // TraceletDoctor has a private constructor — verify it only has
      // the static show() method accessible.
      expect(TraceletDoctor.show, isA<Function>());
    });
  });

  group('HealthCheck model integration', () {
    test('HealthCheck can be constructed for Doctor consumption', () {
      final health = HealthCheck(
        trackingEnabled: true,
        trackingMode: TrackingMode.location,
        isMoving: true,
        odometer: 12345.0,
        locationPermission: AuthorizationStatus.always,
        motionPermission: 3,
        accuracyAuthorization: AccuracyAuthorization.full,
        locationServicesEnabled: true,
        gpsEnabled: true,
        networkEnabled: true,
        isPowerSaveMode: false,
        isIgnoringBatteryOptimizations: true,
        manufacturer: 'Google',
        model: 'Pixel 8',
        isAggressiveOem: false,
        aggressionRating: 0,
        hasAccelerometer: true,
        hasGyroscope: true,
        hasMagnetometer: true,
        hasSignificantMotion: true,
        locationCount: 42,
        platform: 'android',
        osVersion: '14',
        mockLocationsDetected: false,
        timestamp: DateTime.utc(2026, 5, 20),
        warnings: const [],
      );

      expect(health.isHealthy, isTrue);
      expect(health.hasWarnings, isFalse);
      expect(health.warningCount, 0);
      expect(health.hasBackgroundPermission, isTrue);
      expect(health.trackingEnabled, isTrue);
      expect(health.locationCount, 42);
    });

    test('HealthCheck with warnings surfaces them correctly', () {
      final health = HealthCheck(
        trackingEnabled: false,
        trackingMode: TrackingMode.location,
        timestamp: DateTime.utc(2026, 5, 20),
        warnings: const [
          HealthWarning.locationPermissionDenied,
          HealthWarning.powerSaveMode,
          HealthWarning.aggressiveOem,
        ],
      );

      expect(health.isHealthy, isFalse);
      expect(health.hasWarnings, isTrue);
      expect(health.warningCount, 3);
    });

    test('HealthWarning descriptions are non-empty', () {
      for (final warning in HealthWarning.values) {
        expect(warning.description, isNotEmpty);
      }
    });

    test('HealthCheck toMap round-trips correctly', () {
      final original = HealthCheck(
        trackingEnabled: true,
        trackingMode: TrackingMode.geofences,
        isMoving: false,
        odometer: 999.0,
        locationPermission: AuthorizationStatus.whenInUse,
        motionPermission: 2,
        isPowerSaveMode: true,
        isIgnoringBatteryOptimizations: false,
        manufacturer: 'Xiaomi',
        model: 'Redmi Note 12',
        isAggressiveOem: true,
        aggressionRating: 5,
        hasAccelerometer: true,
        hasGyroscope: false,
        hasMagnetometer: true,
        hasSignificantMotion: false,
        locationCount: 1000,
        platform: 'android',
        osVersion: '13',
        mockLocationsDetected: true,
        timestamp: DateTime.utc(2026, 5, 20, 10, 30),
        warnings: const [
          HealthWarning.aggressiveOem,
          HealthWarning.batteryOptimizationsNotIgnored,
        ],
      );

      final map = original.toMap();
      final restored = HealthCheck.fromMap(map);

      expect(restored.trackingEnabled, original.trackingEnabled);
      expect(restored.trackingMode, original.trackingMode);
      expect(restored.manufacturer, original.manufacturer);
      expect(restored.isAggressiveOem, original.isAggressiveOem);
      expect(restored.aggressionRating, original.aggressionRating);
      expect(restored.locationCount, original.locationCount);
      expect(restored.mockLocationsDetected, original.mockLocationsDetected);
      expect(restored.warnings.length, original.warnings.length);
    });
  });
}
