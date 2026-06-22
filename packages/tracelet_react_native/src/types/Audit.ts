import type { AttestationProvider } from './Enums';

/** Result of {@link Tracelet.verifyAuditTrail}. */
export interface AuditVerification {
  isValid: boolean;
  verifiedRecords: number;
  brokenAtIndex?: number | null;
  brokenAtUuid?: string | null;
}

/** Audit proof for a single location. */
export interface AuditProof {
  hash: string;
  previousHash: string;
  chainIndex: number;
}

/** Device attestation token. */
export interface AttestationToken {
  provider: AttestationProvider;
  token: string;
}

/** GDPR/CCPA compliance report. */
export interface ComplianceReport {
  /** ISO8601 timestamp. */
  generatedAt: string;
  totalLocationsStored: number;
  totalLocationsSynced: number;
  maxDaysToPersist: number;
  maxRecordsToPersist: number;
  oldestRecord?: string | null;
  newestRecord?: string | null;
  databaseEncrypted: boolean;
  activePrivacyZones: number;
  privacyZoneIdentifiers: string[];
  httpSyncUrl?: string | null;
  autoSyncEnabled: boolean;
  auditTrailEnabled: boolean;
  locationPermissionStatus: number;
  motionPermissionStatus: number;
  sparseUpdatesEnabled: boolean;
  kalmanFilterEnabled: boolean;
  deltaCompressionEnabled: boolean;
  trackingEnabled: boolean;
  trackingMode: string;
}
