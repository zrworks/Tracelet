import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracelet/tracelet.dart';
import 'package:tracelet_sync/tracelet_sync.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TraceletSync HTTP Root Property and Params regression test on iOS', (
    tester,
  ) async {
    // 1. Setup a local mock HTTP server in Dart
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;

    final requestCompleter = Completer<String>();
    server.listen((req) async {
      final content = await utf8.decoder.bind(req).join();
      if (!requestCompleter.isCompleted) {
        requestCompleter.complete(content);
      }
      req.response.statusCode = 200;
      req.response.write('{"success":true}');
      req.response.close();
    });

    // 2. Initialize Tracelet with custom httpRootProperty and params
    await Tracelet.ready(
      Config(
        http: HttpConfig(
          url: 'http://127.0.0.1:$port/sync',
          batchSync: true,
          maxBatchSize: 10,
          httpRootProperty: 'location_data',
          params: {'user_id': 'ikolvi_tester', 'device': 'example_app'},
          extras: {'session_key': 'super-secret-token'},
        ),
        motion: const MotionConfig(
          motionDetectionMode: MotionDetectionMode.smart,
        ),
      ),
    );

    // 3. Initialize sync plugin to register the Native Sink
    await TraceletSync.initialize();

    // 4. Insert a mock location directly into the database
    await Tracelet.insertLocation({
      'uuid': 'test-ios-sync-uuid',
      'timestamp': DateTime.now().toIso8601String(),
      'latitude': 37.7749,
      'longitude': -122.4194,
      'accuracy': 10.0,
      'speed': 0.0,
      'heading': 0.0,
      'altitude': 0.0,
    });

    // 5. Trigger manual sync
    await Tracelet.sync();

    // 6. Wait for the HTTP request to hit our mock server
    final payloadString = await requestCompleter.future.timeout(
      const Duration(seconds: 15),
    );
    
    final payload = jsonDecode(payloadString);
    
    // Verify custom properties
    expect(payload.containsKey('location_data'), isTrue, reason: 'httpRootProperty should be location_data');
    expect(payload['location_data'], isNotEmpty);
    
    expect(payload.containsKey('params'), isTrue, reason: 'params object should exist');
    expect(payload['params']['user_id'], 'ikolvi_tester');
    expect(payload['params']['device'], 'example_app');

    expect(payload.containsKey('extras'), isTrue, reason: 'extras object should exist');
    expect(payload['extras']['session_key'], 'super-secret-token');

    await Tracelet.stop();
    await server.close();
  });
}
