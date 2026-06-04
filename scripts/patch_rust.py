import re

db_file = "sdk/rust-core/core/src/database/mod.rs"
with open(db_file, "r") as f:
    content = f.read()

# 1. Add uuid to DbLocationRecord
content = content.replace("pub struct DbLocationRecord {\n    pub id: i64,", "pub struct DbLocationRecord {\n    pub id: i64,\n    pub uuid: Option<String>,")

# 2. Add uuid to CREATE TABLE location_events
content = content.replace("id INTEGER PRIMARY KEY AUTOINCREMENT,\n                timestamp TEXT NOT NULL,", "id INTEGER PRIMARY KEY AUTOINCREMENT,\n                uuid TEXT UNIQUE,\n                timestamp TEXT NOT NULL,")

# 3. Add ALTER TABLE for uuid
content = content.replace("let _ = conn.execute(\"ALTER TABLE location_events ADD COLUMN encrypted_payload BLOB\", []);", "let _ = conn.execute(\"ALTER TABLE location_events ADD COLUMN uuid TEXT UNIQUE\", []);\n        let _ = conn.execute(\"ALTER TABLE location_events ADD COLUMN encrypted_payload BLOB\", []);")

# 4. Update insert_location signature
content = content.replace("pub fn insert_location(&self, lat: f64, lng: f64, acc: f64, speed: f64, heading: f64, altitude: f64, is_mock: bool, activity: &str, route_context: Option<String>, timestamp_override: Option<String>) -> Result<i64, TraceletError> {", "pub fn insert_location(&self, uuid: Option<String>, lat: f64, lng: f64, acc: f64, speed: f64, heading: f64, altitude: f64, is_mock: bool, activity: &str, route_context: Option<String>, timestamp_override: Option<String>) -> Result<i64, TraceletError> {")

# 5. Update insert_location query (encrypted)
content = content.replace("\"INSERT INTO location_events (timestamp, latitude, longitude, accuracy, speed, heading, altitude, is_mock, activity, encrypted_payload, route_context)\n                     VALUES (?1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0, '', ?2, ?3)\",\n                    params![timestamp, payload, route_context]", "\"INSERT INTO location_events (uuid, timestamp, latitude, longitude, accuracy, speed, heading, altitude, is_mock, activity, encrypted_payload, route_context)\n                     VALUES (?1, ?2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0, '', ?3, ?4)\",\n                    params![uuid, timestamp, payload, route_context]")

# 6. Update insert_location query (unencrypted)
content = content.replace("\"INSERT INTO location_events (timestamp, latitude, longitude, accuracy, speed, heading, altitude, is_mock, activity, encrypted_payload, route_context)\n             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, NULL, ?10)\",\n            params![timestamp, lat, lng, acc, speed, heading, altitude, if is_mock { 1 } else { 0 }, activity, route_context]", "\"INSERT INTO location_events (uuid, timestamp, latitude, longitude, accuracy, speed, heading, altitude, is_mock, activity, encrypted_payload, route_context)\n             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, NULL, ?11)\",\n            params![uuid, timestamp, lat, lng, acc, speed, heading, altitude, if is_mock { 1 } else { 0 }, activity, route_context]")

# 7. Update get_locations_batch query
content = content.replace("SELECT id, timestamp, latitude, longitude, accuracy, speed, heading, altitude, is_mock, activity, encrypted_payload, route_context FROM location_events WHERE 1=1", "SELECT id, uuid, timestamp, latitude, longitude, accuracy, speed, heading, altitude, is_mock, activity, encrypted_payload, route_context FROM location_events WHERE 1=1")

# 8. Update get_locations_batch mapping
content = content.replace("let iter = stmt.query_map(rusqlite::params_from_iter(params), |row| {\n            let mut lat: f64 = row.get(2)?;", "let iter = stmt.query_map(rusqlite::params_from_iter(params), |row| {\n            let mut lat: f64 = row.get(3)?;\n            let mut lng: f64 = row.get(4)?;\n            let mut acc: f64 = row.get(5)?;\n            let mut speed: f64 = row.get(6)?;\n            let mut heading: f64 = row.get(7)?;\n            let mut altitude: f64 = row.get(8)?;\n            let mut is_mock_val: i32 = row.get(9)?;\n            let mut activity_val: String = row.get(10)?;\n            \n            let encrypted_payload: Option<Vec<u8>> = row.get(11).unwrap_or(None);\n            let mut route_context: Option<String> = row.get(12).unwrap_or(None);")

content = content.replace("let mut lng: f64 = row.get(3)?;\n            let mut acc: f64 = row.get(4)?;\n            let mut speed: f64 = row.get(5)?;\n            let mut heading: f64 = row.get(6)?;\n            let mut altitude: f64 = row.get(7)?;\n            let mut is_mock_val: i32 = row.get(8)?;\n            let mut activity_val: String = row.get(9)?;\n            \n            let encrypted_payload: Option<Vec<u8>> = row.get(10).unwrap_or(None);\n            let mut route_context: Option<String> = row.get(11).unwrap_or(None);", "")

content = content.replace("Ok(DbLocationRecord {\n                id: row.get(0)?,\n                timestamp: row.get(1)?,", "Ok(DbLocationRecord {\n                id: row.get(0)?,\n                uuid: row.get(1).unwrap_or(None),\n                timestamp: row.get(2)?,")

# 9. Update tests in mod.rs
content = content.replace("db.insert_location(37.7749", "db.insert_location(None, 37.7749")
content = content.replace("db.insert_location(40.7128", "db.insert_location(None, 40.7128")
content = content.replace("db.insert_location(1.0", "db.insert_location(None, 1.0")
content = content.replace("db.insert_location(2.0", "db.insert_location(None, 2.0")
content = content.replace("db.insert_location(3.0", "db.insert_location(None, 3.0")

with open(db_file, "w") as f:
    f.write(content)
