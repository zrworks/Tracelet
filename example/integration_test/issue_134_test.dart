import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracelet/tracelet.dart';
import 'package:tracelet_sync/tracelet_sync.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Issue 134: Custom Sync Body Builder Multiple Syncs Test', (
    tester,
  ) async {
    // 1. Setup a local mock HTTP server in Dart
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;

    var syncCount = 0;
    final firstSyncCompleter = Completer<void>();
    final secondSyncCompleter = Completer<void>();

    server.listen((req) async {
      await utf8.decoder.bind(req).join();
      syncCount++;

      if (syncCount == 1) {
        firstSyncCompleter.complete();
      } else if (syncCount == 2) {
        secondSyncCompleter.complete();
      }

      req.response.statusCode = 200;
      req.response.write('{"success":true}');
      req.response.close();
    });

    // 2. Set the custom body builder with the exact payload format from Issue 134
    Tracelet.setSyncBodyBuilder((context) async {
      return {
        'location': context.locations,
        'is_live_ping': false,
        'extras': {'source': 'issue134-repro'},
      };
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

    // 5. Insert first location
    await Tracelet.insertLocation({
      'uuid': 'test-sync-body-uuid-1',
      'timestamp': DateTime.now().toIso8601String(),
      'latitude': 37.7749,
      'longitude': -122.4194,
      'accuracy': 10.0,
    });

    // 6. Trigger manual sync and wait for it
    await Tracelet.sync();
    await firstSyncCompleter.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException(
        'First sync timed out (Custom Builder Failed)',
      ),
    );

    expect(syncCount, 1, reason: 'Should have synced exactly once');

    // 7. Insert SECOND location (this simulates the "next" batch in the background)
    await Tracelet.insertLocation({
      'uuid': 'test-sync-body-uuid-2',
      'timestamp': DateTime.now().toIso8601String(),
      'latitude': 37.7750,
      'longitude': -122.4195,
      'accuracy': 10.0,
    });

    // 8. Trigger second manual sync
    await Tracelet.sync();
    await secondSyncCompleter.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException(
        'Second sync timed out (Issue 134 Regression)',
      ),
    );

    expect(syncCount, 2, reason: 'Should have synced exactly twice');

    // Cleanup
    await Tracelet.setSyncBodyBuilder(null);
    await Tracelet.stop();
    await server.close(force: true);
  });
}
