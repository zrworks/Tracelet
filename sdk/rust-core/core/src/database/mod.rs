use rusqlite::{params, Connection};
use std::sync::{Mutex, RwLock};
use chrono::Utc;
use crate::error::TraceletError;
use aes_gcm::{
    aead::{Aead, KeyInit, generic_array::GenericArray},
    Aes256Gcm, Nonce
};
use rand::{RngCore, rngs::OsRng};

// Import spatial and geo structures to expose them directly through DatabaseManager
use crate::spatial::geofence_evaluator::CoreGeofence;
use crate::spatial::privacy_zone::CorePrivacyZone;
use crate::algorithms::geo_utils::Coordinate;

#[derive(uniffi::Object)]
/// Central database manager handling standard SQLite and secure AES-256 encrypted storage.
/// Coordinates reading and writing of geofences, privacy zones, location history, and audit trail records.
pub struct DatabaseManager {
    conn: Mutex<Connection>,
    encryption_key: RwLock<Option<[u8; 32]>>,
}

#[derive(Debug, Clone, uniffi::Record)]
/// Represents a serialized historical location record fetched from database.
pub struct DbLocationRecord {
    pub id: i64,
    pub timestamp: String,
    pub latitude: f64,
    pub longitude: f64,
    pub accuracy: f64,
    pub speed: f64,
    pub heading: f64,
    pub altitude: f64,
    pub is_mock: bool,
    pub activity: String,
    pub route_context: Option<String>,
}

#[derive(Debug, Clone, uniffi::Record)]
/// Represents a validated tamper-proof cryptographic audit trail record.
/// Used to verify chain integrity across native and core database sync layers.
pub struct DbAuditRecord {
    /// Unique identifier (UUID string) for this specific audit entry.
    pub uuid: String,
    /// Cryptographic SHA-256 hash of the block's content.
    pub audit_hash: String,
    /// The SHA-256 hash of the immediate previous block in the blockchain.
    pub audit_previous_hash: String,
    /// Ordered index representing position in the sequential audit ledger.
    pub audit_chain_index: i32,
    /// Unix timestamp in milliseconds when this audit entry was created.
    pub audit_created_at: i64,
}

#[derive(Debug, Clone, uniffi::Record)]
/// Represents a single log entry persisted in the database.
pub struct LogEntry {
    pub id: i64,
    pub level: String,
    pub message: String,
    pub timestamp: String,
    pub source: String,
}

#[uniffi::export]
impl DatabaseManager {
    /// Initializes a new database connection and creates tables if they don't exist.
    #[uniffi::constructor]
    pub fn new(db_path: &str) -> Result<Self, TraceletError> {
        let conn = Connection::open(db_path).map_err(|e| TraceletError::Database(e.to_string()))?;
        
        conn.execute(
            "CREATE TABLE IF NOT EXISTS location_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                latitude REAL NOT NULL,
                longitude REAL NOT NULL,
                accuracy REAL NOT NULL,
                speed REAL NOT NULL,
                heading REAL NOT NULL,
                altitude REAL NOT NULL,
                is_mock INTEGER NOT NULL,
                activity TEXT NOT NULL,
                encrypted_payload BLOB,
                route_context TEXT
            )",
            [],
        ).map_err(|e| TraceletError::Database(e.to_string()))?;

        conn.execute(
            "CREATE TABLE IF NOT EXISTS geofence_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                geofence_id TEXT NOT NULL,
                action TEXT NOT NULL,
                timestamp TEXT NOT NULL,
                latitude REAL NOT NULL,
                longitude REAL NOT NULL
            )",
            [],
        ).map_err(|e| TraceletError::Database(e.to_string()))?;

        conn.execute(
            "CREATE TABLE IF NOT EXISTS geofences (
                identifier TEXT PRIMARY KEY,
                latitude REAL NOT NULL,
                longitude REAL NOT NULL,
                radius REAL NOT NULL,
                notify_on_entry INTEGER DEFAULT 1,
                notify_on_exit INTEGER DEFAULT 1,
                notify_on_dwell INTEGER DEFAULT 0,
                loitering_delay INTEGER DEFAULT 0,
                gf_extras TEXT,
                vertices TEXT
            )",
            [],
        ).map_err(|e| TraceletError::Database(e.to_string()))?;

        conn.execute(
            "CREATE TABLE IF NOT EXISTS audit_trail (
                uuid TEXT PRIMARY KEY,
                audit_hash TEXT NOT NULL,
                audit_previous_hash TEXT NOT NULL,
                audit_chain_index INTEGER NOT NULL UNIQUE,
                audit_created_at INTEGER DEFAULT (strftime('%s','now') * 1000)
            )",
            [],
        ).map_err(|e| TraceletError::Database(e.to_string()))?;

        conn.execute(
            "CREATE TABLE IF NOT EXISTS privacy_zones (
                identifier TEXT PRIMARY KEY,
                latitude REAL NOT NULL,
                longitude REAL NOT NULL,
                radius REAL NOT NULL,
                pz_action INTEGER NOT NULL DEFAULT 0,
                pz_degraded_accuracy REAL DEFAULT 1000.0
            )",
            [],
        ).map_err(|e| TraceletError::Database(e.to_string()))?;

        conn.execute(
            "CREATE TABLE IF NOT EXISTS logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                level TEXT NOT NULL,
                message TEXT NOT NULL,
                timestamp TEXT DEFAULT (datetime('now')),
                source TEXT DEFAULT 'plugin'
            )",
            [],
        ).map_err(|e| TraceletError::Database(e.to_string()))?;

        // Add encrypted_payload column if it doesn't exist (for seamless migration)
        let _ = conn.execute("ALTER TABLE location_events ADD COLUMN encrypted_payload BLOB", []);
        let _ = conn.execute("ALTER TABLE location_events ADD COLUMN route_context TEXT", []);
        let _ = conn.execute("ALTER TABLE geofences ADD COLUMN encrypted_payload BLOB", []);
        let _ = conn.execute("ALTER TABLE privacy_zones ADD COLUMN encrypted_payload BLOB", []);
        let _ = conn.execute("ALTER TABLE audit_trail ADD COLUMN encrypted_payload BLOB", []);

        Ok(Self {
            conn: Mutex::new(conn),
            encryption_key: RwLock::new(None),
        })
    }

    /// Sets the encryption key (32 bytes max). If the string is empty or invalid, encryption is disabled.
    pub fn set_encryption_key(&self, key: &str) {
        let mut w = self.encryption_key.write().unwrap();
        if key.is_empty() {
            *w = None;
            return;
        }
        
        use sha2::{Sha256, Digest};
        let mut hasher = Sha256::new();
        hasher.update(key.as_bytes());
        let result = hasher.finalize();
        
        let mut key_bytes = [0u8; 32];
        key_bytes.copy_from_slice(&result);
        *w = Some(key_bytes);
    }

    // Helper to encrypt
    fn encrypt_payload(&self, plaintext: &[u8]) -> Option<Vec<u8>> {
        let key = *self.encryption_key.read().unwrap();
        if let Some(k) = key {
            let cipher = Aes256Gcm::new(GenericArray::from_slice(&k));
            let mut nonce_bytes = [0u8; 12];
            OsRng.fill_bytes(&mut nonce_bytes);
            let nonce = Nonce::from_slice(&nonce_bytes);
            
            if let Ok(mut ciphertext) = cipher.encrypt(nonce, plaintext) {
                let mut result = Vec::with_capacity(1 + 12 + ciphertext.len());
                result.push(0x01);
                result.extend_from_slice(&nonce_bytes);
                result.append(&mut ciphertext);
                return Some(result);
            }
        }
        None
    }

    fn decrypt_payload(&self, payload: &[u8]) -> Option<Vec<u8>> {
        if payload.is_empty() { return None; }
        let magic = payload[0];
        
        if magic == 0x01 {
            if payload.len() < 13 { return None; }
            let key = *self.encryption_key.read().unwrap();
            if let Some(k) = key {
                let cipher = Aes256Gcm::new(GenericArray::from_slice(&k));
                let nonce = Nonce::from_slice(&payload[1..13]);
                if let Ok(plaintext) = cipher.decrypt(nonce, &payload[13..]) {
                    return Some(plaintext);
                }
            }
        }
        None
    }

    /// Inserts a new location record into the database.
    pub fn insert_location(&self, lat: f64, lng: f64, acc: f64, speed: f64, heading: f64, altitude: f64, is_mock: bool, activity: &str, route_context: Option<String>) -> Result<(), TraceletError> {
        let conn = self.conn.lock().unwrap();
        let timestamp = Utc::now().to_rfc3339();
        
        let is_encrypted = self.encryption_key.read().unwrap().is_some();
        if is_encrypted {
            let record = serde_json::json!({
                "lat": lat,
                "lng": lng,
                "acc": acc,
                "speed": speed,
                "heading": heading,
                "altitude": altitude,
                "is_mock": is_mock,
                "activity": activity,
                "route_context": route_context
            });
            if let Some(payload) = self.encrypt_payload(record.to_string().as_bytes()) {
                conn.execute(
                    "INSERT INTO location_events (timestamp, latitude, longitude, accuracy, speed, heading, altitude, is_mock, activity, encrypted_payload, route_context)
                     VALUES (?1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0, '', ?2, ?3)",
                    params![timestamp, payload, route_context],
                ).map_err(|e| TraceletError::Database(e.to_string()))?;
                return Ok(());
            }
        }
        
        // Fallback or unencrypted
        conn.execute(
            "INSERT INTO location_events (timestamp, latitude, longitude, accuracy, speed, heading, altitude, is_mock, activity, encrypted_payload, route_context)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, NULL, ?10)",
            params![timestamp, lat, lng, acc, speed, heading, altitude, if is_mock { 1 } else { 0 }, activity, route_context],
        ).map_err(|e| TraceletError::Database(e.to_string()))?;
        Ok(())
    }

    /// Retrieves a batch of location records, up to `limit`.
    pub fn get_locations_batch(&self, limit: i32) -> Result<Vec<DbLocationRecord>, TraceletError> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare("SELECT id, timestamp, latitude, longitude, accuracy, speed, heading, altitude, is_mock, activity, encrypted_payload, route_context FROM location_events ORDER BY id ASC LIMIT ?1").map_err(|e| TraceletError::Database(e.to_string()))?;
        
        let iter = stmt.query_map([limit], |row| {
            let mut lat: f64 = row.get(2)?;
            let mut lng: f64 = row.get(3)?;
            let mut acc: f64 = row.get(4)?;
            let mut speed: f64 = row.get(5)?;
            let mut heading: f64 = row.get(6)?;
            let mut altitude: f64 = row.get(7)?;
            let mut is_mock_val: i32 = row.get(8)?;
            let mut activity_val: String = row.get(9)?;
            
            let encrypted_payload: Option<Vec<u8>> = row.get(10).unwrap_or(None);
            let mut route_context: Option<String> = row.get(11).unwrap_or(None);
            
            if let Some(payload_bytes) = encrypted_payload {
                if let Some(plaintext) = self.decrypt_payload(&payload_bytes) {
                    if let Ok(json) = serde_json::from_slice::<serde_json::Value>(&plaintext) {
                        lat = json["lat"].as_f64().unwrap_or(0.0);
                        lng = json["lng"].as_f64().unwrap_or(0.0);
                        acc = json["acc"].as_f64().unwrap_or(0.0);
                        speed = json["speed"].as_f64().unwrap_or(0.0);
                        heading = json["heading"].as_f64().unwrap_or(0.0);
                        altitude = json["altitude"].as_f64().unwrap_or(0.0);
                        if let Some(is_mock) = json.get("is_mock").and_then(|v| v.as_bool()) { is_mock_val = if is_mock { 1 } else { 0 }; }
                        if let Some(activity) = json.get("activity").and_then(|v| v.as_str()) { activity_val = activity.to_string(); }
                        if let Some(rc) = json.get("route_context").and_then(|v| v.as_str()) { route_context = Some(rc.to_string()); }
                    }
                }
            }
            
            Ok(DbLocationRecord {
                id: row.get(0)?,
                timestamp: row.get(1)?,
                latitude: lat,
                longitude: lng,
                accuracy: acc,
                speed,
                heading,
                altitude,
                is_mock: is_mock_val != 0,
                activity: activity_val,
                route_context,
            })
        }).map_err(|e| TraceletError::Database(e.to_string()))?;

        let mut records = Vec::new();
        for r in iter {
            if let Ok(record) = r {
                records.push(record);
            }
        }
        Ok(records)
    }

    /// Deletes records up to the given max ID (used after successful sync).
    pub fn clear_locations_up_to(&self, max_id: i64) -> Result<(), TraceletError> {
        let conn = self.conn.lock().unwrap();
        conn.execute("DELETE FROM location_events WHERE id <= ?1", params![max_id]).map_err(|e| TraceletError::Database(e.to_string()))?;
        Ok(())
    }

    /// Gets the total count of locations persisted in the database.
    pub fn is_empty(&self) -> Result<bool, TraceletError> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare("SELECT COUNT(*) FROM location_events").map_err(|e| TraceletError::Database(e.to_string()))?;
        let count: i64 = stmt.query_row([], |row| row.get(0)).unwrap_or(0);
        Ok(count == 0)
    }

    /// Gets the total count of locations persisted in the database.
    pub fn get_locations_count(&self) -> Result<i32, TraceletError> {
        let conn = self.conn.lock().unwrap();
        let count: i32 = conn.query_row("SELECT COUNT(*) FROM location_events", [], |row| row.get(0))
            .map_err(|e| TraceletError::Database(e.to_string()))?;
        Ok(count)
    }

    /// Deletes all location records in the database.
    pub fn destroy_locations(&self) -> Result<(), TraceletError> {
        let conn = self.conn.lock().unwrap();
        conn.execute("DELETE FROM location_events", [])
            .map_err(|e| TraceletError::Database(e.to_string()))?;
        Ok(())
    }

    /// Deletes a specific location by ID.
    pub fn destroy_location(&self, id: i64) -> Result<(), TraceletError> {
        let conn = self.conn.lock().unwrap();
        conn.execute("DELETE FROM location_events WHERE id = ?1", params![id])
            .map_err(|e| TraceletError::Database(e.to_string()))?;
        Ok(())
    }

    // --- Geofences ---
    
    pub fn insert_geofence(&self, identifier: &str, lat: f64, lng: f64, radius: f64) -> Result<(), TraceletError> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "INSERT OR REPLACE INTO geofences (identifier, latitude, longitude, radius) VALUES (?1, ?2, ?3, ?4)",
            params![identifier, lat, lng, radius]
        ).map_err(|e| TraceletError::Database(e.to_string()))?;
        Ok(())
    }
    
    pub fn delete_geofence(&self, identifier: &str) -> Result<(), TraceletError> {
        let conn = self.conn.lock().unwrap();
        conn.execute("DELETE FROM geofences WHERE identifier = ?1", params![identifier])
            .map_err(|e| TraceletError::Database(e.to_string()))?;
        Ok(())
    }
    
    pub fn clear_geofences(&self) -> Result<(), TraceletError> {
        let conn = self.conn.lock().unwrap();
        conn.execute("DELETE FROM geofences", [])
            .map_err(|e| TraceletError::Database(e.to_string()))?;
        Ok(())
    }

    // --- Privacy Zones ---
    
    /// Inserts or replaces a privacy zone record in the database.
    ///
    /// # Arguments
    /// * `identifier` - A unique string identifying this privacy zone.
    /// * `lat` - Center latitude in decimal degrees.
    /// * `lng` - Center longitude in decimal degrees.
    /// * `radius` - Radius of the privacy zone in meters.
    /// * `action` - Integer indicating the privacy action to apply:
    ///   - 0: EXCLUDE (drop locations completely)
    ///   - 1: DEGRADE (snap coordinates to a coarse accuracy grid)
    ///   - 2: EVENT_ONLY (dispatch real-time updates to listeners but do not persist)
    /// * `degraded_accuracy` - Precision grid size in meters for DEGRADE actions (defaults to 1000.0).
    pub fn insert_privacy_zone(&self, identifier: &str, lat: f64, lng: f64, radius: f64, action: i32, degraded_accuracy: f64) -> Result<(), TraceletError> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "INSERT OR REPLACE INTO privacy_zones (identifier, latitude, longitude, radius, pz_action, pz_degraded_accuracy) VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params![identifier, lat, lng, radius, action, degraded_accuracy]
        ).map_err(|e| TraceletError::Database(e.to_string()))?;
        Ok(())
    }
    
    /// Deletes a specific privacy zone from the database by its unique identifier.
    pub fn delete_privacy_zone(&self, identifier: &str) -> Result<(), TraceletError> {
        let conn = self.conn.lock().unwrap();
        conn.execute("DELETE FROM privacy_zones WHERE identifier = ?1", params![identifier])
            .map_err(|e| TraceletError::Database(e.to_string()))?;
        Ok(())
    }
    
    /// Removes all stored privacy zones from the database.
    pub fn clear_privacy_zones(&self) -> Result<(), TraceletError> {
        let conn = self.conn.lock().unwrap();
        conn.execute("DELETE FROM privacy_zones", [])
            .map_err(|e| TraceletError::Database(e.to_string()))?;
        Ok(())
    }

    /// Retrieves all privacy zones registered in the local database.
    /// Used by native managers to query geofenced privacy control zones.
    pub fn get_privacy_zones(&self) -> Result<Vec<CorePrivacyZone>, TraceletError> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare("SELECT identifier, latitude, longitude, radius, pz_action, pz_degraded_accuracy FROM privacy_zones")
            .map_err(|e| TraceletError::Database(e.to_string()))?;
        
        let iter = stmt.query_map([], |row| {
            Ok(CorePrivacyZone {
                identifier: row.get(0)?,
                latitude: row.get(1)?,
                longitude: row.get(2)?,
                radius: row.get(3)?,
                action: row.get(4)?,
                degraded_accuracy_meters: row.get(5)?,
            })
        }).map_err(|e| TraceletError::Database(e.to_string()))?;

        let mut zones = Vec::new();
        for z in iter {
            if let Ok(zone) = z {
                zones.push(zone);
            }
        }
        Ok(zones)
    }

    // --- Geofences ---

    /// Retrieves all registered geofences from the database, parsing JSON-serialized vertices.
    /// Resolves polygon geofences containing multiple coordinate vertices as well as circular ones.
    pub fn get_geofences(&self) -> Result<Vec<CoreGeofence>, TraceletError> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare("SELECT identifier, latitude, longitude, radius, vertices FROM geofences")
            .map_err(|e| TraceletError::Database(e.to_string()))?;

        let iter = stmt.query_map([], |row| {
            let identifier: String = row.get(0)?;
            let latitude: f64 = row.get(1)?;
            let longitude: f64 = row.get(2)?;
            let radius: f64 = row.get(3)?;
            let vertices_str: Option<String> = row.get(4)?;

            let mut vertices = Vec::new();
            if let Some(s) = vertices_str {
                if !s.is_empty() {
                    // Vertices are stored in SQLite as JSON-serialized coordinate arrays: [[lat, lng], [lat, lng], ...]
                    if let Ok(raw_vertices) = serde_json::from_str::<Vec<Vec<f64>>>(&s) {
                        for item in raw_vertices {
                            if item.len() >= 2 {
                                vertices.push(Coordinate {
                                    lat: item[0],
                                    lng: item[1],
                                });
                            }
                        }
                    }
                }
            }

            Ok(CoreGeofence {
                identifier,
                latitude,
                longitude,
                radius,
                vertices,
            })
        }).map_err(|e| TraceletError::Database(e.to_string()))?;

        let mut geofences = Vec::new();
        for gf in iter {
            if let Ok(gf_val) = gf {
                geofences.push(gf_val);
            }
        }
        Ok(geofences)
    }

    // --- Audit Trail ---
    
    /// Inserts or replaces a validated tamper-proof cryptographic audit trail record.
    pub fn insert_audit_trail(&self, uuid: &str, hash: &str, prev_hash: &str, index: i32) -> Result<(), TraceletError> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "INSERT OR REPLACE INTO audit_trail (uuid, audit_hash, audit_previous_hash, audit_chain_index) VALUES (?1, ?2, ?3, ?4)",
            params![uuid, hash, prev_hash, index]
        ).map_err(|e| TraceletError::Database(e.to_string()))?;
        Ok(())
    }

    /// Retrieves all audit trail records, ordered sequentially by their chain index.
    pub fn get_audit_trail(&self) -> Result<Vec<DbAuditRecord>, TraceletError> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare("SELECT uuid, audit_hash, audit_previous_hash, audit_chain_index, audit_created_at FROM audit_trail ORDER BY audit_chain_index ASC")
            .map_err(|e| TraceletError::Database(e.to_string()))?;

        let iter = stmt.query_map([], |row| {
            Ok(DbAuditRecord {
                uuid: row.get(0)?,
                audit_hash: row.get(1)?,
                audit_previous_hash: row.get(2)?,
                audit_chain_index: row.get(3)?,
                audit_created_at: row.get(4)?,
            })
        }).map_err(|e| TraceletError::Database(e.to_string()))?;

        let mut records = Vec::new();
        for r in iter {
            if let Ok(record) = r {
                records.push(record);
            }
        }
        Ok(records)
    }

    // --- Logs ---

    /// Inserts a log entry into the database.
    pub fn insert_log(&self, level: &str, message: &str, source: &str) -> Result<(), TraceletError> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "INSERT INTO logs (level, message, source) VALUES (?1, ?2, ?3)",
            params![level, message, source]
        ).map_err(|e| TraceletError::Database(e.to_string()))?;
        Ok(())
    }

    /// Retrieves a batch of log entries, up to `limit`.
    pub fn get_logs(&self, limit: i32) -> Result<Vec<LogEntry>, TraceletError> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare("SELECT id, level, message, timestamp, source FROM logs ORDER BY id DESC LIMIT ?1")
            .map_err(|e| TraceletError::Database(e.to_string()))?;

        let iter = stmt.query_map([limit], |row| {
            Ok(LogEntry {
                id: row.get(0)?,
                level: row.get(1)?,
                message: row.get(2)?,
                timestamp: row.get(3)?,
                source: row.get(4)?,
            })
        }).map_err(|e| TraceletError::Database(e.to_string()))?;

        let mut records = Vec::new();
        for r in iter {
            if let Ok(record) = r {
                records.push(record);
            }
        }
        Ok(records)
    }

    /// Clears all log entries from the database.
    pub fn clear_logs(&self) -> Result<(), TraceletError> {
        let conn = self.conn.lock().unwrap();
        conn.execute("DELETE FROM logs", [])
            .map_err(|e| TraceletError::Database(e.to_string()))?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_unencrypted_insert_and_read() {
        let db = DatabaseManager::new(":memory:").expect("Failed to create in-memory db");
        // Ensure no key is set
        db.set_encryption_key("");
        
        db.insert_location(37.7749, -122.4194, 10.0, 1.5, 90.0, 15.0, false, "walking", None).unwrap();
        
        let locations = db.get_locations_batch(10).unwrap();
        assert_eq!(locations.len(), 1);
        let loc = &locations[0];
        assert_eq!(loc.latitude, 37.7749);
        assert_eq!(loc.longitude, -122.4194);
        assert_eq!(loc.activity, "walking");
    }

    #[test]
    fn test_encrypted_insert_and_read() {
        let db = DatabaseManager::new(":memory:").expect("Failed to create in-memory db");
        
        // Set an encryption key
        let test_key = "my_super_secret_encryption_key_!";
        db.set_encryption_key(test_key);
        
        db.insert_location(40.7128, -74.0060, 5.0, 0.0, 0.0, 10.0, true, "running", None).unwrap();
        
        let locations = db.get_locations_batch(10).unwrap();
        assert_eq!(locations.len(), 1);
        let loc = &locations[0];
        assert_eq!(loc.latitude, 40.7128);
        assert_eq!(loc.longitude, -74.0060);
        assert_eq!(loc.activity, "running");
        assert_eq!(loc.is_mock, true);
    }

    #[test]
    fn test_graceful_reading_mixed_records() {
        let db = DatabaseManager::new(":memory:").expect("Failed to create in-memory db");
        
        // Insert unencrypted
        db.set_encryption_key("");
        db.insert_location(1.0, 1.0, 1.0, 1.0, 1.0, 1.0, false, "unencrypted", None).unwrap();
        
        // Turn encryption ON
        let test_key = "another_secret_key_1234567890!!!";
        db.set_encryption_key(test_key);
        db.insert_location(2.0, 2.0, 2.0, 2.0, 2.0, 2.0, false, "encrypted", None).unwrap();
        
        let locations = db.get_locations_batch(10).unwrap();
        assert_eq!(locations.len(), 2);
        
        // Both should be readable!
        assert_eq!(locations[0].latitude, 1.0);
        assert_eq!(locations[0].activity, "unencrypted");
        
        assert_eq!(locations[1].latitude, 2.0);
        assert_eq!(locations[1].activity, "encrypted");
    }

    #[test]
    fn test_geofence_crud() {
        let db = DatabaseManager::new(":memory:").expect("Failed to create in-memory db");
        
        // Insert a circular geofence
        db.insert_geofence("home_zone", 37.0, -122.0, 150.0).unwrap();
        
        let count: i32 = db.conn.lock().unwrap().query_row("SELECT COUNT(*) FROM geofences", [], |r| r.get(0)).unwrap();
        assert_eq!(count, 1);

        // Manually update/test with JSON-serialized vertices (polygons)
        db.conn.lock().unwrap().execute(
            "UPDATE geofences SET vertices = ?1 WHERE identifier = 'home_zone'",
            params!["[[37.0, -122.0], [37.1, -122.1], [37.2, -122.2]]"]
        ).unwrap();

        // Verify retrieval of geofences and parsing of vertices
        let geofences = db.get_geofences().unwrap();
        assert_eq!(geofences.len(), 1);
        assert_eq!(geofences[0].identifier, "home_zone");
        assert_eq!(geofences[0].vertices.len(), 3);
        assert_eq!(geofences[0].vertices[0].lat, 37.0);
        assert_eq!(geofences[0].vertices[2].lng, -122.2);
        
        // Delete the geofence
        db.delete_geofence("home_zone").unwrap();
        let count_after_delete: i32 = db.conn.lock().unwrap().query_row("SELECT COUNT(*) FROM geofences", [], |r| r.get(0)).unwrap();
        assert_eq!(count_after_delete, 0);
        
        // Batch inserting and clearing multiple
        db.insert_geofence("work", 38.0, -121.0, 50.0).unwrap();
        db.insert_geofence("gym", 39.0, -120.0, 100.0).unwrap();
        db.clear_geofences().unwrap();
        let count_after_clear: i32 = db.conn.lock().unwrap().query_row("SELECT COUNT(*) FROM geofences", [], |r| r.get(0)).unwrap();
        assert_eq!(count_after_clear, 0);
    }

    #[test]
    fn test_privacy_zone_crud() {
        let db = DatabaseManager::new(":memory:").expect("Failed to create in-memory db");
        
        // Insert a privacy zone with custom action (DEGRADE = 1) and precision grid accuracy (500m)
        db.insert_privacy_zone("private_home", 45.0, -90.0, 500.0, 1, 500.0).unwrap();
        
        let count: i32 = db.conn.lock().unwrap().query_row("SELECT COUNT(*) FROM privacy_zones", [], |r| r.get(0)).unwrap();
        assert_eq!(count, 1);

        // Verify retrieving privacy zones matches the inserted properties
        let zones = db.get_privacy_zones().unwrap();
        assert_eq!(zones.len(), 1);
        assert_eq!(zones[0].identifier, "private_home");
        assert_eq!(zones[0].action, 1);
        assert_eq!(zones[0].degraded_accuracy_meters, 500.0);
        
        db.delete_privacy_zone("private_home").unwrap();
        let count_after: i32 = db.conn.lock().unwrap().query_row("SELECT COUNT(*) FROM privacy_zones", [], |r| r.get(0)).unwrap();
        assert_eq!(count_after, 0);
    }

    #[test]
    fn test_audit_trail_crud() {
        let db = DatabaseManager::new(":memory:").expect("Failed to create in-memory db");
        
        db.insert_audit_trail("uuid-1234", "hash1", "hash0", 1).unwrap();
        
        let count: i32 = db.conn.lock().unwrap().query_row("SELECT COUNT(*) FROM audit_trail", [], |r| r.get(0)).unwrap();
        assert_eq!(count, 1);

        // Verify fetching audit trail sequential list
        let records = db.get_audit_trail().unwrap();
        assert_eq!(records.len(), 1);
        assert_eq!(records[0].uuid, "uuid-1234");
        assert_eq!(records[0].audit_hash, "hash1");
        assert_eq!(records[0].audit_chain_index, 1);
        
        // Verify upsert (REPLACE) works for same UUID
        db.insert_audit_trail("uuid-1234", "hash1-updated", "hash0", 1).unwrap();
        let count_after_upsert: i32 = db.conn.lock().unwrap().query_row("SELECT COUNT(*) FROM audit_trail", [], |r| r.get(0)).unwrap();
        assert_eq!(count_after_upsert, 1); // Should overwrite, not add another row
        
        let hash: String = db.conn.lock().unwrap().query_row("SELECT audit_hash FROM audit_trail WHERE uuid = 'uuid-1234'", [], |r| r.get(0)).unwrap();
        assert_eq!(hash, "hash1-updated");
    }

    #[test]
    fn test_logs_crud() {
        let db = DatabaseManager::new(":memory:").expect("Failed to create in-memory db");
        
        db.insert_log("INFO", "Test log message 1", "plugin").unwrap();
        db.insert_log("ERROR", "Test log message 2", "dart").unwrap();
        
        let count: i32 = db.conn.lock().unwrap().query_row("SELECT COUNT(*) FROM logs", [], |r| r.get(0)).unwrap();
        assert_eq!(count, 2);

        // Fetch logs (should be ordered DESC by id)
        let logs = db.get_logs(10).unwrap();
        assert_eq!(logs.len(), 2);
        assert_eq!(logs[0].level, "ERROR");
        assert_eq!(logs[0].message, "Test log message 2");
        assert_eq!(logs[0].source, "dart");
        
        assert_eq!(logs[1].level, "INFO");
        
        // Clear logs
        db.clear_logs().unwrap();
        let count_after_clear: i32 = db.conn.lock().unwrap().query_row("SELECT COUNT(*) FROM logs", [], |r| r.get(0)).unwrap();
        assert_eq!(count_after_clear, 0);
    }
}
