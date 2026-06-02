use sha2::{Sha256, Digest};
use std::sync::Mutex;

/// Represents a raw location sample with all its properties formatted for hashing.
#[derive(uniffi::Record, Clone, Debug)]
pub struct LocationRecord {
    pub uuid: String,
    pub latitude: f64,
    pub longitude: f64,
    pub timestamp: String,
    pub accuracy: f64,
    pub speed: f64,
    pub heading: f64,
    pub altitude: f64,
    pub odometer: f64,
    pub is_moving: bool,
}

/// Represents an audited location entry securely chained to the previous record.
#[derive(uniffi::Record, Clone, Debug)]
pub struct AuditRecordWithLocation {
    pub hash: String,
    pub previous_hash: String,
    pub chain_index: i32,
    pub has_location: bool,
    pub location: Option<LocationRecord>,
}

/// Contains the outcome of a blockchain verification process on the audit trail.
#[derive(uniffi::Record, Clone, Debug)]
pub struct AuditVerificationResult {
    pub is_valid: bool,
    pub total_records: i32,
    pub verified_records: i32,
    pub broken_at_index: Option<i32>,
    pub broken_at_uuid: Option<String>,
    pub error: Option<String>,
}

/// Contains the resulting hashes and chain index after appending a new record to the audit trail.
#[derive(uniffi::Record, Clone, Debug)]
pub struct AuditAppendResult {
    pub hash: String,
    pub previous_hash: String,
    pub chain_index: i32,
}

struct AuditEngineState {
    chain_index: i32,
    latest_hash: String,
    device_id: String,
}

/// Core engine responsible for maintaining a cryptographic chain of custody for location records.
#[derive(uniffi::Object)]
pub struct AuditTrailEngine {
    state: Mutex<AuditEngineState>,
}

#[uniffi::export]
impl AuditTrailEngine {
}

/// Computes the genesis hash for a new device, seeding the audit chain.
#[uniffi::export]
pub fn compute_genesis_hash(device_id: String) -> String {
    sha256(format!("tracelet:genesis:{}", device_id))
}

/// Builds a deterministic canonical string from a location record and its preceding chain hash.
#[uniffi::export]
pub fn build_canonical_string(
    previous_hash: String,
    chain_index: i32,
    loc: LocationRecord,
) -> String {
    format!(
        "{}|TRACELET_AUDIT|{}|{}|{:.6}|{:.6}|{}|{:.2}|{:.2}|{:.2}|{:.2}|{:.2}|{}",
        previous_hash,
        chain_index,
        loc.uuid,
        loc.latitude,
        loc.longitude,
        loc.timestamp,
        loc.accuracy,
        loc.speed,
        loc.heading,
        loc.altitude,
        loc.odometer,
        if loc.is_moving { "1" } else { "0" }
    )
}

/// Computes the SHA-256 hash of a given input string and returns the hex representation.
#[uniffi::export]
pub fn sha256(input: String) -> String {
    let mut hasher = Sha256::new();
    hasher.update(input.as_bytes());
    let result = hasher.finalize();
    hex::encode(result)
}

#[uniffi::export]
impl AuditTrailEngine {
    /// Initializes a new AuditTrailEngine with the device identifier and initial state.
    #[uniffi::constructor]
    pub fn new(device_id: String, initial_chain_index: i32, initial_latest_hash: Option<String>) -> Self {
        let latest_hash = initial_latest_hash.unwrap_or_else(|| {
            compute_genesis_hash(device_id.clone())
        });
        
        Self {
            state: Mutex::new(AuditEngineState {
                chain_index: initial_chain_index,
                latest_hash,
                device_id,
            }),
        }
    }
    /// Generates the next hash in the chain for a new location record.
    pub fn generate_next_hash(&self, loc: LocationRecord) -> AuditAppendResult {
        let mut state = self.state.lock().unwrap();
        
        let previous_hash = state.latest_hash.clone();
        let chain_index = state.chain_index;
        
        let canonical = build_canonical_string(previous_hash.clone(), chain_index, loc);
        let hash = sha256(canonical);
        
        state.latest_hash = hash.clone();
        state.chain_index += 1;
        
        AuditAppendResult {
            hash,
            previous_hash,
            chain_index,
        }
    }

    /// Verifies the cryptographic integrity of a sequence of location records.
    pub fn verify_chain(
        &self,
        records: Vec<AuditRecordWithLocation>,
    ) -> AuditVerificationResult {
        if records.is_empty() {
            return AuditVerificationResult {
                is_valid: true,
                total_records: 0,
                verified_records: 0,
                broken_at_index: None,
                broken_at_uuid: None,
                error: None,
            };
        }

        let state = self.state.lock().unwrap();
        let mut expected_previous_hash = compute_genesis_hash(state.device_id.clone());
        let mut verified = 0;

        for record in &records {
            if record.previous_hash != expected_previous_hash {
                return AuditVerificationResult {
                    is_valid: false,
                    total_records: records.len() as i32,
                    verified_records: verified,
                    broken_at_index: Some(record.chain_index),
                    broken_at_uuid: record.location.as_ref().map(|l| l.uuid.clone()),
                    error: Some(format!(
                        "missing link: expected previousHash={}, got={}",
                        expected_previous_hash, record.previous_hash
                    )),
                };
            }

            if !record.has_location || record.location.is_none() {
                return AuditVerificationResult {
                    is_valid: false,
                    total_records: records.len() as i32,
                    verified_records: verified,
                    broken_at_index: Some(record.chain_index),
                    broken_at_uuid: None,
                    error: Some("missing location record".to_string()),
                };
            }

            let loc = record.location.as_ref().unwrap();
            let canonical = build_canonical_string(
                record.previous_hash.clone(),
                record.chain_index,
                loc.clone(),
            );
            let computed_hash = sha256(canonical);

            if computed_hash != record.hash {
                return AuditVerificationResult {
                    is_valid: false,
                    total_records: records.len() as i32,
                    verified_records: verified,
                    broken_at_index: Some(record.chain_index),
                    broken_at_uuid: Some(loc.uuid.clone()),
                    error: Some(format!(
                        "hash mismatch: expected={}, stored={}",
                        computed_hash, record.hash
                    )),
                };
            }

            expected_previous_hash = record.hash.clone();
            verified += 1;
        }

        AuditVerificationResult {
            is_valid: true,
            total_records: records.len() as i32,
            verified_records: verified,
            broken_at_index: None,
            broken_at_uuid: None,
            error: None,
        }
    }

    /// Resets the engine state back to the genesis block.
    pub fn reset_state(&self) {
        let mut state = self.state.lock().unwrap();
        state.chain_index = 0;
        state.latest_hash = compute_genesis_hash(state.device_id.clone());
    }
}
