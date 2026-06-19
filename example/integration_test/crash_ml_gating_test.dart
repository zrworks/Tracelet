import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// On-device verification of #183 Phase 3 — ML crash gating (Replace mode).
///
/// Drives the real Rust `ImpactDetector.onImpactWindow` on the device via the
/// `com.tracelet/debug` → `debugImpactGate` hook, supplying a crash probability
/// directly (as the loaded model would produce) so the gating logic is proven
/// end-to-end through the rebuilt UniFFI bindings — without needing the 13 MB
/// model or an actual collision.
///
/// `crashProba < 0` selects the rule engine; `crashProba >= 0` activates Replace
/// mode (the probability decides, still speed-gated).
///
/// Run: `flutter test integration_test/crash_ml_gating_test.dart -d <android>`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const debug = MethodChannel('com.tracelet/debug');
  const movingMps = 60 / 3.6; // 60 km/h — above the 25 km/h crash speed gate.

  Future<Map<String, Object?>> gate({
    required double peakG,
    required double speedMps,
    required double crashProba,
    double threshold = 0.5,
  }) async {
    final res = await debug
        .invokeMapMethod<String, Object?>('debugImpactGate', {
          'peakG': peakG,
          'speedMps': speedMps,
          'crashProba': crashProba,
          'threshold': threshold,
        });
    expect(res, isNotNull);
    return res!;
  }

  test('ML rescues a sub-g-threshold crash (proba >= threshold)', () async {
    // 1.0 g is far below the 2.0 g rule, but the model says crash (0.8 >= 0.5)
    // and the device is moving ⇒ Replace mode fires.
    final r = await gate(peakG: 1, speedMps: movingMps, crashProba: 0.8);
    expect(r['fired'], isTrue);
    expect(r['kind'], 'potential_crash');
    expect(r['confidence']! as double, closeTo(0.8, 1e-9));
  });

  test('ML suppresses a high-g event below probability', () async {
    // A 6 g spike at speed WOULD fire the rule, but the model says not a crash
    // (0.2 < 0.5) ⇒ Replace mode suppresses it.
    final r = await gate(peakG: 6, speedMps: movingMps, crashProba: 0.2);
    expect(r['fired'], isFalse);
  });

  test('ML gate is still speed-gated', () async {
    // High probability but stationary ⇒ no crash (speed gate still applies).
    final r = await gate(peakG: 1, speedMps: 0, crashProba: 0.99);
    expect(r['fired'], isFalse);
  });

  test('no model (proba < 0) falls back to the g-threshold rule', () async {
    // crashProba = -1 ⇒ rule engine: 1.0 g is below 2.0 g ⇒ no crash...
    final weak = await gate(peakG: 1, speedMps: movingMps, crashProba: -1);
    expect(weak['fired'], isFalse);
    // ...but a real 4.0 g jolt at speed ⇒ the rule fires.
    final strong = await gate(peakG: 4, speedMps: movingMps, crashProba: -1);
    expect(strong['fired'], isTrue);
    expect(strong['kind'], 'potential_crash');
  });
}
