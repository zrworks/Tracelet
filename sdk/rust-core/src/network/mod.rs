use crate::config::HttpConfig;
use crate::database::DbLocationRecord;
use reqwest::{Client, Method, header::{HeaderMap, HeaderName, HeaderValue}};
use serde_json::json;
use std::str::FromStr;
use std::time::Duration;
use crate::error::TraceletError;

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
    pub fn sync_batch_blocking(&self, config: HttpConfig, records: Vec<DbLocationRecord>, route_context: Option<String>) -> Result<i32, TraceletError> {
        let rt = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .map_err(|e| TraceletError::Network(e.to_string()))?;
        rt.block_on(self.sync_batch(&config, &records, route_context))
    }
}

impl SyncManager {
    /// Performs an asynchronous sync of a batch of location records.
    /// Returns the number of successfully synced records.
    pub async fn sync_batch(&self, config: &HttpConfig, records: &[DbLocationRecord], route_context: Option<String>) -> Result<i32, TraceletError> {
        let url = match &config.url {
            Some(u) if !u.is_empty() => u,
            _ => {
                crate::logger::warn("[Rust Core] ⚠️ Sync skipped: HTTP sync URL is not configured in EngineConfig.");
                return Err(TraceletError::Config("HTTP sync URL not configured".into()));
            }
        };

        if records.is_empty() {
            crate::logger::info("[Rust Core] ℹ️ Sync skipped: Location batch is empty.");
            return Ok(0);
        }

        crate::logger::info(&format!("[Rust Core] 🌐 HTTP Sync batch size: {} record(s). Target URL: {}", records.len(), url));

        // Prepare Headers
        let mut header_map = HeaderMap::new();
        header_map.insert("Content-Type", HeaderValue::from_static("application/json"));
        for (k, v) in &config.headers {
            if let (Ok(name), Ok(value)) = (HeaderName::from_str(k), HeaderValue::from_str(v)) {
                header_map.insert(name, value);
            }
        }

        // Parse the route_context if provided
        let route_context_json: Option<serde_json::Value> = route_context
            .and_then(|rc| serde_json::from_str(&rc).ok());

        // Prepare Payload
        let payload = if config.batch_sync {
            let json_records: Vec<_> = records.iter().map(|r| {
                let mut base_json = json!({
                    "id": r.id,
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
                if let Some(ref rc) = route_context_json {
                    if let Some(obj) = base_json.as_object_mut() {
                        if let Some(rc_obj) = rc.as_object() {
                            for (k, v) in rc_obj {
                                obj.insert(k.clone(), v.clone());
                            }
                        }
                    }
                }
                base_json
            }).collect();
            json!({ "location": json_records })
        } else {
            // For non-batch, just send the latest record
            let r = records.last().unwrap();
            let mut base_json = json!({
                "id": r.id,
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
            if let Some(ref rc) = route_context_json {
                if let Some(obj) = base_json.as_object_mut() {
                    if let Some(rc_obj) = rc.as_object() {
                        for (k, v) in rc_obj {
                            obj.insert(k.clone(), v.clone());
                        }
                    }
                }
            }
            json!({ "location": base_json })
        };

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
            crate::logger::info(&format!("[Rust Core] 🌐 Sending HTTP {} request... (Attempt {}/{})", method, attempt + 1, max_retries + 1));
            // Execute Request
            let request = active_client.request(method.clone(), url)
                .headers(header_map.clone())
                .json(&payload);

            match request.send().await {
                Ok(response) => {
                    let status = response.status();
                    if status.is_success() {
                        crate::logger::info(&format!("[Rust Core] ✅ HTTP Sync succeeded! Status: {}, successfully synced {} location(s).", status, records.len()));
                        return Ok(records.len() as i32);
                    } else if status.is_client_error() {
                        // Do not retry 4xx errors
                        crate::logger::error(&format!("[Rust Core] ❌ HTTP Sync failed with client error (4xx): {}. Aborting sync retries.", status));
                        return Err(TraceletError::Network(format!("HTTP Error: {}", status)));
                    } else {
                        // 5xx errors can be retried
                        crate::logger::error(&format!("[Rust Core] ⚠️ HTTP Sync received server error (5xx): {}.", status));
                        if attempt >= max_retries {
                            crate::logger::error("[Rust Core] ❌ Max retries reached. Permanent sync failure.");
                            return Err(TraceletError::Network(format!("HTTP Error: {}", status)));
                        }
                    }
                },
                Err(e) => {
                    crate::logger::error(&format!("[Rust Core] ⚠️ HTTP Sync connection error occurred: {}", e));
                    if attempt >= max_retries {
                        crate::logger::error("[Rust Core] ❌ Max retries reached. Permanent sync failure.");
                        return Err(TraceletError::Network(e.to_string()));
                    }
                }
            }
            
            // Calculate exponential backoff
            let multiplier = 2_u64.pow(attempt);
            let delay_ms = std::cmp::min(backoff_base * multiplier, backoff_cap);
            crate::logger::info(&format!("[Rust Core] 🔄 Retrying HTTP Sync in {}ms...", delay_ms));
            tokio::time::sleep(Duration::from_millis(delay_ms)).await;
            attempt += 1;
        }
    }
}
