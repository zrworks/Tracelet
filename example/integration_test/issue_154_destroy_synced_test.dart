import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracelet/tracelet.dart';
import 'package:tracelet_sync/tracelet_sync.dart';

/// Issue #154: `destroySyncedLocations()` was a hardcoded stub that always
/// returned `0`. The Rust Core prunes each synced location from the local store
/// the moment it is confirmed uploaded, so there is never a "synced but still
/// persisted" row to delete on demand. The method now reports (and resets) the
/// real running total of locations that have been synced-and-pruned, instead of
/// a constant `0`. This test syncs N records to a loopback server and asserts
/// `destroySyncedLocations()` returns N.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('destroySyncedLocations() returns the real synced count (#154)', (
    tester,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      await utf8.decoder.bind(req).join();
      req.response.statusCode = 200;
      req.response.write('{"success":true}');
      await req.response.close();
    });

    await Tracelet.ready(
      Config(
        http: HttpConfig(
          url: 'http://127.0.0.1:${server.port}/sync',
          autoSync: false,
          batchSync: true,
          maxBatchSize: 50,
        ),
      ),
    );
    await TraceletSync.initialize();

    await Tracelet.destroyLocations();
    // Drain any previously-accumulated counter so this test is independent.
    await Tracelet.destroySyncedLocations();

    const count = 3;
    final base = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < count; i++) {
      await Tracelet.insertLocation({
        'uuid': 'issue-154-$i',
        'timestamp': base + i,
        'latitude': 48.8566 + i * 0.0001,
        'longitude': 2.3522,
        'accuracy': 10.0,
      });
    }

    await Tracelet.sync();

    final deleted = await Tracelet.destroySyncedLocations();
    expect(
      deleted,
      count,
      reason:
          '#154: must report the real number of synced locations removed, '
          'not a hardcoded 0',
    );

    // The counter resets after reading.
    final second = await Tracelet.destroySyncedLocations();
    expect(second, 0, reason: '#154: counter resets after being read');

    await Tracelet.stop();
    await server.close(force: true);
  });
}
