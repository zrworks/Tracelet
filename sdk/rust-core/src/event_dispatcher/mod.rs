use crate::database::DatabaseManager;
use crate::network::SyncManager;
use crate::state::engine_state::EngineState;
use std::sync::Arc;
use tokio::runtime::Runtime;

#[derive(uniffi::Object)]
pub struct EventDispatcher {
    db: Arc<DatabaseManager>,
    sync: Arc<SyncManager>,
    state: Arc<EngineState>,
    rt: Runtime,
}

#[uniffi::export]
impl EventDispatcher {
    #[uniffi::constructor]
    pub fn new(db: Arc<DatabaseManager>, sync: Arc<SyncManager>, state: Arc<EngineState>) -> Self {
        let rt = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .worker_threads(2)
            .build()
            .expect("Failed to build tokio runtime for EventDispatcher");
            
        Self { db, sync, state, rt }
    }

    /// Primary entry point for Native Shells (Android/iOS) to feed OS locations into the Rust Core.
    /// Returns true if the location was accepted and processed, false if discarded (e.g., due to accuracy filter).
    pub fn on_location_update(&self, lat: f64, lng: f64, accuracy: f64, speed: f64, heading: f64, altitude: f64, is_mock: bool) -> bool {
        let config = self.state.get_config();
        crate::logger::info(&format!("[Rust Core] 📍 on_location_update received: ({}, {}), acc={:.1}m, speed={:.2}m/s, heading={:.1}°", lat, lng, accuracy, speed, heading));

        // 1. Basic Filtering
        if config.geo.desired_accuracy >= 0 && accuracy > 100.0 {
            crate::logger::warn(&format!("[Rust Core] ⚠️ Location discarded due to low accuracy ({}m > 100m limit)", accuracy));
            return false;
        }

        let activity = self.state.get_health().current_activity;
        let route_context = self.state.get_route_context();

        // 2. Persist to Database
        if let Err(e) = self.db.insert_location(lat, lng, accuracy, speed, heading, altitude, is_mock, &activity, route_context) {
            crate::logger::error(&format!("[Rust Core] ❌ Failed to insert location into database: {}", e));
            return false;
        }
        crate::logger::info("[Rust Core] 💾 Location persisted to local SQLite database successfully.");

        // 3. Trigger Async Sync if enabled
        if config.http.auto_sync {
            let db_clone = Arc::clone(&self.db);
            let sync_clone = Arc::clone(&self.sync);
            
            crate::logger::info("[Rust Core] 🔄 Triggering HTTP auto-sync batch request.");
            // Spawn background task using the dedicated tokio runtime
            self.rt.spawn(async move {
                match db_clone.get_locations_batch(config.http.max_batch_size) {
                    Ok(records) => {
                        if !records.is_empty() {
                            crate::logger::info(&format!("[Rust Core] 🔄 Batch sync dispatcher loaded {} pending locations.", records.len()));
                            match sync_clone.sync_batch(&config.http, &records).await {
                                Ok(count) => {
                                    if count > 0 {
                                        if let Some(last) = records.last() {
                                            if let Err(err) = db_clone.clear_locations_up_to(last.id) {
                                                crate::logger::error(&format!("[Rust Core] ❌ Failed to prune synced records from DB: {}", err));
                                            } else {
                                                crate::logger::info(&format!("[Rust Core] 🧹 Successfully pruned {} synced location records from SQLite.", count));
                                            }
                                        }
                                    }
                                },
                                Err(e) => {
                                    crate::logger::error(&format!("[Rust Core] ❌ Background batch sync execution failed: {:?}", e));
                                }
                            }
                        } else {
                            crate::logger::info("[Rust Core] ℹ️ Auto-sync triggered, but no pending unsynced locations were found in database.");
                        }
                    },
                    Err(e) => {
                        crate::logger::error(&format!("[Rust Core] ❌ Failed to read locations batch from SQLite: {}", e));
                    }
                }
            });
        } else {
            crate::logger::info("[Rust Core] ℹ️ Auto-sync is disabled. Locations will remain in SQLite until sync() is called manually.");
        }

        true
    }
}
