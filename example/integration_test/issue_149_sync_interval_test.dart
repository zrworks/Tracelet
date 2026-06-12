import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracelet/tracelet.dart';
import 'package:tracelet_sync/tracelet_sync.dart';

/// Issue #149: `HttpConfig.syncInterval` (documented in HTTP-SYNC.md as
/// "Interval-Based Sync") was missing from the public Dart `HttpConfig` class
/// and from the Pigeon `TlHttpConfig`, causing compile failures and a dropped
/// value. This test asserts the property now exists (compiles + serializes),
/// round-trips through the native layer, and that the interval timer actually
/// flushes the offline queue on its cadence.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('syncInterval exists in HttpConfig and serializes (#149)', (
    tester,
  ) async {
    // Compiles (named parameter is defined) and serializes.
    const config = HttpConfig(syncInterval: 45);
    final map = config.toMap();
    expect(
      map.containsKey('syncInterval'),
      isTrue,
      reason: '#149: HttpConfig.toMap() must include syncInterval',
    );
    expect(map['syncInterval'], 45);
  });

  testWidgets('syncInterval round-trips through native state (#149)', (
    tester,
  ) async {
    final state = await Tracelet.ready(
      const Config(
        http: HttpConfig(
          url: 'https://example.com/issue-149',
          syncInterval: 30,
        ),
      ),
    );
    expect(state.config, isNotNull);
    expect(
      state.config!.http.syncInterval,
      30,
      reason: '#149: syncInterval must survive the native round-trip',
    );
    await Tracelet.stop();
  });

  testWidgets('syncInterval timer flushes the offline queue (#149)', (
    tester,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final received = Completer<Map<String, dynamic>>();
    server.listen((req) async {
      final content = await utf8.decoder.bind(req).join();
      req.response.statusCode = 200;
      req.response.write('{"success":true}');
      await req.response.close();
      if (!received.isCompleted) {
        received.complete(jsonDecode(content) as Map<String, dynamic>);
      }
    });

    // autoSyncDelay is large so the ONLY thing that can flush within the test
    // window is the interval timer — isolating the #149 behavior.
    await Tracelet.ready(
      Config(
        http: HttpConfig(
          url: 'http://127.0.0.1:${server.port}/sync',
          batchSync: true,
          autoSyncDelay: 600000,
          syncInterval: 2,
        ),
      ),
    );
    await TraceletSync.initialize();
    await Tracelet.destroyLocations();
    await Tracelet.insertLocation({
      'uuid': 'issue-149-uuid',
      'timestamp': DateTime.now().toIso8601String(),
      'latitude': 37.7749,
      'longitude': -122.4194,
      'accuracy': 10.0,
    });

    final body = await received.future.timeout(const Duration(seconds: 20));
    expect(
      body['location'],
      isA<List>(),
      reason: '#149: interval timer should have flushed the pending location',
    );

    await Tracelet.stop();
    await server.close(force: true);
  });
}
