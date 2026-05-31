import 'package:flutter_test/flutter_test.dart';
import 'package:tracelet_platform_interface/tracelet_platform_interface.dart';

import 'package:tracelet_platform_interface/src/rust/frb_generated.dart';

void main() async {
  await RustLib.init();
  group('AdaptiveSamplingEngine', () {
    // ─────────────────────────────────────────────────────────────────────
    // Activity-based profiles
    // ─────────────────────────────────────────────────────────────────────

    group('activity profiles', () {
      test('still activity uses 500m distance', () {
        const engine = AdaptiveSamplingEngine(baseDistanceFilter: 10);
        final result = engine.compute(
          const AdaptiveContext(
            activityType: ActivityType.still,
            activityConfidence: ActivityConfidence.high,
            batteryLevel: 0.80,
          ),
        );

        expect(result.effectiveDistanceFilter, 500.0);
        expect(result.source, AdaptiveSource.activity);
        expect(result.activityFactor, 50.0); // 500 / 10
      });

      test('walking activity uses 50m distance', () {
        const engine = AdaptiveSamplingEngine(baseDistanceFilter: 10);
        final result = engine.compute(
          const AdaptiveContext(
            activityType: ActivityType.walking,
            activityConfidence: ActivityConfidence.medium,
            batteryLevel: 0.80,
          ),
        );

        expect(result.effectiveDistanceFilter, 50.0);
        expect(result.source, AdaptiveSource.activity);
      });

      test('onFoot activity uses 50m distance', () {
        const engine = AdaptiveSamplingEngine(baseDistanceFilter: 10);
        final result = engine.compute(
          const AdaptiveContext(
            activityType: ActivityType.onFoot,
            activityConfidence: ActivityConfidence.high,
            batteryLevel: 0.80,
          ),
        );

        expect(result.effectiveDistanceFilter, 50.0);
      });

      test('running activity uses 30m distance', () {
        const engine = AdaptiveSamplingEngine(baseDistanceFilter: 10);
        final result = engine.compute(
          const AdaptiveContext(
            activityType: ActivityType.running,
            activityConfidence: ActivityConfidence.high,
            batteryLevel: 0.80,
          ),
        );

        expect(result.effectiveDistanceFilter, 30.0);
      });

      test('onBicycle activity uses 25m distance', () {
        const engine = AdaptiveSamplingEngine(baseDistanceFilter: 10);
        final result = engine.compute(
          const AdaptiveContext(
            activityType: ActivityType.onBicycle,
            activityConfidence: ActivityConfidence.high,
            batteryLevel: 0.80,
          ),
        );

        expect(result.effectiveDistanceFilter, 25.0);
      });

      test('inVehicle activity uses 10m distance', () {
        const engine = AdaptiveSamplingEngine(baseDistanceFilter: 10);
        final result = engine.compute(
          const AdaptiveContext(
            activityType: ActivityType.inVehicle,
            activityConfidence: ActivityConfidence.high,
            batteryLevel: 0.80,
          ),
        );

        expect(result.effectiveDistanceFilter, 10.0);
      });

      test('low confidence activity falls back to speed-based', () {
        const engine = AdaptiveSamplingEngine(baseDistanceFilter: 10);
        final result = engine.compute(
          const AdaptiveContext(
            activityType: ActivityType.walking,
            batteryLevel: 0.80,
            speed: 20,
          ),
        );

        // Should not use activity profile, should use speed.
        expect(result.source, AdaptiveSource.speed);
        expect(result.activityFactor, 1.0);
      });

      test('unknown activity with speed uses speed-based fallback', () {
        const engine = AdaptiveSamplingEngine(baseDistanceFilter: 10);
        final result = engine.compute(
          const AdaptiveContext(
            activityConfidence: ActivityConfidence.high,
            batteryLevel: 0.80,
            speed: 30,
          ),
        );

        expect(result.source, AdaptiveSource.speed);
        // speed=30m/s → speedFactor = clamp(30/10, 1, 10) = 3.0
        expect(result.speedFactor, 3.0);
        expect(result.effectiveDistanceFilter, 30.0); // 10 × 3.0
      });

      test('unknown activity without speed uses static', () {
        const engine = AdaptiveSamplingEngine(baseDistanceFilter: 10);
        final result = engine.compute(
          const AdaptiveContext(
            activityConfidence: ActivityConfidence.high,
            batteryLevel: 0.80,
          ),
        );

        expect(result.source, AdaptiveSource.static_);
        expect(result.effectiveDistanceFilter, 10.0);
      });
    });

    // ─────────────────────────────────────────────────────────────────────
    // Battery scaling
    // ─────────────────────────────────────────────────────────────────────

    group('battery scaling', () {
      test('battery above 50% has no scaling', () {
        const engine = AdaptiveSamplingEngine(baseDistanceFilter: 10);
        final result = engine.compute(
          const AdaptiveContext(
            activityType: ActivityType.walking,
            activityConfidence: ActivityConfidence.high,
            batteryLevel: 0.75,
          ),
        );

        expect(result.batteryFactor, 1.0);
        expect(result.effectiveDistanceFilter, 50.0);
      });

      test('battery 20-50% applies 1.5x factor', () {
        const engine = AdaptiveSamplingEngine(baseDistanceFilter: 10);
        final result = engine.compute(
          const AdaptiveContext(
            activityType: ActivityType.walking,
            activityConfidence: ActivityConfidence.high,
            batteryLevel: 0.35,
          ),
        );

        expect(result.batteryFactor, 1.5);
        expect(result.effectiveDistanceFilter, 75.0); // 50 × 1.5
      });

      test('battery 10-20% applies 2.5x factor', () {
        const engine = AdaptiveSamplingEngine(baseDistanceFilter: 10);
        final result = engine.compute(
          const AdaptiveContext(
            activityType: ActivityType.inVehicle,
            activityConfidence: ActivityConfidence.high,
            batteryLevel: 0.15,
          ),
        );

        expect(result.batteryFactor, 2.5);
        expect(result.effectiveDistanceFilter, 25.0); // 10 × 2.5
      });

      test('battery below 10% applies 5x factor', () {
        const engine = AdaptiveSamplingEngine(baseDistanceFilter: 10);
        final result = engine.compute(
          const AdaptiveContext(
            activityType: ActivityType.inVehicle,
            activityConfidence: ActivityConfidence.high,
            batteryLevel: 0.05,
          ),
        );

        expect(result.batteryFactor, 5.0);
        expect(result.effectiveDistanceFilter, 50.0); // 10 × 5.0
      });

      test('charging disables battery scaling', () {
        const engine = AdaptiveSamplingEngine(baseDistanceFilter: 10);
        final result = engine.compute(
          const AdaptiveContext(
            activityType: ActivityType.walking,
            activityConfidence: ActivityConfidence.high,
            batteryLevel: 0.05,
            isCharging: true,
          ),
        );

        expect(result.batteryFactor, 1.0);
        expect(result.effectiveDistanceFilter, 50.0); // No battery penalty
      });

      test('unknown battery level (-1) disables scaling', () {
        const engine = AdaptiveSamplingEngine(baseDistanceFilter: 10);
        final result = engine.compute(
          const AdaptiveContext(
            activityType: ActivityType.walking,
            activityConfidence: ActivityConfidence.high,
          ),
        );

        expect(result.batteryFactor, 1.0);
      });

      test('battery at exact threshold boundaries', () {
        const engine = AdaptiveSamplingEngine(baseDistanceFilter: 10);

        // Exactly 50%
        var result = engine.compute(
          const AdaptiveContext(
            activityType: ActivityType.inVehicle,
            activityConfidence: ActivityConfidence.high,
            batteryLevel: 0.50,
          ),
        );
        expect(result.batteryFactor, 1.0);

        // Exactly 20%
        result = engine.compute(
          const AdaptiveContext(
            activityType: ActivityType.inVehicle,
            activityConfidence: ActivityConfidence.high,
            batteryLevel: 0.20,
          ),
        );
        expect(result.batteryFactor, 1.5);

        // Exactly 10%
        result = engine.compute(
          const AdaptiveContext(
            activityType: ActivityType.inVehicle,
            activityConfidence: ActivityConfidence.high,
            batteryLevel: 0.10,
          ),
        );
        expect(result.batteryFactor, 2.5);
      });
    });

    // ─────────────────────────────────────────────────────────────────────
    // Speed-based fallback
    // ─────────────────────────────────────────────────────────────────────

    group('speed-based fallback', () {
      test('speed factor is clamped between 1 and 10', () {
        const engine = AdaptiveSamplingEngine(baseDistanceFilter: 10);

        // Very low speed — clamped to 1.0
        var result = engine.compute(
          const AdaptiveContext(batteryLevel: 0.80, speed: 2),
        );
        expect(result.speedFactor, 1.0);

        // Very high speed — clamped to 10.0
        result = engine.compute(
          const AdaptiveContext(batteryLevel: 0.80, speed: 200),
        );
        expect(result.speedFactor, 10.0);
      });

      test('elasticityMultiplier is applied to speed factor', () {
        const engine = AdaptiveSamplingEngine(
          baseDistanceFilter: 10,
          elasticityMultiplier: 2,
        );
        final result = engine.compute(
          const AdaptiveContext(batteryLevel: 0.80, speed: 20),
        );

        // speedFactor = clamp(20/10, 1, 10) * 2.0 = 2.0 * 2.0 = 4.0
        expect(result.speedFactor, 4.0);
        expect(result.effectiveDistanceFilter, 40.0);
      });

      test('very small elasticityMultiplier is clamped to 0.1', () {
        const engine = AdaptiveSamplingEngine(
          baseDistanceFilter: 10,
          elasticityMultiplier: 0.01,
        );
        final result = engine.compute(
          const AdaptiveContext(batteryLevel: 0.80, speed: 10),
        );

        // speedFactor = clamp(10/10, 1, 10) * 0.1 = 0.1
        expect(result.speedFactor, closeTo(0.1, 0.001));
      });
    });

    // ─────────────────────────────────────────────────────────────────────
    // Combined factors
    // ─────────────────────────────────────────────────────────────────────

    group('combined factors', () {
      test('activity + battery scaling works together', () {
        const engine = AdaptiveSamplingEngine(baseDistanceFilter: 10);
        final result = engine.compute(
          const AdaptiveContext(
            activityType: ActivityType.running,
            activityConfidence: ActivityConfidence.high,
            batteryLevel: 0.05, // Critical
          ),
        );

        // running = 30m profile, battery 5% = 5.0x
        // effective = 10.0 * (30.0/10.0) * 5.0 = 150.0
        expect(result.effectiveDistanceFilter, 150.0);
        expect(result.source, AdaptiveSource.activity);
      });

      test('speed fallback + battery scaling works together', () {
        const engine = AdaptiveSamplingEngine(baseDistanceFilter: 10);
        final result = engine.compute(
          const AdaptiveContext(
            batteryLevel: 0.35, // 1.5x
            speed: 30,
          ),
        );

        // speed=30 → factor=3.0, battery 35% → 1.5x
        // effective = 10 × 3.0 × 1.5 = 45.0
        expect(result.effectiveDistanceFilter, 45.0);
      });
    });

    // ─────────────────────────────────────────────────────────────────────
    // Base distance filter variations
    // ─────────────────────────────────────────────────────────────────────

    group('base distance filter', () {
      test('respects custom base distance filter', () {
        const engine = AdaptiveSamplingEngine(baseDistanceFilter: 25);
        final result = engine.compute(
          const AdaptiveContext(
            activityType: ActivityType.walking,
            activityConfidence: ActivityConfidence.high,
            batteryLevel: 0.80,
          ),
        );

        // Walking profile = 50m → factor = 50/25 = 2.0
        // effective = 25 × 2.0 = 50.0 (activity profiles are absolute)
        expect(result.effectiveDistanceFilter, 50.0);
      });

      test('static result returns base when no factors apply', () {
        const engine = AdaptiveSamplingEngine(baseDistanceFilter: 42);
        final result = engine.compute(
          const AdaptiveContext(batteryLevel: 0.80),
        );

        expect(result.effectiveDistanceFilter, 42.0);
        expect(result.source, AdaptiveSource.static_);
      });
    });

    // ─────────────────────────────────────────────────────────────────────
    // AdaptiveSamplingResult
    // ─────────────────────────────────────────────────────────────────────

    test('result toString contains useful info', () {
      const engine = AdaptiveSamplingEngine(baseDistanceFilter: 10);
      final result = engine.compute(
        const AdaptiveContext(
          activityType: ActivityType.walking,
          activityConfidence: ActivityConfidence.high,
          batteryLevel: 0.80,
        ),
      );

      expect(result.toString(), contains('effective='));
      expect(result.toString(), contains('base='));
      expect(result.toString(), contains('activity'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // AdaptiveContext
  // ═══════════════════════════════════════════════════════════════════════

  group('AdaptiveContext', () {
    test('default values', () {
      const ctx = AdaptiveContext();
      expect(ctx.batteryLevel, -1.0);
      expect(ctx.isCharging, isFalse);
      expect(ctx.activityType, ActivityType.unknown);
      expect(ctx.activityConfidence, ActivityConfidence.low);
      expect(ctx.speed, 0);
    });

    test('toString is readable', () {
      const ctx = AdaptiveContext(
        batteryLevel: 0.42,
        activityType: ActivityType.walking,
      );
      expect(ctx.toString(), contains('battery=0.42'));
      expect(ctx.toString(), contains('walking'));
    });
  });
}
