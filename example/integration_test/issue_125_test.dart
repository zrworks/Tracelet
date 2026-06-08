import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracelet/tracelet.dart';
import 'package:tracelet_sync/tracelet_sync.dart';
import 'package:tracelet_example/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Issue 125: Custom sync body timeout aborts sync without posting error payload',
    (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Spin up a local mock server — it should receive zero requests.
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      var requestReceived = false;
      String? receivedBody;

      server.listen((req) async {
        requestReceived = true;
        receivedBody = await utf8.decoder.bind(req).join();
        req.response.statusCode = 200;
        req.response.write('{"success":true}');
        await req.response.close();
      });

      await Tracelet.stop();
      await Tracelet.destroyLocations();

      // Intentionally hang the custom builder beyond the native 10s timeout.
      Tracelet.setSyncBodyBuilder((context) async {
        await Future.delayed(const Duration(seconds: 15));
        return {'custom': true};
      });

      await Tracelet.ready(
        Config(
          http: HttpConfig(
            url: 'http://127.0.0.1:$port/issue125',
            autoSyncDelay: 1000,
          ),
        ),
      );

      await TraceletSync.initialize();

      await Tracelet.insertLocation({
        'uuid': 'test-issue-125-uuid',
        'timestamp': DateTime.now().toIso8601String(),
        'latitude': 5.0,
        'longitude': 5.0,
        'accuracy': 10.0,
      });

      // Wait for the native timeout (10s) plus buffer for autoSyncDelay (1s) + margin.
      await tester.pump(const Duration(seconds: 13));
      await Future.delayed(const Duration(seconds: 13));

      // The mock server must not have received any request — the sync should
      // have aborted cleanly when the custom body builder timed out. In
      // particular it must NOT have posted {"error":"TIMEOUT"}.
      expect(
        requestReceived,
        isFalse,
        reason:
            'Native SDK posted a request (body: $receivedBody) after a custom '
            'body builder timeout. Expected the sync to be aborted.',
      );

      // Cleanup
      Tracelet.setSyncBodyBuilder(null);
      await Tracelet.stop();
      await server.close(force: true);
    },
  );

  testWidgets(
    'Issue 125 regression guard: default sync (no custom body builder) still '
    'posts telemetry',
    (tester) async {
      app.main();
      await tester.pumpAndSettle();

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      final received = <String>[];

      server.listen((req) async {
        received.add(await utf8.decoder.bind(req).join());
        req.response.statusCode = 200;
        req.response.write('{"success":true}');
        await req.response.close();
      });

      await Tracelet.stop();
      await Tracelet.destroyLocations();

      // Critical: NO custom body builder registered. The native interceptor is
      // always present, so the SDK must fall through to the default payload
      // here rather than aborting (the regression the hasBodyBuilder flag
      // prevents).
      Tracelet.setSyncBodyBuilder(null);

      await Tracelet.ready(
        Config(
          http: HttpConfig(
            url: 'http://127.0.0.1:$port/default',
            autoSync: false,
          ),
        ),
      );

      await TraceletSync.initialize();

      await Tracelet.insertLocation({
        'uuid': 'test-issue-125-default-uuid',
        'timestamp': DateTime.now().toIso8601String(),
        'latitude': 9.0,
        'longitude': 9.0,
        'accuracy': 10.0,
      });

      await Tracelet.sync();
      await tester.pump(const Duration(seconds: 3));
      await Future.delayed(const Duration(seconds: 3));

      expect(
        received,
        isNotEmpty,
        reason:
            'Default sync sent no request. The hasBodyBuilder gate must let '
            'builder-less syncs fall through to the default payload.',
      );
      // And it must be a real telemetry payload, not an SDK error object.
      expect(
        received.first.contains('"error"'),
        isFalse,
        reason: 'Default sync posted an error object: ${received.first}',
      );

      await Tracelet.stop();
      await server.close(force: true);
    },
  );
}
