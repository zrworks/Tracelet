use std::f64::consts::PI;
use std::sync::Mutex;

const PROCESS_NOISE: f64 = 3.0;

struct KalmanState {
    x: f64,
    y: f64,
    vx: f64,
    vy: f64,
    p: [f64; 16],
    origin_lat: f64,
    origin_lng: f64,
    meters_per_degree_lat: f64,
    meters_per_degree_lng: f64,
    last_timestamp_ms: i64,
    is_initialized: bool,
}

/// Provides a Kalman filter implementation tailored for smoothing noisy GPS location data.
#[derive(uniffi::Object)]
pub struct KalmanLocationFilter {
    state: Mutex<KalmanState>,
}

/// A simple geographical point used for the smoothed output of the Kalman filter.
#[derive(uniffi::Record)]
pub struct LatLng {
    pub latitude: f64,
    pub longitude: f64,
}

#[uniffi::export]
impl KalmanLocationFilter {
    /// Initializes a new KalmanLocationFilter state.
    #[uniffi::constructor]
    pub fn new() -> Self {
        Self {
            state: Mutex::new(KalmanState {
                x: 0.0,
                y: 0.0,
                vx: 0.0,
                vy: 0.0,
                p: [0.0; 16],
                origin_lat: 0.0,
                origin_lng: 0.0,
                meters_per_degree_lat: 111320.0,
                meters_per_degree_lng: 111320.0,
                last_timestamp_ms: 0,
                is_initialized: false,
            }),
        }
    }

    /// Returns true if the filter has been seeded with an initial location.
    pub fn is_initialized(&self) -> bool {
        self.state.lock().unwrap().is_initialized
    }

    /// Returns the currently estimated speed (in meters per second) from the filter's state.
    pub fn estimated_speed(&self) -> f64 {
        let state = self.state.lock().unwrap();
        (state.vx * state.vx + state.vy * state.vy).sqrt()
    }

    /// Processes a new location measurement and returns the smoothed coordinates.
    pub fn process(
        &self,
        latitude: f64,
        longitude: f64,
        accuracy: f64,
        timestamp_ms: i64,
    ) -> LatLng {
        let mut state = self.state.lock().unwrap();
        let meas_accuracy = accuracy.max(1.0);

        if !state.is_initialized {
            Self::initialize(&mut state, latitude, longitude, meas_accuracy, timestamp_ms);
            return LatLng {
                latitude,
                longitude,
            };
        }

        let dt = (timestamp_ms - state.last_timestamp_ms) as f64 / 1000.0;
        if dt <= 0.0 {
            return Self::to_lat_lng(&state);
        }
        state.last_timestamp_ms = timestamp_ms;

        let mx = (longitude - state.origin_lng) * state.meters_per_degree_lng;
        let my = (latitude - state.origin_lat) * state.meters_per_degree_lat;

        Self::predict(&mut state, dt);
        Self::update(&mut state, mx, my, meas_accuracy);

        Self::to_lat_lng(&state)
    }

    /// Resets the internal state of the filter, clearing the history.
    pub fn reset(&self) {
        let mut state = self.state.lock().unwrap();
        state.is_initialized = false;
        state.last_timestamp_ms = 0;
        state.x = 0.0;
        state.y = 0.0;
        state.vx = 0.0;
        state.vy = 0.0;
        state.p.fill(0.0);
    }
}

impl KalmanLocationFilter {
    fn initialize(state: &mut KalmanState, lat: f64, lng: f64, accuracy: f64, ts: i64) {
        state.origin_lat = lat;
        state.origin_lng = lng;
        state.meters_per_degree_lat = 111320.0;
        state.meters_per_degree_lng = 111320.0 * (lat * PI / 180.0).cos();

        state.x = 0.0;
        state.y = 0.0;
        state.vx = 0.0;
        state.vy = 0.0;
        state.last_timestamp_ms = ts;
        state.is_initialized = true;

        state.p.fill(0.0);
        state.p[0] = accuracy * accuracy;
        state.p[5] = accuracy * accuracy;
        state.p[10] = 100.0;
        state.p[15] = 100.0;
    }

    fn predict(state: &mut KalmanState, dt: f64) {
        state.x += state.vx * dt;
        state.y += state.vy * dt;

        let q = PROCESS_NOISE * PROCESS_NOISE;
        let dt2 = dt * dt;
        let dt3 = dt2 * dt / 2.0;
        let dt4 = dt2 * dt2 / 4.0;

        let mut p_temp = [0.0; 16];
        p_temp.copy_from_slice(&state.p);
        let t = &p_temp;

        state.p[0] = t[0] + dt * (t[2] + t[8]) + dt2 * t[10] + q * dt4;
        state.p[1] = t[1] + dt * (t[3] + t[9]) + dt2 * t[11];
        state.p[2] = t[2] + dt * t[10] + q * dt3;
        state.p[3] = t[3] + dt * t[11];
        state.p[4] = t[4] + dt * (t[6] + t[12]) + dt2 * t[14];
        state.p[5] = t[5] + dt * (t[7] + t[13]) + dt2 * t[15] + q * dt4;
        state.p[6] = t[6] + dt * t[14];
        state.p[7] = t[7] + dt * t[15] + q * dt3;
        state.p[8] = t[8] + dt * t[10] + q * dt3;
        state.p[9] = t[9] + dt * t[11];
        state.p[10] = t[10] + q * dt2;
        state.p[11] = t[11];
        state.p[12] = t[12] + dt * t[14];
        state.p[13] = t[13] + dt * t[15] + q * dt3;
        state.p[14] = t[14];
        state.p[15] = t[15] + q * dt2;
    }

    fn update(state: &mut KalmanState, mx: f64, my: f64, accuracy: f64) {
        let r = accuracy * accuracy;
        let dx = mx - state.x;
        let dy = my - state.y;

        let s00 = state.p[0] + r;
        let s01 = state.p[1];
        let s10 = state.p[4];
        let s11 = state.p[5] + r;

        let det = s00 * s11 - s01 * s10;
        if det == 0.0 {
            return;
        }

        let inv_det = 1.0 / det;
        let si00 = s11 * inv_det;
        let si01 = -s01 * inv_det;
        let si10 = -s10 * inv_det;
        let si11 = s00 * inv_det;

        let k00 = state.p[0] * si00 + state.p[1] * si10;
        let k01 = state.p[0] * si01 + state.p[1] * si11;
        let k10 = state.p[4] * si00 + state.p[5] * si10;
        let k11 = state.p[4] * si01 + state.p[5] * si11;
        let k20 = state.p[8] * si00 + state.p[9] * si10;
        let k21 = state.p[8] * si01 + state.p[9] * si11;
        let k30 = state.p[12] * si00 + state.p[13] * si10;
        let k31 = state.p[12] * si01 + state.p[13] * si11;

        state.x += k00 * dx + k01 * dy;
        state.y += k10 * dx + k11 * dy;
        state.vx += k20 * dx + k21 * dy;
        state.vy += k30 * dx + k31 * dy;

        let mut p_temp = [0.0; 16];
        p_temp.copy_from_slice(&state.p);
        let t = &p_temp;

        state.p[0] = t[0] - k00 * t[0] - k01 * t[4];
        state.p[1] = t[1] - k00 * t[1] - k01 * t[5];
        state.p[2] = t[2] - k00 * t[2] - k01 * t[6];
        state.p[3] = t[3] - k00 * t[3] - k01 * t[7];
        state.p[4] = t[4] - k10 * t[0] - k11 * t[4];
        state.p[5] = t[5] - k10 * t[1] - k11 * t[5];
        state.p[6] = t[6] - k10 * t[2] - k11 * t[6];
        state.p[7] = t[7] - k10 * t[3] - k11 * t[7];
        state.p[8] = t[8] - k20 * t[0] - k21 * t[4];
        state.p[9] = t[9] - k20 * t[1] - k21 * t[5];
        state.p[10] = t[10] - k20 * t[2] - k21 * t[6];
        state.p[11] = t[11] - k20 * t[3] - k21 * t[7];
        state.p[12] = t[12] - k30 * t[0] - k31 * t[4];
        state.p[13] = t[13] - k30 * t[1] - k31 * t[5];
        state.p[14] = t[14] - k30 * t[2] - k31 * t[6];
        state.p[15] = t[15] - k30 * t[3] - k31 * t[7];
    }

    fn to_lat_lng(state: &KalmanState) -> LatLng {
        LatLng {
            latitude: state.origin_lat + state.y / state.meters_per_degree_lat,
            longitude: state.origin_lng + state.x / state.meters_per_degree_lng,
        }
    }
}
