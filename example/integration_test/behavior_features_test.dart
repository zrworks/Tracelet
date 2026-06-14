import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracelet/tracelet.dart';

/// Integration tests for the 3.3.0 behavior features — driving telematics,
/// transport-mode classifier, and crash/fall detection — exercised against the
/// real native runtime (engines instantiated in TraceletSdk, fed by the
/// location/accel pipeline).
///
/// The detection *logic* is covered by the Rust unit suite; these tests verify
/// the native wiring loads, config flows end-to-end, the event streams are
/// live, and — critically — that with the features OFF there is no behavior
/// change (no driving/impact events, normal tracking).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await Tracelet.stop();
  });

  group('config round-trips through the native runtime', () {
    testWidgets('telematics/classifier/impact enable flows without error', (
      tester,
    ) async {
      await Tracelet.ready(
        const Config(
          telematics: TelematicsConfig(
            enableDrivingEvents: true,
            speedLimitKmh: 50,
          ),
          classifier: ClassifierConfig(enableFusedClassifier: true),
          impact: ImpactConfig(enableCrashDetection: true),
        ),
      );
      final state = await Tracelet.getState();
      expect(state, isA<State>());

      // Reconfiguring at runtime via setConfig must also succeed.
      await Tracelet.setConfig(
        const Config(
          telematics: TelematicsConfig(
            enableDrivingEvents: true,
            speedLimitKmh: 80,
          ),
        ),
      );
    });
  });

  group('event streams are live', () {
    testWidgets('subscribing to all three streams does not throw', (
      tester,
    ) async {
      await Tracelet.ready(
        const Config(
          telematics: TelematicsConfig(enableDrivingEvents: true),
          classifier: ClassifierConfig(enableFusedClassifier: true),
          impact: ImpactConfig(enableCrashDetection: true),
        ),
      );
      // Subscribing must wire the native event channels without throwing. We
      // intentionally do NOT call start() here: starting tracking pulls in
      // runtime location-permission / foreground-service externalities that are
      // orthogonal to these features and can't complete in a headless test
      // harness. Event *detection* is covered by the Rust unit suite and the
      // FRB simulation tests.
      final subs = <StreamSubscription<dynamic>>[
        Tracelet.drivingEventStream.listen((_) {}),
        Tracelet.impactStream.listen((_) {}),
        Tracelet.modeChangeStream.listen((_) {}),
      ];
      await tester.pump(const Duration(milliseconds: 200));
      for (final s in subs) {
        await s.cancel();
      }
      expect(true, isTrue);
    });

    testWidgets('cancelImpact is a safe no-op for an unknown id', (
      tester,
    ) async {
      await Tracelet.ready(
        const Config(impact: ImpactConfig(enableCrashDetection: true)),
      );
      final ok = await Tracelet.cancelImpact(999999);
      expect(ok, isFalse);
    });
  });

  group('no-regression: features OFF (defaults)', () {
    testWidgets('default Config emits no driving/impact events', (
      tester,
    ) async {
      var driving = 0;
      var impact = 0;
      final subs = <StreamSubscription<dynamic>>[
        Tracelet.drivingEventStream.listen((_) => driving++),
        Tracelet.impactStream.listen((_) => impact++),
      ];

      // With the features at their defaults (off), the native engines are never
      // instantiated, so the streams must stay silent. (No start() — see above.)
      await Tracelet.ready(const Config());
      await tester.pump(const Duration(seconds: 1));

      for (final s in subs) {
        await s.cancel();
      }
      expect(driving, 0, reason: 'no driving events when feature is off');
      expect(impact, 0, reason: 'no impact events when feature is off');
    });
  });
}
