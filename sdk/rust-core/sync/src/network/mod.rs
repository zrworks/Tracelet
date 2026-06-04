use std::collections::HashMap;
use tracelet_core::error::TraceletError;
use reqwest::{Client, Method, header::{HeaderMap, HeaderName, HeaderValue}};
use serde_json::json;
use std::str::FromStr;
use std::time::Duration;

#[derive(uniffi::Record, Debug, Clone)]
pub struct SyncHttpConfig {
    pub url: Option<String>,
    pub method: i32,
    pub headers: HashMap<String, String>,
    pub batch_sync: bool,
    pub max_batch_size: i32,
    pub auto_sync: bool,
    pub max_retries: i32,
    pub retry_backoff_base: i32,
    pub retry_backoff_cap: i32,
    pub ssl_pinning_certificates: Option<Vec<String>>,
    pub http_root_property: Option<String>,
    pub params: Option<HashMap<String, String>>,
    pub extras: Option<HashMap<String, String>>,
    pub disable_auto_sync_on_cellular: bool,
    pub enable_delta_compression: bool,
    pub delta_coordinate_precision: i32,
    pub locations_order_direction: i32,
}

#[derive(uniffi::Record, Debug, Clone)]
pub struct SyncLocationRecord {
    pub id: i64,
    pub uuid: Option<String>,
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

#[derive(uniffi::Object)]
pub struct SyncManager {
    client: Client,
}

#[uniffi::export]
impl SyncManager {
    #[uniffi::constructor]
    pub fn new() -> Self {
        Self {
            client: Client::builder()
                .timeout(Duration::from_secs(60))
                .build()
                .unwrap_or_else(|_| Client::new()),
        }
    }

    /// Performs a synchronous/blocking sync of a batch of location records.
    /// Returns the number of successfully synced records.
    pub fn sync_batch_blocking(&self, config: SyncHttpConfig, records: Vec<SyncLocationRecord>) -> Result<u32, TraceletError> {
        let rt = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .map_err(|e| TraceletError::Network(e.to_string()))?;
        let res = rt.block_on(self.sync_batch(&config, &records))?;
        Ok(res as u32)
    }
}

impl SyncManager {
    pub(crate) fn build_sync_payload(config: &SyncHttpConfig, records: &[SyncLocationRecord]) -> serde_json::Value {
        let mut payload = if config.batch_sync {
            let json_records: Vec<_> = records.iter().map(|r| {
                let mut base_json = json!({
                    "id": r.id,
                    "uuid": r.uuid,
                    "timestamp": r.timestamp,
                    "coords": {
                        "latitude": r.latitude,
                        "longitude": r.longitude,
                        "accuracy": r.accuracy,
                        "speed": r.speed,
                        "heading": r.heading,
                        "altitude": r.altitude,
                    },
                    "is_mock": r.is_mock,
                    "activity": r.activity
                });
                let record_route_context: Option<serde_json::Value> = r.route_context.as_ref()
                    .and_then(|rc| serde_json::from_str(rc).ok());
                    
                if let Some(ref rc) = record_route_context {
                    if let Some(obj) = base_json.as_object_mut() {
                        if let Some(rc_obj) = rc.as_object() {
                            for (k, v) in rc_obj.iter() {
                                obj.insert(k.clone(), v.clone());
                            }
                        }
                    }
                }
                base_json
            }).collect();
            let root_key = config.http_root_property.as_deref().unwrap_or("location");
            let mut map = serde_json::Map::new();
            map.insert(root_key.to_string(), serde_json::Value::Array(json_records));
            serde_json::Value::Object(map)
        } else {
            // For non-batch, just send the latest record
            let r = records.last().unwrap();
            let mut base_json = json!({
                "id": r.id,
                "uuid": r.uuid,
                "timestamp": r.timestamp,
                "coords": {
                    "latitude": r.latitude,
                    "longitude": r.longitude,
                    "accuracy": r.accuracy,
                    "speed": r.speed,
                    "heading": r.heading,
                    "altitude": r.altitude,
                },
                "is_mock": r.is_mock,
                "activity": r.activity
            });
            let record_route_context: Option<serde_json::Value> = r.route_context.as_ref()
                .and_then(|rc| serde_json::from_str(rc).ok());
                
            if let Some(ref rc) = record_route_context {
                if let Some(obj) = base_json.as_object_mut() {
                    if let Some(rc_obj) = rc.as_object() {
                        for (k, v) in rc_obj.iter() {
                            obj.insert(k.clone(), v.clone());
                        }
                    }
                }
            }
            let root_key = config.http_root_property.as_deref().unwrap_or("location");
            let mut map = serde_json::Map::new();
            map.insert(root_key.to_string(), base_json);
            serde_json::Value::Object(map)
        };

        // Attach params and extras to the root of the payload
        if let Some(obj) = payload.as_object_mut() {
            if let Some(params) = &config.params {
                let mut params_obj = serde_json::Map::new();
                for (k, v) in params {
                    let parsed_val = serde_json::from_str(v).unwrap_or_else(|_| serde_json::Value::String(v.clone()));
                    params_obj.insert(k.clone(), parsed_val);
                }
                obj.insert("params".to_string(), serde_json::Value::Object(params_obj));
            }
            if let Some(extras) = &config.extras {
                let mut extras_obj = serde_json::Map::new();
                for (k, v) in extras {
                    let parsed_val = serde_json::from_str(v).unwrap_or_else(|_| serde_json::Value::String(v.clone()));
                    extras_obj.insert(k.clone(), parsed_val);
                }
                obj.insert("extras".to_string(), serde_json::Value::Object(extras_obj));
            }
        }
        
        payload
    }

    /// Performs an asynchronous sync of a batch of location records.
    /// Returns the number of successfully synced records.
    pub async fn sync_batch(&self, config: &SyncHttpConfig, records: &[SyncLocationRecord]) -> Result<i32, TraceletError> {
        let url = match &config.url {
            Some(u) if !u.is_empty() => u,
            _ => {
                tracelet_core::logger::warn("[Rust Core] ⚠️ Sync skipped: HTTP sync URL is not configured in EngineConfig.");
                return Err(TraceletError::Config("HTTP sync URL not configured".into()));
            }
        };

        if records.is_empty() {
            tracelet_core::logger::info("[Rust Core] ℹ️ Sync skipped: Location batch is empty.");
            return Ok(0);
        }

        tracelet_core::logger::info(&format!("[Rust Core] 🌐 HTTP Sync batch size: {} record(s). Target URL: {}", records.len(), url));

        // Prepare Headers
        let mut header_map = HeaderMap::new();
        header_map.insert("Content-Type", HeaderValue::from_static("application/json"));
        for (k, v) in &config.headers {
            if let (Ok(name), Ok(value)) = (HeaderName::from_str(k), HeaderValue::from_str(v)) {
                header_map.insert(name, value);
            }
        }


        // Prepare Payload
        let payload = Self::build_sync_payload(config, records);

        let method = if config.method == 1 { Method::PUT } else { Method::POST };

        // Handle SSL Pinning dynamically if configured
        let mut active_client = self.client.clone();
        if let Some(certs) = &config.ssl_pinning_certificates {
            if !certs.is_empty() {
                let mut builder = Client::builder()
                    .timeout(Duration::from_secs(60))
                    .tls_built_in_root_certs(false); // Force strict pinning

                for cert_str in certs {
                    if let Ok(cert) = reqwest::Certificate::from_pem(cert_str.as_bytes()) {
                        builder = builder.add_root_certificate(cert);
                    } else if let Ok(cert) = reqwest::Certificate::from_der(cert_str.as_bytes()) {
                        builder = builder.add_root_certificate(cert);
                    }
                }
                active_client = builder.build().unwrap_or_else(|_| self.client.clone());
            }
        }

        let max_retries = if config.max_retries < 0 { 0 } else { config.max_retries as u32 };
        let backoff_base = if config.retry_backoff_base <= 0 { 1000 } else { config.retry_backoff_base as u64 };
        let backoff_cap = if config.retry_backoff_cap <= 0 { 10000 } else { config.retry_backoff_cap as u64 };
        
        let mut attempt = 0;
        loop {
            tracelet_core::logger::info(&format!("[Rust Core] 🌐 Sending HTTP {} request... (Attempt {}/{})", method, attempt + 1, max_retries + 1));
            // Execute Request
            let request = active_client.request(method.clone(), url)
                .headers(header_map.clone())
                .json(&payload);

            match request.send().await {
                Ok(response) => {
                    let status = response.status();
                    if status.is_success() {
                        tracelet_core::logger::info(&format!("[Rust Core] ✅ HTTP Sync succeeded! Status: {}, successfully synced {} location(s).", status, records.len()));
                        return Ok(records.len() as i32);
                    } else if status.is_client_error() {
                        // Do not retry 4xx errors
                        tracelet_core::logger::error(&format!("[Rust Core] ❌ HTTP Sync failed with client error (4xx): {}. Aborting sync retries.", status));
                        return Err(TraceletError::Network(format!("HTTP Error: {}", status)));
                    } else {
                        // 5xx errors can be retried
                        tracelet_core::logger::error(&format!("[Rust Core] ⚠️ HTTP Sync received server error (5xx): {}.", status));
                        if attempt >= max_retries {
                            tracelet_core::logger::error("[Rust Core] ❌ Max retries reached. Permanent sync failure.");
                            return Err(TraceletError::Network(format!("HTTP Error: {}", status)));
                        }
                    }
                },
                Err(e) => {
                    tracelet_core::logger::error(&format!("[Rust Core] ⚠️ HTTP Sync connection error occurred: {}", e));
                    if attempt >= max_retries {
                        tracelet_core::logger::error("[Rust Core] ❌ Max retries reached. Permanent sync failure.");
                        return Err(TraceletError::Network(e.to_string()));
                    }
                }
            }
            
            // Calculate exponential backoff
            let multiplier = 2_u64.pow(attempt);
            let delay_ms = std::cmp::min(backoff_base * multiplier, backoff_cap);
            tracelet_core::logger::info(&format!("[Rust Core] 🔄 Retrying HTTP Sync in {}ms...", delay_ms));
            tokio::time::sleep(Duration::from_millis(delay_ms)).await;
            attempt += 1;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::Value;

    fn get_test_record() -> SyncLocationRecord {
        SyncLocationRecord {
            id: 1,
            uuid: Some("test-uuid-1234".to_string()),
            timestamp: "2023-01-01T00:00:00Z".to_string(),
            latitude: 10.0,
            longitude: 20.0,
            accuracy: 5.0,
            speed: 15.0,
            heading: 90.0,
            altitude: 100.0,
            is_mock: false,
            activity: "moving".to_string(),
            route_context: None,
        }
    }

    fn get_test_config(batch_sync: bool) -> SyncHttpConfig {
        SyncHttpConfig {
            url: Some("http://localhost".to_string()),
            method: 0,
            headers: HashMap::new(),
            batch_sync,
            max_batch_size: 10,
            auto_sync: true,
            max_retries: 3,
            retry_backoff_base: 1000,
            retry_backoff_cap: 10000,
            ssl_pinning_certificates: None,
            http_root_property: None,
            params: None,
            extras: None,
            disable_auto_sync_on_cellular: false,
            enable_delta_compression: false,
            delta_coordinate_precision: 5,
            locations_order_direction: 0,
        }
    }

    #[test]
    fn test_build_sync_payload_batch_includes_uuid() {
        let config = get_test_config(true);
        let records = vec![get_test_record()];
        
        let payload = SyncManager::build_sync_payload(&config, &records);
        
        // Assert payload structure for batch
        let locations = payload.get("location").expect("Missing 'location' array in payload")
            .as_array().expect("'location' should be an array");
            
        assert_eq!(locations.len(), 1);
        let first_loc = &locations[0];
        
        // Assert uuid is mapped correctly
        assert_eq!(first_loc.get("uuid").and_then(Value::as_str), Some("test-uuid-1234"));
        assert_eq!(first_loc.get("id").and_then(Value::as_i64), Some(1));
    }

    #[test]
    fn test_build_sync_payload_single_includes_uuid() {
        let config = get_test_config(false);
        let records = vec![get_test_record()];
        
        let payload = SyncManager::build_sync_payload(&config, &records);
        
        // Assert payload structure for non-batch
        let location = payload.get("location").expect("Missing 'location' object in payload");
            
        // Assert uuid is mapped correctly
        assert_eq!(location.get("uuid").and_then(Value::as_str), Some("test-uuid-1234"));
        assert_eq!(location.get("id").and_then(Value::as_i64), Some(1));
    }

    #[test]
    fn test_build_sync_payload_merges_route_context_audit_hash() {
        let config = get_test_config(true);
        let mut record = get_test_record();
        
        // Inject an audit_hash into the route_context (simulating iOS/Android behaviour)
        record.route_context = Some(r#"{"custom":"{app: tracelet-example}","audit_hash":"hash123","audit_chain_index":42}"#.to_string());
        
        let records = vec![record];
        let payload = SyncManager::build_sync_payload(&config, &records);
        
        let locations = payload.get("location").expect("Missing 'location' array in payload")
            .as_array().expect("'location' should be an array");
            
        assert_eq!(locations.len(), 1);
        let first_loc = &locations[0];
        
        // The audit_hash should be merged directly into the location JSON object
        assert_eq!(first_loc.get("audit_hash").and_then(Value::as_str), Some("hash123"), "audit_hash was not merged into the sync payload!");
        assert_eq!(first_loc.get("audit_chain_index").and_then(Value::as_i64), Some(42), "audit_chain_index was not merged into the sync payload!");
        assert_eq!(first_loc.get("custom").and_then(Value::as_str), Some("{app: tracelet-example}"));
    }

    #[test]
    fn test_build_sync_payload_uses_custom_root_property_and_extras() {
        let mut config = get_test_config(true); // uses "events" and extras
        config.http_root_property = Some("events".to_string());
        config.extras = Some(HashMap::from([("custom_meta".to_string(), "123".to_string())]));
        let records = vec![get_test_record()];
        
        let payload = SyncManager::build_sync_payload(&config, &records);
        
        // Assert payload uses custom root "events" instead of "location"
        let locations = payload.get("events").expect("Missing custom root 'events' array in payload")
            .as_array().expect("'events' should be an array");
            
        assert_eq!(locations.len(), 1);
        
        // Assert extras are attached at the root level of the payload as an object
        let extras = payload.get("extras").expect("Missing 'extras' object in payload");
        assert_eq!(extras.get("custom_meta").and_then(serde_json::Value::as_i64), Some(123), "extras were not attached to the payload!");
    }
}
