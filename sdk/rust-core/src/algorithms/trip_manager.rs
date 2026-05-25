use crate::algorithms::geo_utils::haversine;
use std::collections::VecDeque;
use std::sync::Mutex;

const MAX_WAYPOINTS: usize = 5000;

/// A geographical point recorded as part of a trip's path.
#[derive(Clone, Debug, uniffi::Record)]
pub struct TripWaypoint {
    pub latitude: f64,
    pub longitude: f64,
    pub timestamp_ms: i64,
}

/// Represents the start or end geographical location of a trip.
#[derive(Clone, Debug, uniffi::Record)]
pub struct TripLocation {
    pub latitude: f64,
    pub longitude: f64,
}

/// Summarized data for a tracked trip, including distance, duration, and path.
#[derive(Clone, Debug, uniffi::Record)]
pub struct TripData {
    pub distance_meters: f64,
    pub duration_seconds: f64,
    pub start_location: Option<TripLocation>,
    pub stop_location: Option<TripLocation>,
    pub waypoints: Vec<TripWaypoint>,
}

struct TripManagerState {
    is_trip_active: bool,
    start_lat: Option<f64>,
    start_lng: Option<f64>,
    start_time_ms: i64,
    total_distance: f64,
    last_waypoint_lat: Option<f64>,
    last_waypoint_lng: Option<f64>,
    waypoints: VecDeque<TripWaypoint>,
}

/// Core logic for determining trip boundaries (start/stop) based on location and motion changes.
#[derive(uniffi::Object)]
pub struct TripManager {
    state: Mutex<TripManagerState>,
}

#[uniffi::export]
impl TripManager {
    /// Initializes a new TripManager state machine.
    #[uniffi::constructor]
    pub fn new() -> Self {
        Self {
            state: Mutex::new(TripManagerState {
                is_trip_active: false,
                start_lat: None,
                start_lng: None,
                start_time_ms: 0,
                total_distance: 0.0,
                last_waypoint_lat: None,
                last_waypoint_lng: None,
                waypoints: VecDeque::new(),
            }),
        }
    }

    /// Returns true if a trip is currently being tracked.
    pub fn is_trip_active(&self) -> bool {
        let state = self.state.lock().unwrap();
        state.is_trip_active
    }

    /// Evaluates a motion state transition to determine if a trip has started or ended.
    /// If a trip ended, it returns the accumulated `TripData`.
    pub fn on_motion_state_changed(
        &self,
        is_moving: bool,
        latitude: Option<f64>,
        longitude: Option<f64>,
        timestamp_ms: i64,
        now_ms: i64,
    ) -> Option<TripData> {
        let mut state = self.state.lock().unwrap();
        if is_moving && !state.is_trip_active {
            Self::start_trip(&mut state, latitude, longitude, timestamp_ms, now_ms);
            None
        } else if !is_moving && state.is_trip_active {
            Some(Self::end_trip(&mut state, latitude, longitude, timestamp_ms, now_ms))
        } else {
            None
        }
    }

    /// Feeds a new location sample into the active trip to update its path and distance.
    pub fn on_location_received(
        &self,
        latitude: f64,
        longitude: f64,
        timestamp_ms: i64,
    ) {
        let mut state = self.state.lock().unwrap();
        if !state.is_trip_active {
            return;
        }

        if let (Some(prev_lat), Some(prev_lng)) = (state.last_waypoint_lat, state.last_waypoint_lng) {
            state.total_distance += haversine(prev_lat, prev_lng, latitude, longitude);
        }
        
        state.last_waypoint_lat = Some(latitude);
        state.last_waypoint_lng = Some(longitude);

        if state.waypoints.len() >= MAX_WAYPOINTS {
            state.waypoints.pop_front();
        }
        state.waypoints.push_back(TripWaypoint {
            latitude,
            longitude,
            timestamp_ms,
        });
    }

    /// Resets the trip manager, discarding any active trip and path data.
    pub fn reset(&self) {
        let mut state = self.state.lock().unwrap();
        state.is_trip_active = false;
        state.start_lat = None;
        state.start_lng = None;
        state.last_waypoint_lat = None;
        state.last_waypoint_lng = None;
        state.start_time_ms = 0;
        state.total_distance = 0.0;
        state.waypoints.clear();
    }
}

impl TripManager {
    fn start_trip(
        state: &mut TripManagerState,
        lat: Option<f64>,
        lng: Option<f64>,
        timestamp_ms: i64,
        now_ms: i64,
    ) {
        state.is_trip_active = true;
        state.start_lat = lat;
        state.start_lng = lng;
        state.last_waypoint_lat = lat;
        state.last_waypoint_lng = lng;
        state.start_time_ms = now_ms;
        state.total_distance = 0.0;
        state.waypoints.clear();

        if let (Some(l), Some(g)) = (lat, lng) {
            state.waypoints.push_back(TripWaypoint {
                latitude: l,
                longitude: g,
                timestamp_ms,
            });
        }
    }

    fn end_trip(
        state: &mut TripManagerState,
        lat: Option<f64>,
        lng: Option<f64>,
        timestamp_ms: i64,
        now_ms: i64,
    ) -> TripData {
        state.is_trip_active = false;

        if let (Some(l), Some(g), Some(prev_lat), Some(prev_lng)) = (lat, lng, state.last_waypoint_lat, state.last_waypoint_lng) {
            state.total_distance += haversine(prev_lat, prev_lng, l, g);
            
            if state.waypoints.len() >= MAX_WAYPOINTS {
                state.waypoints.pop_front();
            }
            state.waypoints.push_back(TripWaypoint {
                latitude: l,
                longitude: g,
                timestamp_ms,
            });
        }

        let duration_ms = now_ms - state.start_time_ms;
        let duration_seconds = (duration_ms as f64) / 1000.0;

        let start_location = match (state.start_lat, state.start_lng) {
            (Some(l), Some(g)) => Some(TripLocation { latitude: l, longitude: g }),
            _ => None,
        };

        let stop_location = match (lat, lng) {
            (Some(l), Some(g)) => Some(TripLocation { latitude: l, longitude: g }),
            _ => None,
        };

        let trip_data = TripData {
            distance_meters: state.total_distance,
            duration_seconds,
            start_location,
            stop_location,
            waypoints: state.waypoints.iter().cloned().collect(),
        };

        state.start_lat = None;
        state.start_lng = None;
        state.last_waypoint_lat = None;
        state.last_waypoint_lng = None;
        state.start_time_ms = 0;
        state.total_distance = 0.0;
        state.waypoints.clear();

        trip_data
    }
}
