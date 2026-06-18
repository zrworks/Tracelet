import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracelet/tracelet.dart';

/// End-to-end integration tests for the sync bug fixes #212, #213, #214.
///
/// Each runs against a real loopback HTTP server and the live native SDK, so
/// they exercise the actual native sync path (Rust payload builder, the
/// debounce-cancel on stop(), and the telematics bridge to the custom builder).
///
/// Run on a device/emulator: `flutter test integration_test/sync_fixes_test.dart`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await Tracelet.setSyncBodyBuilder(null);
    try {
      await Tracelet.stop();
    } catch (_) {}
  });

  test('#212: reverse-geocoded address is in the default payload', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final captured = Completer<Map<String, dynamic>>();
    server.listen((req) async {
      final content = await utf8.decoder.bind(req).join();
      req.response.statusCode = 200;
      req.response.write('{"ok":true}');
      await req.response.close();
      if (!captured.isCompleted) {
        captured.complete(jsonDecode(content) as Map<String, dynamic>);
      }
    });
    addTearDown(() => server.close(force: true));

    await Tracelet.setSyncBodyBuilder(null); // default payload path
    await Tracelet.ready(
      Config.passive().copyWith(
        http: HttpConfig(
          url: 'http://127.0.0.1:${server.port}/sync',
          autoSync: false,
          batchSync: true,
        ),
      ),
    );
    await Tracelet.destroyLocations();
    await Tracelet.insertLocation({
      'uuid': 'it-212',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'latitude': 48.8566,
      'longitude': 2.3522,
      'accuracy': 5.0,
      'address': {'city': 'Paris', 'country': 'FR'},
    });

    await Tracelet.sync();
    final body = await captured.future.timeout(const Duration(seconds: 20));
    final loc = (body['location'] as List).first as Map<String, dynamic>;
    expect(loc['address'], isA<Map>());
    expect((loc['address'] as Map)['city'], 'Paris');
  });

  test('#213: stop() cancels the pending debounced auto-sync', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requestCount = 0;
    server.listen((req) async {
      requestCount++;
      await req.cast<List<int>>().drain<void>();
      req.response.statusCode = 200;
      req.response.write('{"ok":true}');
      await req.response.close();
    });
    addTearDown(() => server.close(force: true));

    const delayMs = 3000;
    await Tracelet.setSyncBodyBuilder(null);
    await Tracelet.ready(
      Config.passive().copyWith(
        http: HttpConfig(
          url: 'http://127.0.0.1:${server.port}/sync',
          autoSyncDelay: delayMs,
          batchSync: true,
        ),
      ),
    );
    await Tracelet.destroyLocations();
    await Tracelet.insertLocation({
      'uuid': 'it-213',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'latitude': 12.97,
      'longitude': 77.59,
      'accuracy': 5.0,
    });

    // Stop before the debounce elapses; it must be cancelled.
    await Tracelet.stop();
    await Future<void>.delayed(const Duration(milliseconds: delayMs + 2500));

    expect(requestCount, 0, reason: 'no sync should fire after stop() (#213)');
  });

  test('#214: telematics reach the custom sync body builder', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      await req.cast<List<int>>().drain<void>();
      req.response.statusCode = 200;
      req.response.write('{"ok":true}');
      await req.response.close();
    });
    addTearDown(() => server.close(force: true));

    final captured = Completer<SyncBodyContext>();
    await Tracelet.setSyncBodyBuilder((ctx) async {
      if (!captured.isCompleted) captured.complete(ctx);
      return {'points': ctx.locations, 'events': ctx.telematics};
    });

    await Tracelet.ready(
      Config.passive().copyWith(
        http: HttpConfig(
          url: 'http://127.0.0.1:${server.port}/sync',
          autoSync: false,
          batchSync: true,
          syncTelematics: true,
        ),
      ),
    );
    await Tracelet.destroyLocations();
    await Tracelet.insertLocation({
      'uuid': 'it-214',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'latitude': 12.97,
      'longitude': 77.59,
      'accuracy': 5.0,
    });
    await Tracelet.simulateTelematicsEvent(
      eventType: 'harsh_braking',
      severity: 0.85,
      latitude: 12.97,
      longitude: 77.59,
    );

    await Tracelet.sync();
    final ctx = await captured.future.timeout(const Duration(seconds: 20));
    expect(ctx.telematics, isNotEmpty);
    expect(ctx.telematics.first['event_type'], 'harsh_braking');
  });

  test('#214 dedup: telematics are not re-sent after a successful sync', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      await req.cast<List<int>>().drain<void>();
      req.response.statusCode = 200;
      req.response.write('{"ok":true}');
      await req.response.close();
    });
    addTearDown(() => server.close(force: true));

    final telematicsCounts = <int>[];
    await Tracelet.setSyncBodyBuilder((ctx) async {
      telematicsCounts.add(ctx.telematics.length);
      return {'points': ctx.locations, 'events': ctx.telematics};
    });

    await Tracelet.ready(
      Config.passive().copyWith(
        http: HttpConfig(
          url: 'http://127.0.0.1:${server.port}/sync',
          autoSync: false,
          batchSync: true,
          syncTelematics: true,
        ),
      ),
    );
    await Tracelet.destroyLocations();

    // Batch 1: a location + a telematics event → builder should see telematics.
    await Tracelet.insertLocation({
      'uuid': 'it-214d-1',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'latitude': 12.97,
      'longitude': 77.59,
      'accuracy': 5.0,
    });
    await Tracelet.simulateTelematicsEvent(
      eventType: 'speeding',
      severity: 0.7,
      latitude: 12.97,
      longitude: 77.59,
    );
    await Tracelet.sync();

    // Batch 2: a new location, NO new telematics → already-synced ones must not
    // be re-sent (marked synced after batch 1).
    await Tracelet.insertLocation({
      'uuid': 'it-214d-2',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'latitude': 12.98,
      'longitude': 77.60,
      'accuracy': 5.0,
    });
    await Tracelet.sync();
    await Tracelet.setSyncBodyBuilder(null);

    expect(
      telematicsCounts.length,
      greaterThanOrEqualTo(2),
      reason: 'builder should run for both batches',
    );
    expect(
      telematicsCounts.first,
      greaterThan(0),
      reason: 'batch 1 should carry the telematics event',
    );
    expect(
      telematicsCounts.last,
      0,
      reason: 'batch 2 must not re-send already-synced telematics (#214 dedup)',
    );
  });
}
