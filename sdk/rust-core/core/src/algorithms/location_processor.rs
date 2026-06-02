use crate::algorithms::geo_utils::haversine;
use std::sync::Mutex;

/// Represents the interpreted physical activity state of the device.
#[derive(uniffi::Enum, Clone, Copy, PartialEq)]
pub enum ActivityType {
    Still,
    Walking,
    Running,
    OnFoot,
    InVehicle,
    OnBicycle,
    Unknown,
}

/// Confidence level of the associated physical activity.
#[derive(uniffi::Enum, Clone, Copy, PartialEq)]
pub enum ActivityConfidence {
    Low,
    Medium,
    High,
}

/// Environmental context used to adapt location sampling frequency.
#[derive(uniffi::Record)]
pub struct AdaptiveContext {
    pub battery_level: f64,
    pub is_charging: bool,
    pub activity_type: ActivityType,
    pub activity_confidence: ActivityConfidence,
    pub speed: f64,
}

impl Default for AdaptiveContext {
    fn default() -> Self {
        Self {
            battery_level: -1.0,
            is_charging: false,
            activity_type: ActivityType::Unknown,
            activity_confidence: ActivityConfidence::Low,
            speed: 0.0,
        }
    }
}

/// The primary factor driving the current adaptive sampling rate.
#[derive(uniffi::Enum, Clone, Copy, PartialEq)]
pub enum AdaptiveSource {
    Activity,
    Speed,
    Static,
}

/// Results from evaluating the current context to determine the optimal sampling parameters.
#[derive(uniffi::Record)]
pub struct AdaptiveSamplingResult {
    pub effective_distance_filter: f64,
    pub base_distance_filter: f64,
    pub activity_factor: f64,
    pub battery_factor: f64,
    pub speed_factor: f64,
    pub source: AdaptiveSource,
}

/// Core logic engine for dynamically adjusting distance filters based on context.
#[derive(uniffi::Object)]
pub struct AdaptiveSamplingEngine {
    base_distance_filter: f64,
    elasticity_multiplier: f64,
}

#[uniffi::export]
impl AdaptiveSamplingEngine {
    #[uniffi::constructor]
    pub fn new(base_distance_filter: f64, elasticity_multiplier: f64) -> Self {
        Self {
            base_distance_filter,
            elasticity_multiplier,
        }
    }

    pub fn compute(&self, context: AdaptiveContext) -> AdaptiveSamplingResult {
        let mut activity_factor = 1.0;
        let mut speed_factor = 1.0;
        let mut source = AdaptiveSource::Static;

        let use_activity = context.activity_type != ActivityType::Unknown
            && context.activity_confidence != ActivityConfidence::Low;

        if use_activity {
            let activity_distance = Self::activity_distance(context.activity_type);
            activity_factor = activity_distance / self.base_distance_filter;
            source = AdaptiveSource::Activity;
        } else if context.speed > 0.0 {
            let mult = self.elasticity_multiplier.max(0.1);
            speed_factor = (context.speed / 10.0).clamp(1.0, 10.0) * mult;
            source = AdaptiveSource::Speed;
        }

        let batt_factor = Self::battery_factor(context.battery_level, context.is_charging);

        let effective = match source {
            AdaptiveSource::Activity => self.base_distance_filter * activity_factor * batt_factor,
            AdaptiveSource::Speed => self.base_distance_filter * speed_factor * batt_factor,
            AdaptiveSource::Static => self.base_distance_filter * batt_factor,
        };

        AdaptiveSamplingResult {
            effective_distance_filter: effective,
            base_distance_filter: self.base_distance_filter,
            activity_factor,
            battery_factor: batt_factor,
            speed_factor,
            source,
        }
    }
}

impl AdaptiveSamplingEngine {
    const DISTANCE_STILL: f64 = 500.0;
    const DISTANCE_WALKING: f64 = 50.0;
    const DISTANCE_RUNNING: f64 = 30.0;
    const DISTANCE_BICYCLE: f64 = 25.0;
    const DISTANCE_VEHICLE: f64 = 10.0;

    const BATTERY_HIGH_THRESHOLD: f64 = 0.50;
    const BATTERY_MEDIUM_THRESHOLD: f64 = 0.20;
    const BATTERY_LOW_THRESHOLD: f64 = 0.10;

    const BATTERY_MEDIUM_FACTOR: f64 = 1.5;
    const BATTERY_LOW_FACTOR: f64 = 2.5;
    const BATTERY_CRITICAL_FACTOR: f64 = 5.0;

    fn activity_distance(activity: ActivityType) -> f64 {
        match activity {
            ActivityType::Still => Self::DISTANCE_STILL,
            ActivityType::Walking | ActivityType::OnFoot => Self::DISTANCE_WALKING,
            ActivityType::Running => Self::DISTANCE_RUNNING,
            ActivityType::OnBicycle => Self::DISTANCE_BICYCLE,
            ActivityType::InVehicle => Self::DISTANCE_VEHICLE,
            ActivityType::Unknown => 10.0,
        }
    }

    fn battery_factor(battery_level: f64, is_charging: bool) -> f64 {
        if is_charging || battery_level < 0.0 {
            return 1.0;
        }
        if battery_level < Self::BATTERY_LOW_THRESHOLD {
            return Self::BATTERY_CRITICAL_FACTOR;
        }
        if battery_level < Self::BATTERY_MEDIUM_THRESHOLD {
            return Self::BATTERY_LOW_FACTOR;
        }
        if battery_level < Self::BATTERY_HIGH_THRESHOLD {
            return Self::BATTERY_MEDIUM_FACTOR;
        }
        1.0
    }
}

/// Represents the outcome of filtering and processing a single location update.
#[derive(uniffi::Record)]
pub struct LocationProcessorResult {
    pub accepted: bool,
    pub effective_speed: f64,
    pub odometer_delta: f64,
    pub distance: f64,
    pub reason: Option<String>,
    pub error_message: Option<String>,
    pub is_error: bool,
}

impl LocationProcessorResult {
    fn accept(effective_speed: f64, odometer_delta: f64, distance: f64) -> Self {
        Self {
            accepted: true,
            effective_speed,
            odometer_delta,
            distance,
            reason: None,
            error_message: None,
            is_error: false,
        }
    }

    fn filtered(reason: &str) -> Self {
        Self {
            accepted: false,
            effective_speed: 0.0,
            odometer_delta: 0.0,
            distance: 0.0,
            reason: Some(reason.to_string()),
            error_message: None,
            is_error: false,
        }
    }

    fn error(reason: &str, message: &str) -> Self {
        Self {
            accepted: false,
            effective_speed: 0.0,
            odometer_delta: 0.0,
            distance: 0.0,
            reason: Some(reason.to_string()),
            error_message: Some(message.to_string()),
            is_error: true,
        }
    }
}

struct LocationProcessorState {
    last_latitude: Option<f64>,
    last_longitude: Option<f64>,
    last_timestamp_ms: i64,
    sparse_last_lat: Option<f64>,
    sparse_last_lng: Option<f64>,
    sparse_last_timestamp_ms: i64,
    last_effective_speed: f64,
}

/// Core location processing engine that handles filtering out inaccurate or redundant points.
#[derive(uniffi::Object)]
pub struct LocationProcessor {
    distance_filter: f64,
    disable_elasticity: bool,
    elasticity_multiplier: f64,
    enable_adaptive_mode: bool,
    tracking_accuracy_threshold: i32,
    filter_policy: i32,
    max_implied_speed: i32,
    odometer_accuracy_threshold: i32,
    reject_mock_locations: bool,
    mock_detection_level: i32,
    enable_sparse_updates: bool,
    sparse_distance_threshold: f64,
    sparse_max_idle_seconds: i32,
    state: Mutex<LocationProcessorState>,
}

#[uniffi::export]
impl LocationProcessor {
    #[uniffi::constructor]
    pub fn new(
        distance_filter: f64,
        disable_elasticity: bool,
        elasticity_multiplier: f64,
        enable_adaptive_mode: bool,
        tracking_accuracy_threshold: i32,
        filter_policy: i32,
        max_implied_speed: i32,
        odometer_accuracy_threshold: i32,
        reject_mock_locations: bool,
        mock_detection_level: i32,
        enable_sparse_updates: bool,
        sparse_distance_threshold: f64,
        sparse_max_idle_seconds: i32,
    ) -> Self {
        Self {
            distance_filter,
            disable_elasticity,
            elasticity_multiplier,
            enable_adaptive_mode,
            tracking_accuracy_threshold,
            filter_policy,
            max_implied_speed,
            odometer_accuracy_threshold,
            reject_mock_locations,
            mock_detection_level,
            enable_sparse_updates,
            sparse_distance_threshold,
            sparse_max_idle_seconds,
            state: Mutex::new(LocationProcessorState {
                last_latitude: None,
                last_longitude: None,
                last_timestamp_ms: 0,
                sparse_last_lat: None,
                sparse_last_lng: None,
                sparse_last_timestamp_ms: 0,
                last_effective_speed: 0.0,
            }),
        }
    }

    pub fn last_effective_speed(&self) -> f64 {
        self.state.lock().unwrap().last_effective_speed
    }

    pub fn has_last_location(&self) -> bool {
        self.state.lock().unwrap().last_latitude.is_some()
    }

    pub fn process(
        &self,
        latitude: f64,
        longitude: f64,
        accuracy: f64,
        speed: f64,
        timestamp_ms: i64,
        is_mock: bool,
        adaptive_context: Option<AdaptiveContext>,
    ) -> LocationProcessorResult {
        let mut state = self.state.lock().unwrap();

        if self.reject_mock_locations && is_mock {
            return if self.filter_policy == 2 {
                LocationProcessorResult::error(
                    "MOCK_LOCATION",
                    "Location rejected: flagged as mock/spoofed by the platform",
                )
            } else {
                LocationProcessorResult::filtered("MOCK_LOCATION")
            };
        }

        if self.mock_detection_level >= 2
            && self.reject_mock_locations
            && state.last_timestamp_ms > 0
            && timestamp_ms < state.last_timestamp_ms
        {
            return if self.filter_policy == 2 {
                LocationProcessorResult::error(
                    "MOCK_LOCATION_TIMESTAMP",
                    &format!(
                        "Location rejected: timestamp {} is before previous {} (non-monotonic)",
                        timestamp_ms, state.last_timestamp_ms
                    ),
                )
            } else {
                LocationProcessorResult::filtered("MOCK_LOCATION_TIMESTAMP")
            };
        }

        let mut distance = 0.0;
        let mut time_delta = 0.0;

        if let (Some(prev_lat), Some(prev_lng)) = (state.last_latitude, state.last_longitude) {
            distance = haversine(prev_lat, prev_lng, latitude, longitude);
            time_delta = (timestamp_ms - state.last_timestamp_ms) as f64 / 1000.0;
        }

        let computed_speed = if distance > 0.0 && time_delta > 0.0 {
            distance / time_delta
        } else {
            0.0
        };
        let effective_speed = if speed > 0.0 { speed } else { computed_speed };

        let mut effective_distance = self.distance_filter;
        if self.enable_adaptive_mode {
            let mut ctx = adaptive_context.unwrap_or_default();
            if ctx.speed <= 0.0 {
                ctx.speed = effective_speed;
            }
            let engine = AdaptiveSamplingEngine::new(self.distance_filter, self.elasticity_multiplier);
            effective_distance = engine.compute(ctx).effective_distance_filter;
        } else if !self.disable_elasticity && effective_speed > 0.0 {
            let multiplier = self.elasticity_multiplier.max(0.1);
            let speed_factor = (effective_speed / 10.0).clamp(1.0, 10.0);
            effective_distance = self.distance_filter * speed_factor * multiplier;
        }

        if state.last_latitude.is_some() && distance < effective_distance {
            return LocationProcessorResult::filtered("DISTANCE_FILTER");
        }

        if self.tracking_accuracy_threshold > 0 && accuracy > self.tracking_accuracy_threshold as f64 {
            match self.filter_policy {
                2 => {
                    return LocationProcessorResult::error(
                        "ACCURACY_FILTER",
                        &format!(
                            "Location accuracy {}m exceeds threshold {}m",
                            accuracy, self.tracking_accuracy_threshold
                        ),
                    )
                }
                1 => return LocationProcessorResult::filtered("ACCURACY_FILTER"),
                _ => {
                    if state.last_latitude.is_some() {
                        return LocationProcessorResult::filtered("ACCURACY_FILTER");
                    }
                }
            }
        }

        if self.max_implied_speed > 0 && state.last_latitude.is_some() && time_delta > 0.0 {
            let implied_speed = distance / time_delta;
            if implied_speed > self.max_implied_speed as f64 {
                return if self.filter_policy == 2 {
                    LocationProcessorResult::error(
                        "SPEED_FILTER",
                        &format!(
                            "Implied speed {:.1}m/s exceeds max {}m/s",
                            implied_speed, self.max_implied_speed
                        ),
                    )
                } else {
                    LocationProcessorResult::filtered("SPEED_FILTER")
                };
            }
        }

        let odometer_delta = if self.odometer_accuracy_threshold <= 0
            || accuracy <= self.odometer_accuracy_threshold as f64
        {
            distance
        } else {
            0.0
        };

        if self.enable_sparse_updates {
            if let (Some(s_lat), Some(s_lng)) = (state.sparse_last_lat, state.sparse_last_lng) {
                let sparse_dist = haversine(s_lat, s_lng, latitude, longitude);
                let sparse_elapsed = (timestamp_ms - state.sparse_last_timestamp_ms) as f64 / 1000.0;

                let within_distance = sparse_dist < self.sparse_distance_threshold;
                let within_time = self.sparse_max_idle_seconds == 0
                    || sparse_elapsed < self.sparse_max_idle_seconds as f64;

                if within_distance && within_time {
                    state.last_latitude = Some(latitude);
                    state.last_longitude = Some(longitude);
                    state.last_timestamp_ms = timestamp_ms;
                    state.last_effective_speed = effective_speed;
                    return LocationProcessorResult::filtered("SPARSE_FILTER");
                }
            }
            state.sparse_last_lat = Some(latitude);
            state.sparse_last_lng = Some(longitude);
            state.sparse_last_timestamp_ms = timestamp_ms;
        }

        state.last_latitude = Some(latitude);
        state.last_longitude = Some(longitude);
        state.last_timestamp_ms = timestamp_ms;
        state.last_effective_speed = effective_speed;

        LocationProcessorResult::accept(effective_speed, odometer_delta, distance)
    }

    pub fn reset(&self) {
        let mut state = self.state.lock().unwrap();
        state.last_latitude = None;
        state.last_longitude = None;
        state.last_timestamp_ms = 0;
        state.last_effective_speed = 0.0;
        state.sparse_last_lat = None;
        state.sparse_last_lng = None;
        state.sparse_last_timestamp_ms = 0;
    }
}
