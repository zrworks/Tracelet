//! Dart-facing (flutter_rust_bridge) wrapper around the transport-mode
//! classifier.
//!
//! Lets the example app and Dart tests simulate motion by feeding synthetic
//! accelerometer-sample batches + speed and observing the fused mode, without
//! actually walking/cycling/driving.

use crate::algorithms::sensor_features::compute_accel_window;
use crate::algorithms::transport_mode::{ClassifierConfig, ModeResult, TransportModeClassifier};

/// FRB-exposed handle to a [`TransportModeClassifier`].
pub struct TransportModeClassifierDart {
    inner: TransportModeClassifier,
}

impl TransportModeClassifierDart {
    /// Creates a classifier. Pass `None` for default tuning.
    #[flutter_rust_bridge::frb(sync)]
    pub fn new(config: Option<ClassifierConfig>) -> Self {
        Self {
            inner: TransportModeClassifier::new(config),
        }
    }

    /// Convenience: computes an accel window from raw magnitudes (g) and
    /// classifies it together with `speed_mps`. Returns the committed mode.
    #[flutter_rust_bridge::frb(sync)]
    pub fn classify_samples(
        &self,
        magnitudes_g: Vec<f64>,
        duration_ms: i64,
        speed_mps: f64,
        now_ms: i64,
    ) -> ModeResult {
        let window = compute_accel_window(magnitudes_g, duration_ms);
        self.inner.classify(window, speed_mps, now_ms)
    }

    /// Resets to `Unknown`.
    #[flutter_rust_bridge::frb(sync)]
    pub fn reset(&self) {
        self.inner.reset()
    }
}
