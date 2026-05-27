use crate::config::EngineConfig;
use serde::{Deserialize, Serialize};
use std::sync::RwLock;

/// Represents the global health and status of the Tracelet Engine.
#[derive(Debug, Clone, Serialize, Deserialize, Default, uniffi::Record)]
#[serde(rename_all = "camelCase")]
pub struct HealthState {
    pub is_tracking: bool,
    pub is_moving: bool,
    pub current_activity: String,
    pub battery_level: f64,
}

/// The centralized Engine State that holds the active configuration and current health.
/// This acts as the single source of truth for the entire SDK across platforms.
#[derive(uniffi::Object)]
pub struct EngineState {
    pub config: RwLock<EngineConfig>,
    pub health: RwLock<HealthState>,
    pub route_context: RwLock<Option<String>>,
}

#[uniffi::export]
impl EngineState {
    /// Initializes a new EngineState with default configuration and health.
    #[uniffi::constructor]
    pub fn new() -> Self {
        Self {
            config: RwLock::new(EngineConfig::default()),
            health: RwLock::new(HealthState::default()),
            route_context: RwLock::new(None),
        }
    }

    /// Updates the global engine configuration.
    pub fn update_config(&self, new_config: EngineConfig) {
        if let Ok(mut config) = self.config.write() {
            *config = new_config;
        }
    }

    /// Updates the global engine configuration from a JSON string.
    pub fn update_config_from_json(&self, json: &str) -> Result<(), crate::error::TraceletError> {
        let new_config = EngineConfig::from_json(json)
            .map_err(|e| crate::error::TraceletError::Config(e.to_string()))?;
        self.update_config(new_config);
        Ok(())
    }

    /// Updates the dynamic HTTP headers in the configuration.
    pub fn set_dynamic_headers(&self, headers: std::collections::HashMap<String, String>) {
        if let Ok(mut config) = self.config.write() {
            config.http.headers.extend(headers);
        }
    }

    /// Retrieves a cloned snapshot of the current active configuration.
    pub fn get_config(&self) -> EngineConfig {
        self.config.read().unwrap().clone()
    }

    /// Updates the global tracking status.
    pub fn set_tracking(&self, tracking: bool) {
        if let Ok(mut health) = self.health.write() {
            health.is_tracking = tracking;
        }
    }

    /// Retrieves a cloned snapshot of the current health state.
    pub fn get_health(&self) -> HealthState {
        self.health.read().unwrap().clone()
    }

    /// Updates the active route context (custom JSON payload) for upcoming locations.
    pub fn set_route_context(&self, json: Option<String>) {
        if let Ok(mut rc) = self.route_context.write() {
            *rc = json;
        }
    }

    /// Retrieves the current route context JSON string, if any.
    pub fn get_route_context(&self) -> Option<String> {
        self.route_context.read().unwrap().clone()
    }
}
