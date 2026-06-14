import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracelet/tracelet.dart';

/// Integration tests for the 3.3.0 behavior features — driving telematics,
/// transport-mode classifier, and crash/fall detection — against the real
/// native runtime.
///
/// The detection *logic* is covered by the Rust unit suite and the on-device
/// FRB simulation tests (behavior_simulation_test.dart). These tests verify the
/// native wiring loads, config flows end-to-end, the event streams are live,
/// and — with the features ON but no movement — that no spurious events fire.
///
/// We `ready()` ONCE in setUpAll and never call start(): starting tracking pulls
/// in runtime location-permission / foreground-service externalities that can't
/// complete in a headless test harness, and repeatedly cycling ready()/stop()
/// per test is flaky on real devices.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
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
  });

  testWidgets('config round-trips through the native runtime', (tester) async {
    final state = await Tracelet.getState();
    expect(state, isA<State>());

    // Reconfiguring at runtime must also succeed.
    await Tracelet.setConfig(
      const Config(
        telematics: TelematicsConfig(
          enableDrivingEvents: true,
          speedLimitKmh: 80,
        ),
      ),
    );
  });

  testWidgets('all three event streams subscribe without throwing', (
    tester,
  ) async {
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

  testWidgets('cancelImpact is a safe no-op for an unknown id', (tester) async {
    final ok = await Tracelet.cancelImpact(999999);
    expect(ok, isFalse);
  });

  testWidgets('no spurious driving/impact events without movement', (
    tester,
  ) async {
    var driving = 0;
    var impact = 0;
    final subs = <StreamSubscription<dynamic>>[
      Tracelet.drivingEventStream.listen((_) => driving++),
      Tracelet.impactStream.listen((_) => impact++),
    ];
    await tester.pump(const Duration(seconds: 1));
    for (final s in subs) {
      await s.cancel();
    }
    expect(driving, 0);
    expect(impact, 0);
  });
}
