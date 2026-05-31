use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// The central configuration struct for the Tracelet Engine.
/// This struct holds all tracking, network, and persistence parameters.
/// It acts as the single source of truth for the SDK's behavior across platforms.
#[derive(Debug, Clone, Serialize, Deserialize, uniffi::Record)]
#[serde(rename_all = "camelCase")]
pub struct EngineConfig {
    /// Geolocation tracking parameters (accuracy, filters, intervals).
    #[serde(default)]
    pub geo: GeoConfig,
    /// Motion detection and activity recognition parameters.
    #[serde(default)]
    pub motion: MotionConfig,
    /// HTTP synchronization and batching parameters for server communication.
    #[serde(default)]
    pub http: HttpConfig,
    /// Geofencing parameters for proximity alerts and tracking boundaries.
    #[serde(default)]
    pub geofence: GeofenceConfig,
    /// Local database persistence parameters for locations and events.
    #[serde(default)]
    pub persistence: PersistenceConfig,
    /// Security audit trail parameters for tracking data integrity.
    #[serde(default)]
    pub audit: AuditConfig,
    /// Core security parameters (e.g., database encryption).
    #[serde(default)]
    pub security: SecurityConfig,
    /// Device attestation and anti-spoofing parameters.
    #[serde(default)]
    pub attestation: AttestationConfig,
}

impl Default for EngineConfig {
    fn default() -> Self {
        Self {
            geo: GeoConfig::default(),
            motion: MotionConfig::default(),
            http: HttpConfig::default(),
            geofence: GeofenceConfig::default(),
            persistence: PersistenceConfig::default(),
            audit: AuditConfig::default(),
            security: SecurityConfig::default(),
            attestation: AttestationConfig::default(),
        }
    }
}

/// Configuration for geolocation tracking behavior.
#[derive(Debug, Clone, Serialize, Deserialize, uniffi::Record)]
#[serde(rename_all = "camelCase")]
pub struct GeoConfig {
    /// Desired accuracy for tracking (e.g., 0 = High, 1 = Medium).
    #[serde(default = "default_desired_accuracy")]
    pub desired_accuracy: i32,
    /// Minimum distance (in meters) the device must move before a location update is generated.
    #[serde(default = "default_distance_filter")]
    pub distance_filter: f64,
    /// Radius (in meters) around the stationary location to detect when movement resumes.
    #[serde(default = "default_stationary_radius")]
    pub stationary_radius: f64,
    /// Maximum time (in seconds) to wait for a location fix before falling back.
    #[serde(default = "default_location_timeout")]
    pub location_timeout: i32,
    /// If true, disables the dynamic adjustment of the distance filter based on speed.
    #[serde(default)]
    pub disable_elasticity: bool,
    /// Multiplier applied to speed to calculate the elastic distance filter.
    #[serde(default = "default_elasticity_multiplier")]
    pub elasticity_multiplier: f64,
    /// If true, enables battery-saving modes that dynamically degrade accuracy based on battery state.
    #[serde(default)]
    pub enable_adaptive_mode: bool,
    /// If true, includes OS-level timestamps as meta fields in location events.
    #[serde(default)]
    pub enable_timestamp_meta: bool,
    /// If true, locations that do not meet the distance threshold are still recorded if time elapsed exceeds max idle.
    #[serde(default)]
    pub enable_sparse_updates: bool,
    /// Distance threshold (in meters) used to calculate sparse update eligibility.
    #[serde(default = "default_sparse_distance_threshold")]
    pub sparse_distance_threshold: f64,
}

fn default_desired_accuracy() -> i32 { 0 } // High
fn default_distance_filter() -> f64 { 10.0 }
fn default_stationary_radius() -> f64 { 25.0 }
fn default_location_timeout() -> i32 { 60 }
fn default_elasticity_multiplier() -> f64 { 1.0 }
fn default_sparse_distance_threshold() -> f64 { 50.0 }

impl Default for GeoConfig {
    fn default() -> Self {
        Self {
            desired_accuracy: default_desired_accuracy(),
            distance_filter: default_distance_filter(),
            stationary_radius: default_stationary_radius(),
            location_timeout: default_location_timeout(),
            disable_elasticity: false,
            elasticity_multiplier: default_elasticity_multiplier(),
            enable_adaptive_mode: false,
            enable_timestamp_meta: false,
            enable_sparse_updates: false,
            sparse_distance_threshold: default_sparse_distance_threshold(),
        }
    }
}

/// Configuration for motion and activity detection.
#[derive(Debug, Clone, Serialize, Deserialize, uniffi::Record)]
#[serde(rename_all = "camelCase")]
pub struct MotionConfig {
    /// Number of consecutive minutes a device must remain still to trigger a stationary event.
    #[serde(default = "default_stop_timeout")]
    pub stop_timeout: i32,
    /// Delay (in seconds) before a motion event is officially registered.
    #[serde(default = "default_motion_trigger_delay")]
    pub motion_trigger_delay: i32,
    /// If true, stops the OS activity recognition updates to save battery (relies only on speed/geofences).
    #[serde(default)]
    pub disable_motion_activity_updates: bool,
    /// If true, bypasses stop detection completely (device is considered always moving).
    #[serde(default)]
    pub disable_stop_detection: bool,
    /// Accelerometer threshold (G-force) required to wake the device from a stationary state.
    #[serde(default = "default_shake_threshold")]
    pub shake_threshold: f64,
}

fn default_stop_timeout() -> i32 { 5 }
fn default_motion_trigger_delay() -> i32 { 0 }
fn default_shake_threshold() -> f64 { 2.5 }

impl Default for MotionConfig {
    fn default() -> Self {
        Self {
            stop_timeout: default_stop_timeout(),
            motion_trigger_delay: default_motion_trigger_delay(),
            disable_motion_activity_updates: false,
            disable_stop_detection: false,
            shake_threshold: default_shake_threshold(),
        }
    }
}

/// Configuration for syncing location and event data to a remote server.
#[derive(Debug, Clone, Serialize, Deserialize, Default, uniffi::Record)]
#[serde(rename_all = "camelCase")]
pub struct HttpConfig {
    /// Remote URL endpoint for HTTP sync. If None, auto-sync is disabled.
    pub url: Option<String>,
    /// HTTP Method (0 = POST, 1 = PUT).
    #[serde(default)]
    pub method: i32,
    /// Custom HTTP headers attached to synchronization requests.
    #[serde(default)]
    pub headers: HashMap<String, String>,
    /// If true, sends locations in a JSON array rather than individually.
    #[serde(default)]
    pub batch_sync: bool,
    /// Maximum number of records to send in a single batch.
    #[serde(default = "default_max_batch_size")]
    pub max_batch_size: i32,
    /// If true, automatically triggers HTTP sync operations based on internal thresholds.
    #[serde(default = "default_true")]
    pub auto_sync: bool,
    /// Maximum number of retries for a failed sync request.
    #[serde(default = "default_max_retries")]
    pub max_retries: i32,
    /// Base backoff time in milliseconds for exponential retry.
    #[serde(default = "default_retry_backoff_base")]
    pub retry_backoff_base: i32,
    /// Maximum backoff time in milliseconds for exponential retry.
    #[serde(default = "default_retry_backoff_cap")]
    pub retry_backoff_cap: i32,
    /// Optional list of PEM or DER encoded certificates for SSL pinning.
    #[serde(default)]
    pub ssl_pinning_certificates: Option<Vec<String>>,
}

fn default_max_batch_size() -> i32 { 250 }
fn default_true() -> bool { true }
fn default_max_retries() -> i32 { 3 }
fn default_retry_backoff_base() -> i32 { 1000 }
fn default_retry_backoff_cap() -> i32 { 10000 }

/// Configuration for monitoring geographic boundaries.
#[derive(Debug, Clone, Serialize, Deserialize, uniffi::Record)]
#[serde(rename_all = "camelCase")]
pub struct GeofenceConfig {
    /// If true, fires an entry trigger immediately if the device is already inside the geofence when registered.
    #[serde(default = "default_true")]
    pub geofence_initial_trigger_entry: bool,
    /// The radius (in meters) for loading geofences from the database into the active monitoring queue.
    #[serde(default = "default_geofence_proximity_radius")]
    pub geofence_proximity_radius: i32,
}

fn default_geofence_proximity_radius() -> i32 { 1000 }

impl Default for GeofenceConfig {
    fn default() -> Self {
        Self {
            geofence_initial_trigger_entry: true,
            geofence_proximity_radius: default_geofence_proximity_radius(),
        }
    }
}

/// Configuration for local SQLite database retention policies.
#[derive(Debug, Clone, Serialize, Deserialize, uniffi::Record)]
#[serde(rename_all = "camelCase")]
pub struct PersistenceConfig {
    /// Maximum number of days to retain tracking records before pruning. (-1 for infinite)
    #[serde(default = "default_max_days_to_persist")]
    pub max_days_to_persist: i32,
    /// Maximum number of absolute location records to keep. (-1 for infinite)
    #[serde(default = "default_max_records_to_persist")]
    pub max_records_to_persist: i32,
}

fn default_max_days_to_persist() -> i32 { 1 }
fn default_max_records_to_persist() -> i32 { -1 }

impl Default for PersistenceConfig {
    fn default() -> Self {
        Self {
            max_days_to_persist: default_max_days_to_persist(),
            max_records_to_persist: default_max_records_to_persist(),
        }
    }
}

/// Security feature configuration for generating tamper-evident cryptographic trails.
#[derive(Debug, Clone, Serialize, Deserialize, Default, uniffi::Record)]
#[serde(rename_all = "camelCase")]
pub struct AuditConfig {
    /// If true, location events are hashed to provide an audit trail.
    #[serde(default)]
    pub enabled: bool,
}

/// Core security and encryption configuration.
#[derive(Debug, Clone, Serialize, Deserialize, Default, uniffi::Record)]
#[serde(rename_all = "camelCase")]
pub struct SecurityConfig {
    /// If true, local SQLite databases are encrypted at rest (e.g., using SQLCipher).
    #[serde(default)]
    pub encrypt_database: bool,
}

/// Anti-spoofing and device validation configuration.
#[derive(Debug, Clone, Serialize, Deserialize, Default, uniffi::Record)]
#[serde(rename_all = "camelCase")]
pub struct AttestationConfig {
    /// If true, attestation tokens (Play Integrity/DeviceCheck) are gathered.
    #[serde(default)]
    pub enabled: bool,
}

impl EngineConfig {
    /// Deserializes a raw JSON string (usually originating from Dart `Config.toMap()`) 
    /// into a strongly-typed `EngineConfig` struct.
    pub fn from_json(json: &str) -> Result<Self, serde_json::Error> {
        serde_json::from_str(json)
    }
}
