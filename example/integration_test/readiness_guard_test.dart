import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracelet/tracelet.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // IMPORTANT: do NOT call Tracelet.ready() anywhere in this file.
  // Every call below must hit the native NOT_READY guard, on both platforms.
  group('Readiness guards (NOT_READY before ready())', () {
    Future<void> expectNotReady(Future<void> Function() call) async {
      try {
        await call();
        fail('Expected PlatformException(NOT_READY) but the call succeeded');
      } on PlatformException catch (e) {
        expect(e.code, 'NOT_READY', reason: 'wrong error code: ${e.code}');
        expect(
          e.message,
          isNotNull,
          reason: 'NOT_READY error should carry a message',
        );
      }
    }

    testWidgets('start', (_) => expectNotReady(Tracelet.start));
    testWidgets(
      'startGeofences',
      (_) => expectNotReady(Tracelet.startGeofences),
    );
    testWidgets('startPeriodic', (_) => expectNotReady(Tracelet.startPeriodic));
    testWidgets('startSchedule', (_) => expectNotReady(Tracelet.startSchedule));
    testWidgets('stopSchedule', (_) => expectNotReady(Tracelet.stopSchedule));
    testWidgets(
      'changePace',
      (_) => expectNotReady(() => Tracelet.changePace(true)),
    );
    testWidgets('reset', (_) => expectNotReady(Tracelet.reset));
    testWidgets(
      'getCurrentPosition',
      (_) => expectNotReady(Tracelet.getCurrentPosition),
    );
  });
}
