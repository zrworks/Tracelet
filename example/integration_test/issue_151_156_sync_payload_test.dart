import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracelet/tracelet.dart';
import 'package:tracelet_sync/tracelet_sync.dart';

/// Issue #151 (`is_moving`) and #156 (`event`): the native SyncManager built
/// the HTTP payload from a `SyncLocationRecord` that omitted the motion state
/// and the trigger event, so backends never received those keys. This test
/// syncs a record and asserts both keys are present in the payload.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sync payload includes is_moving (#151) and event (#156)', (
    tester,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;

    final bodyCompleter = Completer<Map<String, dynamic>>();
    server.listen((req) async {
      final content = await utf8.decoder.bind(req).join();
      req.response.statusCode = 200;
      req.response.write('{"success":true}');
      await req.response.close();
      if (!bodyCompleter.isCompleted) {
        bodyCompleter.complete(jsonDecode(content) as Map<String, dynamic>);
      }
    });

    await Tracelet.ready(
      Config(
        http: HttpConfig(
          url: 'http://127.0.0.1:$port/sync',
          batchSync: true,
          maxBatchSize: 10,
        ),
      ),
    );
    await TraceletSync.initialize();

    await Tracelet.destroyLocations();
    await Tracelet.insertLocation({
      'uuid': 'issue-151-156-uuid',
      'timestamp': DateTime.now().toIso8601String(),
      'latitude': 37.7749,
      'longitude': -122.4194,
      'accuracy': 10.0,
      'speed': 1.2,
      'heading': 0.0,
      'altitude': 0.0,
      'is_moving': true,
      'event': 'motionchange',
    });

    await Tracelet.sync();

    final body = await bodyCompleter.future.timeout(
      const Duration(seconds: 20),
    );

    // Default httpRootProperty is "location"; batchSync sends an array.
    final records = body['location'];
    expect(records, isA<List>(), reason: 'payload should carry a location list');
    final record = (records as List).first as Map<String, dynamic>;

    expect(
      record.containsKey('is_moving'),
      isTrue,
      reason: '#151: sync payload must include is_moving',
    );
    expect(record['is_moving'], isTrue);
    expect(
      record.containsKey('event'),
      isTrue,
      reason: '#156: sync payload must include event',
    );
    expect(record['event'], 'motionchange');

    await Tracelet.stop();
    await server.close();
  });
}
