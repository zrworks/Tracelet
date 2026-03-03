import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracelet/tracelet.dart';

/// Integration tests for the Audit Trail enterprise feature.
///
/// These tests exercise the real native plugin through MethodChannels,
/// verifying that audit trail verification and proof retrieval work
/// correctly through the platform layer.
///
/// **Note:** The audit trail is populated automatically when tracking is active
/// and `AuditConfig.enabled` is `true`. These tests verify the query/verify
/// API works when no audit data exists (edge case) and the model
/// deserialization from native responses.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Audit Trail — Verification API', () {
    testWidgets('verifyAuditTrail returns valid result when no data exists', (
      tester,
    ) async {
      final result = await Tracelet.verifyAuditTrail();

      // With no audit data, verification should return a valid result
      // (0 records verified, no broken chain)
      expect(result, isA<AuditVerification>());
      expect(result.totalRecords, isA<int>());
      expect(result.verifiedRecords, isA<int>());
      expect(result.totalRecords, greaterThanOrEqualTo(0));
      expect(result.verifiedRecords, greaterThanOrEqualTo(0));
    });

    testWidgets(
      'verifyAuditTrail isValid is true when chain is empty or intact',
      (tester) async {
        final result = await Tracelet.verifyAuditTrail();

        // An empty chain or intact chain should be valid
        if (result.totalRecords == 0) {
          expect(result.isValid, isTrue);
          expect(result.brokenAtIndex, isNull);
          expect(result.brokenAtUuid, isNull);
          expect(result.error, isNull);
        }
      },
    );

    testWidgets('getAuditProof returns null for non-existent UUID', (
      tester,
    ) async {
      final proof = await Tracelet.getAuditProof('non-existent-uuid-12345');

      // No record with this UUID should exist
      expect(proof, isNull);
    });

    testWidgets('verifyAuditTrail result has consistent record counts', (
      tester,
    ) async {
      final result = await Tracelet.verifyAuditTrail();

      // verifiedRecords should never exceed totalRecords
      expect(result.verifiedRecords, lessThanOrEqualTo(result.totalRecords));

      // If valid, all records should be verified
      if (result.isValid) {
        expect(result.verifiedRecords, equals(result.totalRecords));
      }
    });
  });

  group('Audit Trail — Model Serialization', () {
    testWidgets('AuditVerification.fromMap handles native response', (
      tester,
    ) async {
      // Test that the model can be constructed from a typical native response
      final verification = AuditVerification.fromMap({
        'is_valid': true,
        'total_records': 10,
        'verified_records': 10,
        'broken_at_index': null,
        'broken_at_uuid': null,
        'error': null,
      });

      expect(verification.isValid, isTrue);
      expect(verification.totalRecords, 10);
      expect(verification.verifiedRecords, 10);
      expect(verification.brokenAtIndex, isNull);
    });

    testWidgets('AuditVerification.fromMap handles broken chain response', (
      tester,
    ) async {
      final verification = AuditVerification.fromMap({
        'is_valid': false,
        'total_records': 10,
        'verified_records': 5,
        'broken_at_index': 5,
        'broken_at_uuid': 'uuid-at-break',
        'error': 'Hash mismatch at index 5',
      });

      expect(verification.isValid, isFalse);
      expect(verification.totalRecords, 10);
      expect(verification.verifiedRecords, 5);
      expect(verification.brokenAtIndex, 5);
      expect(verification.brokenAtUuid, 'uuid-at-break');
      expect(verification.error, contains('Hash mismatch'));
    });

    testWidgets('AuditProof.fromMap handles snake_case keys', (tester) async {
      final proof = AuditProof.fromMap({
        'uuid': 'test-uuid',
        'hash': 'abc123def456',
        'previous_hash': 'genesis',
        'chain_index': 0,
        'timestamp': '2024-01-01T00:00:00.000Z',
      });

      expect(proof.uuid, 'test-uuid');
      expect(proof.hash, 'abc123def456');
      expect(proof.previousHash, 'genesis');
      expect(proof.chainIndex, 0);
      expect(proof.timestamp, '2024-01-01T00:00:00.000Z');
    });

    testWidgets('AuditProof.fromMap handles camelCase keys', (tester) async {
      final proof = AuditProof.fromMap({
        'uuid': 'test-uuid-2',
        'hash': 'xyz789',
        'previousHash': 'prev-hash',
        'chainIndex': 42,
        'timestamp': '2024-06-15T12:30:00.000Z',
      });

      expect(proof.uuid, 'test-uuid-2');
      expect(proof.previousHash, 'prev-hash');
      expect(proof.chainIndex, 42);
    });

    testWidgets('AuditProof.toMap produces correct keys', (tester) async {
      const proof = AuditProof(
        uuid: 'uuid-1',
        hash: 'hash-value',
        previousHash: 'prev-hash',
        chainIndex: 3,
        timestamp: '2024-01-01T00:00:00.000Z',
      );

      final map = proof.toMap();
      expect(map['uuid'], 'uuid-1');
      expect(map['hash'], 'hash-value');
      expect(
        map.containsKey('previous_hash') || map.containsKey('previousHash'),
        isTrue,
      );
      expect(
        map.containsKey('chain_index') || map.containsKey('chainIndex'),
        isTrue,
      );
    });

    testWidgets('AuditVerification.toMap round-trips correctly', (
      tester,
    ) async {
      const original = AuditVerification(
        isValid: true,
        totalRecords: 100,
        verifiedRecords: 100,
      );

      final map = original.toMap();
      final restored = AuditVerification.fromMap(map);

      expect(restored.isValid, original.isValid);
      expect(restored.totalRecords, original.totalRecords);
      expect(restored.verifiedRecords, original.verifiedRecords);
    });
  });
}
