import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracelet/tracelet.dart';
import 'package:tracelet_sync/tracelet_sync.dart';

/// Issue #204 — a single batch must be uploaded exactly once. The bug caused the
/// sync to fire twice for the same batch (duplicate providers / triggers),
/// producing duplicate server uploads and duplicate DB rows.
///
/// Deterministic (no GPS): seeds 3 locations, lets auto-sync fire once, and
/// asserts the mock server received exactly ONE request carrying all 3 records
/// (not two requests, and no record delivered twice).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('#204: one batch is uploaded exactly once (no duplicate)', (
    tester,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;

    final requests = <Map<String, dynamic>>[];
    server.listen((req) async {
      final content = await utf8.decoder.bind(req).join();
      req.response.statusCode = 200;
      req.response.write('{"success":true}');
      await req.response.close();
      try {
        requests.add(jsonDecode(content) as Map<String, dynamic>);
      } catch (_) {}
    });

    await Tracelet.ready(
      Config(
        http: HttpConfig(
          url: 'http://127.0.0.1:$port/sync',
          batchSync: true,
          maxBatchSize: 50,
          autoSyncDelay: 1000,
        ),
      ),
    );
    await TraceletSync.initialize();

    await Tracelet.destroyLocations();

    for (var i = 0; i < 3; i++) {
      await Tracelet.insertLocation({
        'uuid': 'issue-204-$i',
        'timestamp': DateTime.now().toIso8601String(),
        'latitude': 19.16 + i * 0.001,
        'longitude': 73.00 + i * 0.001,
        'accuracy': 10.0,
        'speed': 0.0,
        'heading': 0.0,
        'altitude': 0.0,
        'is_moving': true,
        'event': 'location',
      });
    }

    // Allow auto-sync to debounce + fire, then a generous extra window to catch
    // any erroneous second upload of the same batch.
    await Future<void>.delayed(const Duration(seconds: 6));

    expect(
      requests.length,
      1,
      reason:
          '#204: expected exactly one upload for the batch, got '
          '${requests.length} (duplicate sync).',
    );

    final records = requests.first['location'] as List;
    expect(records.length, 3, reason: 'batch should carry all 3 records');

    // No record uploaded twice.
    final ids = records.map((r) => (r as Map)['uuid'] as String).toSet();
    expect(ids.length, 3, reason: 'records must be unique (no duplicates)');

    await server.close(force: true);
  });
}
