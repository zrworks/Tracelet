import 'package:flutter_test/flutter_test.dart';
import 'package:tracelet/tracelet.dart';
import 'package:tracelet_platform_interface/tracelet_platform_interface.dart';

void main() {
  test('DrivingEvent.fromTl maps all fields', () {
    final e = DrivingEvent.fromTl(
      TlDrivingEvent(
        kind: 'harsh_braking',
        severity: 0.7,
        speed: 12,
        value: 0.9,
        latitude: 1,
        longitude: 2,
        timestampMs: 1000,
      ),
    );
    expect(e.kind, 'harsh_braking');
    expect(e.severity, 0.7);
    expect(e.value, 0.9);
    expect(e.timestamp.millisecondsSinceEpoch, 1000);
  });

  test('ImpactEvent.fromTl maps fields and isPotential', () {
    final pot = ImpactEvent.fromTl(
      TlImpactEvent(
        kind: 'potential_crash',
        id: 5,
        confidence: 0.8,
        peakG: 4,
        speedBefore: 16,
        latitude: 1,
        longitude: 2,
        timestampMs: 1000,
        confirmDeadlineMs: 16000,
      ),
    );
    expect(pot.isPotential, isTrue);
    expect(pot.id, 5);
    expect(pot.confirmDeadline.millisecondsSinceEpoch, 16000);

    final confirmed = ImpactEvent.fromTl(
      TlImpactEvent(
        kind: 'crash',
        id: 5,
        confidence: 0.8,
        peakG: 4,
        speedBefore: 16,
        latitude: 1,
        longitude: 2,
        timestampMs: 1000,
        confirmDeadlineMs: 1000,
      ),
    );
    expect(confirmed.isPotential, isFalse);
  });

  test('ModeChangeEvent.fromTl maps fields', () {
    final e = ModeChangeEvent.fromTl(
      TlModeChangeEvent(mode: 'vehicle', confidence: 0.95),
    );
    expect(e.mode, 'vehicle');
    expect(e.confidence, 0.95);
  });
}
