import 'package:meta/meta.dart';

import '_helpers.dart';

// ---------------------------------------------------------------------------
// AuditProof
// ---------------------------------------------------------------------------

/// A single link in the tamper-proof audit chain.
///
/// Each [AuditProof] represents the cryptographic hash commitment for one
/// location record. Together, all proofs form a hash chain that can be
/// independently verified.
///
/// ```dart
/// final proof = await Tracelet.getAuditProof('some-uuid');
/// if (proof != null) {
///   print('Hash: ${proof.hash}');
///   print('Previous: ${proof.previousHash}');
///   print('Chain index: ${proof.chainIndex}');
/// }
/// ```
@immutable
class AuditProof {
  /// Creates a new [AuditProof].
  const AuditProof({
    required this.uuid,
    required this.hash,
    required this.previousHash,
    required this.chainIndex,
    required this.timestamp,
  });

  /// The UUID of the location record this proof belongs to.
  final String uuid;

  /// The SHA-256 hex digest of this record.
  ///
  /// Computed from:
  /// `SHA256(previousHash + "|TRACELET_AUDIT|" + chainIndex + "|" + canonicalFields)`
  final String hash;

  /// The hash of the previous record in the chain.
  ///
  /// For the first record, this is the **genesis hash**:
  /// `SHA256("tracelet:genesis:" + deviceId)`.
  final String previousHash;

  /// The sequential position in the audit chain (0-based).
  final int chainIndex;

  /// ISO 8601 timestamp of the location record.
  final String timestamp;

  /// Creates an [AuditProof] from a platform map.
  factory AuditProof.fromMap(Map<String, Object?> map) {
    return AuditProof(
      uuid: ensureString(map['uuid']),
      hash: ensureString(map['hash']),
      previousHash: ensureString(map['previousHash'] ?? map['previous_hash']),
      chainIndex: ensureInt(
        map['chainIndex'] ?? map['chain_index'],
        fallback: 0,
      ),
      timestamp: ensureString(map['timestamp']),
    );
  }

  /// Serializes to a map.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'uuid': uuid,
      'hash': hash,
      'previous_hash': previousHash,
      'chain_index': chainIndex,
      'timestamp': timestamp,
    };
  }

  @override
  String toString() {
    final truncated = hash.length > 16 ? '${hash.substring(0, 16)}...' : hash;
    return 'AuditProof(uuid: $uuid, chainIndex: $chainIndex, '
        'hash: $truncated)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuditProof &&
          runtimeType == other.runtimeType &&
          uuid == other.uuid &&
          hash == other.hash;

  @override
  int get hashCode => Object.hash(uuid, hash);
}

// ---------------------------------------------------------------------------
// AuditVerification
// ---------------------------------------------------------------------------

/// Result of verifying the tamper-proof audit trail.
///
/// Returned by [Tracelet.verifyAuditTrail()]. When [isValid] is `true`,
/// every record in the chain has been verified — no insertions, deletions,
/// or modifications were detected.
///
/// ```dart
/// final result = await Tracelet.verifyAuditTrail();
/// if (result.isValid) {
///   print('✅ Chain verified: ${result.verifiedRecords} records');
/// } else {
///   print('❌ Chain broken at index ${result.brokenAtIndex}');
///   print('   UUID: ${result.brokenAtUuid}');
///   print('   Error: ${result.error}');
/// }
/// ```
@immutable
class AuditVerification {
  /// Creates a new [AuditVerification].
  const AuditVerification({
    required this.isValid,
    required this.totalRecords,
    required this.verifiedRecords,
    this.brokenAtIndex,
    this.brokenAtUuid,
    this.error,
  });

  /// Whether the entire audit chain is intact.
  ///
  /// `true` if every record's hash matches the expected computation.
  final bool isValid;

  /// Total number of records in the audit trail.
  final int totalRecords;

  /// Number of records that were successfully verified before a break
  /// was detected (or all records if valid).
  final int verifiedRecords;

  /// The chain index where the first integrity violation was detected.
  ///
  /// `null` when [isValid] is `true`.
  final int? brokenAtIndex;

  /// The UUID of the location record where the chain broke.
  ///
  /// `null` when [isValid] is `true`.
  final String? brokenAtUuid;

  /// Human-readable description of the verification failure.
  ///
  /// Common errors:
  /// - `"hash mismatch"` — record data was modified after storage
  /// - `"missing link"` — a record was deleted from the chain
  /// - `"chain index gap"` — records were inserted or reordered
  ///
  /// `null` when [isValid] is `true`.
  final String? error;

  /// Creates an [AuditVerification] from a platform map.
  factory AuditVerification.fromMap(Map<String, Object?> map) {
    return AuditVerification(
      isValid: ensureBool(map['isValid'] ?? map['is_valid'], fallback: false),
      totalRecords: ensureInt(
        map['totalRecords'] ?? map['total_records'],
        fallback: 0,
      ),
      verifiedRecords: ensureInt(
        map['verifiedRecords'] ?? map['verified_records'],
        fallback: 0,
      ),
      brokenAtIndex: (map['brokenAtIndex'] ?? map['broken_at_index']) != null
          ? ensureInt(
              map['brokenAtIndex'] ?? map['broken_at_index'],
              fallback: 0,
            )
          : null,
      brokenAtUuid: (map['brokenAtUuid'] ?? map['broken_at_uuid']) as String?,
      error: map['error'] as String?,
    );
  }

  /// Serializes to a map.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'is_valid': isValid,
      'total_records': totalRecords,
      'verified_records': verifiedRecords,
      'broken_at_index': brokenAtIndex,
      'broken_at_uuid': brokenAtUuid,
      'error': error,
    };
  }

  @override
  String toString() => isValid
      ? 'AuditVerification(valid, $verifiedRecords records)'
      : 'AuditVerification(BROKEN at index $brokenAtIndex, '
            'uuid: $brokenAtUuid, error: $error)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuditVerification &&
          runtimeType == other.runtimeType &&
          isValid == other.isValid &&
          totalRecords == other.totalRecords &&
          verifiedRecords == other.verifiedRecords;

  @override
  int get hashCode => Object.hash(isValid, totalRecords, verifiedRecords);
}
