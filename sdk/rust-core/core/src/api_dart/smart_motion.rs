use crate::state::smart_motion_coordinator::{SmartMotionCoordinator as NativeMotion, TrackingMode as NativeMode};

/// Represents the different tracking modes available for the SmartMotionCoordinator.
pub enum TrackingModeDart {
    /// Actively track location using continuous updates.
    Active,
    /// Passive tracking using stationary geofences.
    Passive,
    /// Manual tracking mode using periodic updates.
    Manual,
}

impl From<TrackingModeDart> for NativeMode {
    fn from(mode: TrackingModeDart) -> Self {
        match mode {
            TrackingModeDart::Active => NativeMode::Continuous,
            TrackingModeDart::Passive => NativeMode::StationaryGeofences,
            TrackingModeDart::Manual => NativeMode::StationaryPeriodic,
        }
    }
}

/// Coordinator that manages tracking mode state based on motion and speed events.
pub struct SmartMotionCoordinatorDart {
    inner: NativeMotion,
}

impl SmartMotionCoordinatorDart {
    /// Creates a new instance of SmartMotionCoordinator.
    #[flutter_rust_bridge::frb(sync)]
    pub fn new() -> Self {
        Self {
            inner: NativeMotion::new(true),
        }
    }

    /// Sets the current tracking mode for the coordinator.
    #[flutter_rust_bridge::frb(sync)]
    pub fn set_tracking_mode(&self, mode: TrackingModeDart) {
        self.inner.set_current_mode(mode.into());
    }

    /// Processes an accelerometer event and returns true if motion state changed.
    #[flutter_rust_bridge::frb(sync)]
    pub fn on_accel_event(&self, x: f32, y: f32, z: f32, _timestamp_ms: i64) -> bool {
        let is_moving = x.abs() > 0.5 || y.abs() > 0.5 || z.abs() > 0.5;
        self.inner.on_accel_state_change(is_moving);
        self.inner.is_accel_moving() || self.inner.is_speed_moving()
    }

    /// Processes a speed change event (e.g., from GPS) and returns true if motion state changed.
    #[flutter_rust_bridge::frb(sync)]
    pub fn on_speed_changed(&self, speed: f32) -> bool {
        self.inner.on_speed_state_change(speed > 1.0);
        self.inner.is_accel_moving() || self.inner.is_speed_moving()
    }

    /// Returns whether the device is currently considered to be moving.
    #[flutter_rust_bridge::frb(sync)]
    pub fn is_moving(&self) -> bool {
        self.inner.is_accel_moving() || self.inner.is_speed_moving()
    }
}
