import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracelet/tracelet.dart';
import 'package:tracelet_sync/tracelet_sync.dart';
import 'package:tracelet_example/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Issue 124: Header Parsing and Custom Sync Body', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // 1. Setup a local mock HTTP server in Dart
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;

    final requestCompleter = Completer<Map<String, dynamic>>();
    server.listen((req) async {
      final content = await utf8.decoder.bind(req).join();
      final headersMap = <String, String>{};
      req.headers.forEach((name, values) {
        headersMap[name] = values.join(',');
      });
      if (!requestCompleter.isCompleted) {
        requestCompleter.complete({'content': content, 'headers': headersMap});
      }
      req.response.statusCode = 200;
      req.response.write('{"success":true}');
      req.response.close();
    });

    Tracelet.setSyncBodyBuilder((context) async {
      return {'issue_124_test': true, 'points': context.locations};
    });

    await Tracelet.ready(
      Config(
        http: HttpConfig(
          url: 'http://127.0.0.1:$port/sync',
          batchSync: true,
          maxBatchSize: 10,
          headers: const {
            'X-Test-Header': 'issue124-value',
            'Authorization': 'Bearer test-token',
          },
        ),
      ),
    );

    // 3. Initialize sync plugin to register the Native Sink
    await TraceletSync.initialize();

    // 4. Insert a mock location directly into the database
    await Tracelet.insertLocation({
      'uuid': 'test-issue-124-uuid',
      'timestamp': DateTime.now().toIso8601String(),
      'latitude': 37.7749,
      'longitude': -122.4194,
      'accuracy': 10.0,
    });

    // 5. Trigger manual sync
    await Tracelet.sync();

    // 6. Wait for the HTTP request to hit our mock server
    final result = await requestCompleter.future.timeout(
      const Duration(seconds: 15),
    );
    final headers = result['headers'] as Map<String, String>;
    final content = result['content'] as String;

    // Verify Headers (headers are lowercased by Dart HttpServer)
    expect(
      headers['x-test-header'],
      'issue124-value',
      reason:
          'Custom headers were not correctly parsed/sent by the native sync module.',
    );
    expect(
      headers['authorization'],
      'Bearer test-token',
      reason: 'Authorization header was stripped or not sent.',
    );

    // Verify Body
    final payload = jsonDecode(content);

    expect(
      payload.containsKey('issue_124_test'),
      isTrue,
      reason: 'Dart custom body callback was bypassed! Expected key not found.',
    );
    expect(payload['issue_124_test'], isTrue);

    expect(
      payload.containsKey('points'),
      isTrue,
      reason: 'Dart custom body callback was bypassed! Expected key not found.',
    );
    expect(payload['points'], isNotEmpty);
    expect(payload['points'][0]['uuid'], 'test-issue-124-uuid');

    // Cleanup
    Tracelet.setSyncBodyBuilder(null);
    await Tracelet.stop();
    await server.close(force: true);
  });
}
