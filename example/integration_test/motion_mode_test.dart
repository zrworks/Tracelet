import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracelet/tracelet.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Motion Mode Integration Tests', () {
    testWidgets('Cycle through motion detection modes natively', (
      tester,
    ) async {
      // 1. Initialize with accelerometer
      await Tracelet.ready(const Config());

      var state = await Tracelet.getState();
      expect(state, isNotNull);

      // 2. Switch to speed
      await Tracelet.setConfig(
        const Config(
          motion: MotionConfig(motionDetectionMode: MotionDetectionMode.speed),
        ),
      );

      state = await Tracelet.getState();
      expect(state, isNotNull);

      // 3. Switch to smart
      await Tracelet.setConfig(
        const Config(
          motion: MotionConfig(motionDetectionMode: MotionDetectionMode.smart),
        ),
      );

      state = await Tracelet.getState();
      expect(state, isNotNull);
    });
  });
}
