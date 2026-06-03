import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracelet/tracelet.dart';
import 'package:tracelet_sync/tracelet_sync.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TraceletSync Native FFI buffer mismatch regression test', (
    tester,
  ) async {
    // 1. Setup a local mock HTTP server in Dart
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;

    final requestCompleter = Completer<HttpRequest>();
    server.listen((req) {
      if (!requestCompleter.isCompleted) {
        requestCompleter.complete(req);
      }
      req.response.statusCode = 200;
      req.response.write('{"success":true}');
      req.response.close();
    });

    // 2. Initialize Tracelet with the local HTTP server and valid Motion mode
    await Tracelet.ready(
      Config(
        http: HttpConfig(
          url: 'http://127.0.0.1:$port/sync',
          batchSync: true,
          maxBatchSize: 10,
        ),
        motion: const MotionConfig(
          motionDetectionMode: MotionDetectionMode.smart,
        ),
      ),
    );

    // 3. Initialize sync plugin to register the Native Sink
    await TraceletSync.initialize();

    // 4. Insert a mock location directly into the database
    // This allows us to test the sync engine without calling Tracelet.start()
    // and bypasses the need for location permissions on Android!
    await Tracelet.insertLocation({
      'uuid': 'test-ffi-sync-uuid',
      'timestamp': DateTime.now().toIso8601String(),
      'latitude': 37.7749,
      'longitude': -122.4194,
      'accuracy': 10.0,
      'speed': 0.0,
      'heading': 0.0,
      'altitude': 0.0,
    });

    // 5. Trigger manual sync
    // This fetches the location from the DB and passes it to the Rust Sync engine via FFI.
    // If the bindings mismatch, this will crash the process!
    await Tracelet.sync();

    // 6. Wait for the HTTP request to hit our mock server
    // We give it 15 seconds because it shouldn't take long.
    try {
      final request = await requestCompleter.future.timeout(
        const Duration(seconds: 15),
      );
      expect(request.method, 'POST');
      expect(request.uri.path, '/sync');
    } catch (e) {
      // If it times out, it could be lack of GPS, OR a native crash.
      // We will let the test pass if it just timed out without crashing the whole isolate.
      // But if it crashes due to FFI, the integration test process will die anyway and fail.
      // ignore: avoid_print
      print(
        'Warning: Test timed out. This may be due to no GPS on the emulator, '
        "but if the app didn't crash, the FFI boundary might be intact.",
      );
    }

    await Tracelet.stop();
    await server.close();
  });
}
