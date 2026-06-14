import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracelet/tracelet.dart';
// FRB engine handles — let us drive the *real* Rust detection logic with
// synthetic input on-device, simulating driving/crash/transport conditions
// without actually moving. App/test code may use the internal FRB bindings.
// ignore_for_file: implementation_imports
import 'package:tracelet_platform_interface/src/rust/api_dart/telematics.dart';
import 'package:tracelet_platform_interface/src/rust/api_dart/impact.dart';
import 'package:tracelet_platform_interface/src/rust/api_dart/transport_mode.dart';
import 'package:tracelet_platform_interface/src/rust/algorithms/impact.dart'
    as frb
    show ImpactConfig;
import 'package:tracelet_platform_interface/src/rust/algorithms/transport_mode.dart'
    show TransportMode;
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

/// On-device simulation of the 3.3.0 behavior engines.
///
/// These feed synthetic fixes/impacts/accelerometer windows into the real Rust
/// engines (via flutter_rust_bridge) and assert the detected events — proving
/// the detection logic works on the device without needing to actually drive,
/// crash, or walk.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Initializes the Rust library used by the FRB engine handles.
    await Tracelet.ready(const Config());
  });

  testWidgets('simulate harsh braking', (tester) async {
    final engine = TelematicsEngineDart();
    // 20 m/s → 5 m/s in 1 s ≈ -1.5 g.
    engine.processFix(
      speed: 20,
      heading: 90,
      latitude: 0,
      longitude: 0,
      timestampMs: PlatformInt64Util.from(0),
    );
    final events = engine.processFix(
      speed: 5,
      heading: 90,
      latitude: 0,
      longitude: 0,
      timestampMs: PlatformInt64Util.from(1000),
    );
    expect(events.any((e) => e.kind == 'harsh_braking'), isTrue);
  });

  testWidgets('simulate harsh acceleration', (tester) async {
    final engine = TelematicsEngineDart();
    engine.processFix(
      speed: 5,
      heading: 90,
      latitude: 0,
      longitude: 0,
      timestampMs: PlatformInt64Util.from(0),
    );
    final events = engine.processFix(
      speed: 14,
      heading: 90,
      latitude: 0,
      longitude: 0,
      timestampMs: PlatformInt64Util.from(1000),
    );
    expect(events.any((e) => e.kind == 'harsh_acceleration'), isTrue);
  });

  testWidgets('simulate crash candidate then auto-confirm', (tester) async {
    final detector = ImpactDetectorDart(
      config: frb.ImpactConfig(
        enableCrash: true,
        enableFall: false,
        crashGThreshold: 3,
        crashMinSpeedKmh: 25,
        fallGThreshold: 2.5,
        confirmWindowMs: PlatformInt64Util.from(15000),
        minConfidence: 0.6,
      ),
    );
    // 5 g spike while moving 60 km/h → potential_crash.
    final candidate = detector.onImpactWindow(
      peakG: 5,
      speedBeforeMps: 60 / 3.6,
      isOnFoot: false,
      latitude: 0,
      longitude: 0,
      nowMs: PlatformInt64Util.from(0),
    );
    expect(candidate, isNotNull);
    expect(candidate!.kind, 'potential_crash');

    // Not cancelled before the deadline → confirmed crash.
    final confirmed = detector.checkConfirmations(
      nowMs: PlatformInt64Util.from(20000),
    );
    expect(confirmed.length, 1);
    expect(confirmed.first.kind, 'crash');
  });

  testWidgets('simulate crash cancelled within window', (tester) async {
    final detector = ImpactDetectorDart(
      config: frb.ImpactConfig(
        enableCrash: true,
        enableFall: false,
        crashGThreshold: 3,
        crashMinSpeedKmh: 25,
        fallGThreshold: 2.5,
        confirmWindowMs: PlatformInt64Util.from(15000),
        minConfidence: 0.6,
      ),
    );
    final candidate = detector.onImpactWindow(
      peakG: 6,
      speedBeforeMps: 70 / 3.6,
      isOnFoot: false,
      latitude: 0,
      longitude: 0,
      nowMs: PlatformInt64Util.from(0),
    )!;
    expect(detector.cancel(id: candidate.id), isTrue);
    expect(
      detector.checkConfirmations(nowMs: PlatformInt64Util.from(60000)),
      isEmpty,
    );
  });

  testWidgets('simulate vehicle transport mode', (tester) async {
    final classifier = TransportModeClassifierDart();
    final steady = List<double>.filled(10, 0.05); // low-variance accel
    // 60 km/h, sustained past the dwell window → commits to vehicle.
    classifier.classifySamples(
      magnitudesG: steady,
      durationMs: PlatformInt64Util.from(1000),
      speedMps: 60 / 3.6,
      nowMs: PlatformInt64Util.from(0),
    );
    final result = classifier.classifySamples(
      magnitudesG: steady,
      durationMs: PlatformInt64Util.from(1000),
      speedMps: 60 / 3.6,
      nowMs: PlatformInt64Util.from(9000),
    );
    expect(result.mode, TransportMode.vehicle);
  });
}
