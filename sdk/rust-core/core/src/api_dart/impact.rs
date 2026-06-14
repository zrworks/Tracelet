//! Dart-facing (flutter_rust_bridge) wrapper around the impact detector.
//!
//! Lets the example app and Dart tests simulate crash/fall impacts (a high-g
//! spike + speed context) and exercise the confirm/cancel countdown flow,
//! without a real collision.

use crate::algorithms::impact::{ImpactConfig, ImpactDetector, ImpactEvent};

/// FRB-exposed handle to an [`ImpactDetector`].
pub struct ImpactDetectorDart {
    inner: ImpactDetector,
}

impl ImpactDetectorDart {
    /// Creates a detector. Pass `None` for defaults (both detections off).
    #[flutter_rust_bridge::frb(sync)]
    pub fn new(config: Option<ImpactConfig>) -> Self {
        Self {
            inner: ImpactDetector::new(config),
        }
    }

    /// Feeds one accel-window peak + motion context; returns a `potential_*`
    /// candidate when an impact is detected.
    #[flutter_rust_bridge::frb(sync)]
    pub fn on_impact_window(
        &self,
        peak_g: f64,
        speed_before_mps: f64,
        is_on_foot: bool,
        latitude: f64,
        longitude: f64,
        now_ms: i64,
    ) -> Option<ImpactEvent> {
        self.inner.on_impact_window(
            peak_g,
            speed_before_mps,
            is_on_foot,
            latitude,
            longitude,
            now_ms,
        )
    }

    /// Fires confirmed events for candidates whose deadline elapsed.
    #[flutter_rust_bridge::frb(sync)]
    pub fn check_confirmations(&self, now_ms: i64) -> Vec<ImpactEvent> {
        self.inner.check_confirmations(now_ms)
    }

    /// Confirms a pending candidate now.
    #[flutter_rust_bridge::frb(sync)]
    pub fn confirm(&self, id: i64, now_ms: i64) -> Option<ImpactEvent> {
        self.inner.confirm(id, now_ms)
    }

    /// Cancels a pending candidate.
    #[flutter_rust_bridge::frb(sync)]
    pub fn cancel(&self, id: i64) -> bool {
        self.inner.cancel(id)
    }

    /// Resets all pending candidates.
    #[flutter_rust_bridge::frb(sync)]
    pub fn reset(&self) {
        self.inner.reset()
    }
}
