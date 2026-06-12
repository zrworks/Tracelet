import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracelet/tracelet.dart';

/// Issue #159: applications had no public way to inspect the offline queue —
/// `getLocations()` returns all stored records but there was no explicit
/// "pending sync" accessor. Because Tracelet prunes synced records immediately,
/// every persisted record is by definition still pending, so the new
/// `getPendingLocations()` / `getPendingLocationCount()` APIs surface exactly
/// the offline queue. This test inserts N records and asserts the new APIs
/// report them.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('getPendingLocations()/getPendingLocationCount() (#159)', (
    tester,
  ) async {
    // No URL configured → nothing can sync → everything stays pending.
    await Tracelet.ready(const Config());
    await Tracelet.destroyLocations();

    expect(await Tracelet.getPendingLocationCount(), 0);
    expect(await Tracelet.getPendingLocations(), isEmpty);

    const count = 4;
    final base = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < count; i++) {
      await Tracelet.insertLocation({
        'uuid': 'issue-159-$i',
        'timestamp': base + i,
        'latitude': 12.9716 + i * 0.0001,
        'longitude': 77.5946,
        'accuracy': 5.0,
      });
    }

    final pendingCount = await Tracelet.getPendingLocationCount();
    expect(
      pendingCount,
      count,
      reason: '#159: getPendingLocationCount() must reflect the offline queue',
    );

    final pending = await Tracelet.getPendingLocations();
    expect(pending.length, count);
    expect(pending.every((l) => l.uuid.startsWith('issue-159-')), isTrue);

    await Tracelet.destroyLocations();
    expect(await Tracelet.getPendingLocationCount(), 0);
  });
}
