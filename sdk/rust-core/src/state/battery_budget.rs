use std::sync::Mutex;

const ERROR_THRESHOLD: f64 = 0.5;
const MIN_DISTANCE_FILTER: f64 = 10.0;
const MAX_DISTANCE_FILTER: f64 = 5000.0;
const THROTTLE_FACTOR: f64 = 1.5;
const BOOST_FACTOR: f64 = 0.8;

#[derive(uniffi::Record, Debug, Clone, Copy)]
pub struct BudgetAdjustmentEvent {
    pub current_battery_drain: f64,
    pub target_budget: f64,
    pub new_distance_filter: f64,
    pub new_desired_accuracy: i32,
    pub new_periodic_interval: Option<i32>,
}

struct EngineState {
    distance_filter: f64,
    accuracy_index: i32,
    periodic_interval: Option<i32>,
    prev_battery_level: Option<f64>,
    prev_sample_time_ms: Option<i64>,
}

#[derive(uniffi::Object)]
pub struct BatteryBudgetEngine {
    target_budget_per_hour: f64,
    state: Mutex<EngineState>,
}

#[uniffi::export]
impl BatteryBudgetEngine {
    #[uniffi::constructor]
    pub fn new(
        target_budget_per_hour: f64,
        initial_distance_filter: f64,
        initial_accuracy_index: i32,
        initial_periodic_interval: Option<i32>,
    ) -> Self {
        Self {
            target_budget_per_hour,
            state: Mutex::new(EngineState {
                distance_filter: initial_distance_filter,
                accuracy_index: initial_accuracy_index.clamp(0, 4),
                periodic_interval: initial_periodic_interval,
                prev_battery_level: None,
                prev_sample_time_ms: None,
            }),
        }
    }

    pub fn process_sample(
        &self,
        battery_level: f64,
        now_ms: i64,
    ) -> Option<BudgetAdjustmentEvent> {
        let mut state = self.state.lock().unwrap();
        
        let (prev_level, prev_time) = match (state.prev_battery_level, state.prev_sample_time_ms) {
            (Some(l), Some(t)) => (l, t),
            _ => {
                state.prev_battery_level = Some(battery_level);
                state.prev_sample_time_ms = Some(now_ms);
                return None;
            }
        };

        let elapsed_sec = (now_ms - prev_time) as f64 / 1000.0;
        if elapsed_sec < 60.0 {
            return None; // Too soon for meaningful measurement.
        }

        // Compute actual drain normalized to %/hr.
        let drain = (prev_level - battery_level) * 100.0;
        let drain_per_hour = drain * (3600.0 / elapsed_sec);

        state.prev_battery_level = Some(battery_level);
        state.prev_sample_time_ms = Some(now_ms);

        // Charging — no adjustment needed.
        if drain_per_hour <= 0.0 {
            return None;
        }

        let error = drain_per_hour - self.target_budget_per_hour;

        if error.abs() < ERROR_THRESHOLD {
            return None;
        }

        let mut adjusted = false;

        if error > 0.0 {
            // Draining too fast — throttle.
            state.distance_filter = (state.distance_filter * THROTTLE_FACTOR)
                .clamp(MIN_DISTANCE_FILTER, MAX_DISTANCE_FILTER);
            adjusted = true;
            if state.accuracy_index < 4 {
                state.accuracy_index += 1;
            }
            if let Some(interval) = state.periodic_interval {
                state.periodic_interval = Some(
                    ((interval as f64 * THROTTLE_FACTOR) as i32).clamp(60, 43200),
                );
            }
        } else {
            // Under budget — can improve.
            state.distance_filter = (state.distance_filter * BOOST_FACTOR)
                .clamp(MIN_DISTANCE_FILTER, MAX_DISTANCE_FILTER);
            adjusted = true;
            if state.accuracy_index > 0 {
                state.accuracy_index -= 1;
            }
            if let Some(interval) = state.periodic_interval {
                state.periodic_interval = Some(
                    ((interval as f64 * BOOST_FACTOR) as i32).clamp(60, 43200),
                );
            }
        }

        if !adjusted {
            return None;
        }

        Some(BudgetAdjustmentEvent {
            current_battery_drain: drain_per_hour,
            target_budget: self.target_budget_per_hour,
            new_distance_filter: state.distance_filter,
            new_desired_accuracy: state.accuracy_index,
            new_periodic_interval: state.periodic_interval,
        })
    }

    pub fn reset(&self) {
        let mut state = self.state.lock().unwrap();
        state.prev_battery_level = None;
        state.prev_sample_time_ms = None;
    }

    pub fn distance_filter(&self) -> f64 {
        self.state.lock().unwrap().distance_filter
    }

    pub fn accuracy_index(&self) -> i32 {
        self.state.lock().unwrap().accuracy_index
    }

    pub fn periodic_interval(&self) -> Option<i32> {
        self.state.lock().unwrap().periodic_interval
    }
}
