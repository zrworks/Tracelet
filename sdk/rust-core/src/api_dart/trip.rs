use crate::algorithms::trip_manager::{TripManager as NativeTripManager, TripData as NativeTripData, TripLocation as NativeLocation, TripWaypoint as NativeWaypoint};

/// Represents a single waypoint along a tracked trip.
pub struct TripWaypointDart {
    pub latitude: f64,
    pub longitude: f64,
    pub timestamp_ms: i64,
}

impl From<NativeWaypoint> for TripWaypointDart {
    fn from(wp: NativeWaypoint) -> Self {
        Self {
            latitude: wp.latitude,
            longitude: wp.longitude,
            timestamp_ms: wp.timestamp_ms,
        }
    }
}

/// Represents a geographical location (start or stop) of a trip.
pub struct TripLocationDart {
    pub latitude: f64,
    pub longitude: f64,
}

impl From<NativeLocation> for TripLocationDart {
    fn from(loc: NativeLocation) -> Self {
        Self {
            latitude: loc.latitude,
            longitude: loc.longitude,
        }
    }
}

/// Contains the comprehensive data for a completed trip.
pub struct TripDataDart {
    pub distance_meters: f64,
    pub duration_seconds: f64,
    pub start_location: Option<TripLocationDart>,
    pub stop_location: Option<TripLocationDart>,
    pub waypoints: Vec<TripWaypointDart>,
}

impl From<NativeTripData> for TripDataDart {
    fn from(data: NativeTripData) -> Self {
        Self {
            distance_meters: data.distance_meters,
            duration_seconds: data.duration_seconds,
            start_location: data.start_location.map(|l| l.into()),
            stop_location: data.stop_location.map(|l| l.into()),
            waypoints: data.waypoints.into_iter().map(|w| w.into()).collect(),
        }
    }
}

/// Manages trip state and boundary detection based on motion transitions.
pub struct TripManagerDart {
    inner: NativeTripManager,
}

impl TripManagerDart {
    /// Initializes a new TripManager.
    #[flutter_rust_bridge::frb(sync)]
    pub fn new() -> Self {
        Self {
            inner: NativeTripManager::new(),
        }
    }

    /// Returns true if a trip is actively being recorded.
    #[flutter_rust_bridge::frb(sync)]
    pub fn is_trip_active(&self) -> bool {
        self.inner.is_trip_active()
    }

    /// Updates the motion state and returns trip data if a trip has just ended.
    #[flutter_rust_bridge::frb(sync)]
    pub fn on_motion_state_changed(
        &self,
        is_moving: bool,
        latitude: Option<f64>,
        longitude: Option<f64>,
        timestamp_ms: i64,
        now_ms: i64,
    ) -> Option<TripDataDart> {
        self.inner.on_motion_state_changed(is_moving, latitude, longitude, timestamp_ms, now_ms).map(|d| d.into())
    }

    /// Feeds a new location point to the trip manager.
    #[flutter_rust_bridge::frb(sync)]
    pub fn on_location_received(
        &self,
        latitude: f64,
        longitude: f64,
        timestamp_ms: i64,
    ) {
        self.inner.on_location_received(latitude, longitude, timestamp_ms);
    }

    /// Resets the trip manager, discarding any active trip.
    #[flutter_rust_bridge::frb(sync)]
    pub fn reset(&self) {
        self.inner.reset();
    }
}
