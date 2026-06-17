import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracelet/tracelet.dart';
import 'package:tracelet_sync/tracelet_sync.dart';

/// Issue #201 — Local extras passed per-record must reach the synced payload,
/// alongside the globally-configured `HttpConfig.extras`.
///
/// Deterministic (no GPS): seeds a location carrying a LOCAL extra
/// (`event_type: sos`) via `insertLocation`, with a GLOBAL extra
/// (`device_id`) configured on `HttpConfig`, then syncs to a local mock server
/// and asserts BOTH appear in the payload.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('#201: local + global extras both reach the sync payload', (
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
          autoSync: false,
          extras: const {'device_id': 'global-123'},
        ),
      ),
    );
    await TraceletSync.initialize();

    await Tracelet.destroyLocations();
    await Tracelet.insertLocation({
      'uuid': 'issue-201-uuid',
      'timestamp': DateTime.now().toIso8601String(),
      'latitude': 19.1664,
      'longitude': 73.0011,
      'accuracy': 10.0,
      'speed': 1.2,
      'heading': 0.0,
      'altitude': 0.0,
      'is_moving': true,
      'event': 'location',
      'extras': {'event_type': 'sos'}, // LOCAL extra
    });

    await Tracelet.sync();

    final body = await bodyCompleter.future.timeout(
      const Duration(seconds: 20),
    );

    final records = body['location'];
    expect(
      records,
      isA<List>(),
      reason: 'payload should carry a location list',
    );
    final record = (records as List).first as Map<String, dynamic>;

    // LOCAL extra must be present on the record (Issue #201).
    final recordExtras = record['extras'] as Map<String, dynamic>?;
    expect(
      recordExtras?['event_type'],
      'sos',
      reason: '#201: local extra "event_type" missing from synced record',
    );

    // GLOBAL extra must still be present at the payload root.
    final rootExtras = body['extras'] as Map<String, dynamic>?;
    expect(
      rootExtras?['device_id'],
      'global-123',
      reason: 'global HttpConfig extra "device_id" missing from payload root',
    );

    await server.close(force: true);
  });
}
