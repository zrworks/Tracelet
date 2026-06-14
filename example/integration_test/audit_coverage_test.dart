import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracelet/tracelet.dart';

/// Regression coverage for the audit-trail chain (3.3.0 fixes).
///
/// Two bugs are locked down here, exercised through the **real** native
/// persistence path (`Tracelet.insertLocation`) — the same chokepoint that
/// background/headless persists (periodic worker, location service, geofence
/// events) flow through:
///
///  1. **Coverage gap** — locations persisted outside the foreground dispatcher
///     used to skip the audit chain entirely, so `getAuditProof()` returned
///     `null` for them. Every persisted location with a uuid must now be chained.
///
///  2. **Orphan rows (iOS)** — `appendToChain` used to create an audit row with
///     an empty uuid for records lacking one. Those orphans had no retrievable
///     location and made `verifyAuditTrail()` report the whole chain broken
///     ("missing location record"). A uuid-less record must now be persisted
///     **without** adding an audit row.
///
/// These assertions are written as relative invariants (count deltas) so they
/// hold regardless of any pre-existing chain state on the device, and never
/// require `start()` (which would need runtime permissions + a foreground
/// service and hang headlessly).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Tracelet.ready(const Config(audit: AuditConfig(enabled: true)));
  });

  /// A monotonically-increasing timestamp so inserts are never collapsed by the
  /// native duplicate-timestamp guard.
  var tsCounter = DateTime.now().millisecondsSinceEpoch;
  String nextTimestamp() {
    tsCounter += 1000;
    return DateTime.fromMillisecondsSinceEpoch(tsCounter, isUtc: true)
        .toIso8601String();
  }

  Map<String, Object?> locationParams({
    String? uuid,
    String event = 'location',
  }) {
    return <String, Object?>{
      if (uuid != null) 'uuid': uuid,
      'event': event,
      'timestamp': nextTimestamp(),
      'is_moving': true,
      'activity': const <String, Object?>{'type': 'in_vehicle'},
      'coords': const <String, Object?>{
        'latitude': 37.4220,
        'longitude': -122.0841,
        'accuracy': 8.0,
        'speed': 14.0,
        'heading': 90.0,
        'altitude': 12.0,
      },
    };
  }

  testWidgets(
    'a uuid location persisted via insertLocation is chained and provable',
    (tester) async {
      final before = await Tracelet.verifyAuditTrail();

      final uuid = 'audit-cov-${DateTime.now().microsecondsSinceEpoch}';
      await Tracelet.insertLocation(locationParams(uuid: uuid));

      // The direct-insert path must now create exactly one audit link.
      final after = await Tracelet.verifyAuditTrail();
      expect(
        after.totalRecords,
        before.totalRecords + 1,
        reason: 'insertLocation with a uuid must add one audit-trail row',
      );

      // ...and that link must be retrievable as a proof (the coverage fix).
      final proof = await Tracelet.getAuditProof(uuid);
      expect(proof, isNotNull, reason: 'background-path location must be chained');
      expect(proof!.uuid, uuid);
      expect(proof.hash, isNotEmpty);
      expect(proof.previousHash, isNotEmpty);

      // Adding a valid link must not break a previously-valid chain.
      if (before.isValid) {
        expect(after.isValid, isTrue);
      }
    },
  );

  testWidgets(
    'a uuid-less record is persisted but never creates an orphan audit row',
    (tester) async {
      final beforeAudit = await Tracelet.verifyAuditTrail();
      final beforeCount = await Tracelet.getCount();

      // No uuid — e.g. an event the dispatcher never enriched.
      await Tracelet.insertLocation(locationParams());

      final afterAudit = await Tracelet.verifyAuditTrail();
      final afterCount = await Tracelet.getCount();

      // It IS persisted...
      expect(
        afterCount,
        greaterThan(beforeCount),
        reason: 'the uuid-less record should still be stored',
      );

      // ...but it must NOT add an audit row (that would be an orphan).
      expect(
        afterAudit.totalRecords,
        beforeAudit.totalRecords,
        reason: 'uuid-less records must not be chained (no orphan rows)',
      );

      // And therefore must not newly break a previously-valid chain.
      if (beforeAudit.isValid) {
        expect(
          afterAudit.isValid,
          isTrue,
          reason: 'uuid-less insert must not break the audit chain',
        );
      }
    },
  );

  testWidgets('getAuditProof returns null for an unknown uuid', (tester) async {
    final proof = await Tracelet.getAuditProof(
      'definitely-not-a-real-uuid-${DateTime.now().microsecondsSinceEpoch}',
    );
    expect(proof, isNull);
  });
}
