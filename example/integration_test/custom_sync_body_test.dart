import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracelet/tracelet.dart';
import 'package:tracelet_sync/tracelet_sync.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TraceletSync Custom Sync Body Bypass test', (tester) async {
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

    Tracelet.setSyncBodyBuilder((context) async {
      return {'custom_payload_test': 'success', 'points': context.locations};
    });

    // 3. Initialize Tracelet
    await Tracelet.ready(
      Config(
        http: HttpConfig(
          url: 'http://127.0.0.1:$port/sync',
          batchSync: true,
          maxBatchSize: 10,
        ),
      ),
    );

    // 4. Initialize sync plugin to register the Native Sink
    await TraceletSync.initialize();

    // 5. Insert a mock location directly into the database
    await Tracelet.insertLocation({
      'uuid': 'test-sync-body-uuid',
      'timestamp': DateTime.now().toIso8601String(),
      'latitude': 37.7749,
      'longitude': -122.4194,
      'accuracy': 10.0,
    });

    // 6. Trigger manual sync
    await Tracelet.sync();

    // 7. Wait for the HTTP request to hit our mock server
    final payloadString = await requestCompleter.future.timeout(
      const Duration(seconds: 15),
    );

    final payload = jsonDecode(payloadString);

    // Verify custom properties
    expect(
      payload.containsKey('custom_payload_test'),
      isTrue,
      reason: 'Dart custom body callback was bypassed! Expected key not found.',
    );
    expect(payload['custom_payload_test'], 'success');

    expect(
      payload.containsKey('points'),
      isTrue,
      reason: 'Dart custom body callback was bypassed! Expected key not found.',
    );
    expect(payload['points'], isNotEmpty);

    // Cleanup
    Tracelet.setSyncBodyBuilder(null);
    await Tracelet.stop();
    await server.close(force: true);
  });
}
