use crate::algorithms::trip_manager::{TripManager as NativeTripManager, TripData as NativeTripData, TripLocation as NativeLocation, TripWaypoint as NativeWaypoint};

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

pub struct TripManagerDart {
    inner: NativeTripManager,
}

impl TripManagerDart {
    #[flutter_rust_bridge::frb(sync)]
    #[flutter_rust_bridge::frb(sync)]
    pub fn new() -> Self {
        Self {
            inner: NativeTripManager::new(),
        }
    }

    #[flutter_rust_bridge::frb(sync)]
    #[flutter_rust_bridge::frb(sync)]
    pub fn is_trip_active(&self) -> bool {
        self.inner.is_trip_active()
    }

    #[flutter_rust_bridge::frb(sync)]
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

    #[flutter_rust_bridge::frb(sync)]
    #[flutter_rust_bridge::frb(sync)]
    pub fn on_location_received(
        &self,
        latitude: f64,
        longitude: f64,
        timestamp_ms: i64,
    ) {
        self.inner.on_location_received(latitude, longitude, timestamp_ms);
    }

    #[flutter_rust_bridge::frb(sync)]
    #[flutter_rust_bridge::frb(sync)]
    pub fn reset(&self) {
        self.inner.reset();
    }
}
