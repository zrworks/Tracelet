//! Dart-facing (flutter_rust_bridge) wrapper around the telematics engine.
//!
//! Lets the example app and Dart tests drive the *real* Rust detection logic
//! with synthetic fixes — simulating harsh braking / acceleration / cornering /
//! speeding without actually driving. Mirrors the `BatteryBudgetEngineDart`
//! pattern.

use crate::algorithms::telematics::{DrivingEvent, TelematicsConfig, TelematicsEngine};

/// FRB-exposed handle to a [`TelematicsEngine`].
pub struct TelematicsEngineDart {
    inner: TelematicsEngine,
}

impl TelematicsEngineDart {
    /// Creates an engine. Pass `None` for default thresholds.
    #[flutter_rust_bridge::frb(sync)]
    pub fn new(config: Option<TelematicsConfig>) -> Self {
        Self {
            inner: TelematicsEngine::new(config),
        }
    }

    /// Feeds one fix (speed m/s, heading deg, epoch ms) and returns events.
    #[flutter_rust_bridge::frb(sync)]
    pub fn process_fix(
        &self,
        speed: f64,
        heading: f64,
        latitude: f64,
        longitude: f64,
        timestamp_ms: i64,
    ) -> Vec<DrivingEvent> {
        self.inner
            .process_fix(speed, heading, latitude, longitude, timestamp_ms)
    }

    /// Current rolling driving score (0–100).
    #[flutter_rust_bridge::frb(sync)]
    pub fn current_score(&self) -> f64 {
        self.inner.current_score()
    }

    /// Resets engine state.
    #[flutter_rust_bridge::frb(sync)]
    pub fn reset(&self) {
        self.inner.reset()
    }
}
