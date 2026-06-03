import re

db_file = "sdk/rust-core/core/src/database/mod.rs"
with open(db_file, "r") as f:
    content = f.read()

# Add get_location_for_audit
new_func = """    pub fn get_location_for_audit(&self, uuid: &str) -> Result<Option<DbLocationRecord>, TraceletError> {
        let conn = self.conn.lock().unwrap();
        let sql = "SELECT id, uuid, timestamp, latitude, longitude, accuracy, speed, heading, altitude, is_mock, activity, encrypted_payload, route_context FROM location_events WHERE uuid = ?1 LIMIT 1";
        
        let mut stmt = conn.prepare(sql).map_err(|e| TraceletError::Database(e.to_string()))?;
        
        let mut iter = stmt.query_map([uuid], |row| {
            let mut lat: f64 = row.get(3)?;
            let mut lng: f64 = row.get(4)?;
            let mut acc: f64 = row.get(5)?;
            let mut speed: f64 = row.get(6)?;
            let mut heading: f64 = row.get(7)?;
            let mut altitude: f64 = row.get(8)?;
            let mut is_mock_val: i32 = row.get(9)?;
            let mut activity_val: String = row.get(10)?;
            
            let encrypted_payload: Option<Vec<u8>> = row.get(11).unwrap_or(None);
            let mut route_context: Option<String> = row.get(12).unwrap_or(None);
            
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
                uuid: row.get(1).unwrap_or(None),
                timestamp: row.get(2)?,
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

        if let Some(result) = iter.next() {
            return match result {
                Ok(r) => Ok(Some(r)),
                Err(e) => Err(TraceletError::Database(e.to_string())),
            };
        }
        
        Ok(None)
    }
"""

content = content.replace("    pub fn get_locations_count(&self) -> Result<i32, TraceletError> {", new_func + "\n    pub fn get_locations_count(&self) -> Result<i32, TraceletError> {")

with open(db_file, "w") as f:
    f.write(content)
