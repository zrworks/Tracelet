// Smoke test for the Tracelet example app.
//
// The app calls platform channels at startup (registerHeadlessTask,
// event channel subscriptions), so widget-level testing requires
// setting up mock method channels. This test exercises only the
// top-level widget tree construction (TraceletApp → MaterialApp).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tracelet_example/main.dart';

void main() {
  testWidgets('TraceletApp builds a MaterialApp', (WidgetTester tester) async {
    // Stub the Tracelet MethodChannel so platform calls don't throw.
    const channel = MethodChannel('com.tracelet/methods');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          switch (call.method) {
            case 'registerHeadlessTask':
              return true;
            case 'getState':
              return <String, Object?>{
                'enabled': false,
                'trackingMode': 0,
                'isMoving': false,
                'odometer': 0.0,
              };
            case 'getProviderState':
              return <String, Object?>{
                'enabled': true,
                'status': 0,
                'gps': false,
                'network': false,
              };
            default:
              return null;
          }
        });

    await tester.pumpWidget(const TraceletApp());

    // TraceletApp wraps a MaterialApp — verify it rendered.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
