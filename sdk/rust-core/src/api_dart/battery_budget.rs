use crate::state::battery_budget::{BatteryBudgetEngine as NativeEngine, BudgetAdjustmentEvent};

pub struct BatteryBudgetEngineDart {
    inner: std::sync::Mutex<NativeEngine>,
    interval_ms: std::sync::Mutex<i64>,
    throttled: std::sync::Mutex<bool>,
    is_charging: std::sync::Mutex<bool>,
}

impl BatteryBudgetEngineDart {
    #[flutter_rust_bridge::frb(sync)]
    pub fn new(
        target_budget_per_hour: f64,
        initial_distance_filter: f64,
        initial_accuracy_index: i32,
        initial_periodic_interval: Option<i32>,
    ) -> Self {
        Self {
            inner: std::sync::Mutex::new(NativeEngine::new(
                target_budget_per_hour,
                initial_distance_filter,
                initial_accuracy_index,
                initial_periodic_interval,
            )),
            interval_ms: std::sync::Mutex::new(0),
            throttled: std::sync::Mutex::new(false),
            is_charging: std::sync::Mutex::new(false),
        }
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn process_sample(&self, level: f64, is_charging: bool, timestamp_ms: i64) -> Option<BudgetAdjustmentEvent> {
        let inner = self.inner.lock().unwrap();
        let mut charging_state = self.is_charging.lock().unwrap();
        *charging_state = is_charging;
        
        let adjustment = inner.process_sample(level, timestamp_ms);
        if let Some(adj) = adjustment {
            if let Some(interval) = adj.new_periodic_interval {
                *self.interval_ms.lock().unwrap() = (interval as i64) * 1000;
            }
            *self.throttled.lock().unwrap() = adj.new_distance_filter > 100.0;
        }
        adjustment
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn reset(&self) {
        let inner = self.inner.lock().unwrap();
        inner.reset();
        
        // We probably don't reset interval/throttled state here as they represent configuration,
        // but resetting the engine drops the baseline.
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn get_recommended_interval_ms(&self, default_interval_ms: i64) -> i64 {
        let interval = *self.interval_ms.lock().unwrap();
        if interval > 0 {
            interval
        } else {
            default_interval_ms
        }
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn should_throttle_location(&self) -> bool {
        *self.throttled.lock().unwrap()
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn is_charging(&self) -> bool {
        *self.is_charging.lock().unwrap()
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn get_distance_filter(&self) -> f64 {
        let inner = self.inner.lock().unwrap();
        inner.distance_filter()
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn get_accuracy_index(&self) -> i32 {
        let inner = self.inner.lock().unwrap();
        inner.accuracy_index()
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn get_periodic_interval(&self) -> Option<i32> {
        let inner = self.inner.lock().unwrap();
        inner.periodic_interval()
    }
}
