use std::sync::Mutex;

#[derive(uniffi::Enum, Debug, Clone, Copy, PartialEq, Eq)]
pub enum TrackingMode {
    Continuous,
    StationaryGeofences,
    StationaryPeriodic,
}

#[derive(uniffi::Enum, Debug, Clone, Copy, PartialEq, Eq)]
pub enum CoordinatorAction {
    None,
    SwitchToContinuous,
    SwitchToStationaryGeofences,
    SwitchToStationaryPeriodic,
}

struct CoordinatorState {
    is_accel_moving: bool,
    is_speed_moving: bool,
    current_mode: TrackingMode,
    use_geofences_when_stationary: bool,
}

#[derive(uniffi::Object)]
pub struct SmartMotionCoordinator {
    state: Mutex<CoordinatorState>,
}

#[uniffi::export]
impl SmartMotionCoordinator {
    #[uniffi::constructor]
    pub fn new(use_geofences_when_stationary: bool) -> Self {
        Self {
            state: Mutex::new(CoordinatorState {
                is_accel_moving: false,
                is_speed_moving: true, // Default to true matching Kotlin/Swift
                current_mode: TrackingMode::Continuous, // Assume starting in continuous
                use_geofences_when_stationary,
            }),
        }
    }

    pub fn on_accel_state_change(&self, is_moving: bool) -> CoordinatorAction {
        let mut state = self.state.lock().unwrap();
        if state.is_accel_moving == is_moving {
            return CoordinatorAction::None;
        }
        state.is_accel_moving = is_moving;
        Self::evaluate_state(&mut state)
    }

    pub fn on_speed_state_change(&self, is_moving: bool) -> CoordinatorAction {
        let mut state = self.state.lock().unwrap();
        if state.is_speed_moving == is_moving {
            return CoordinatorAction::None;
        }
        state.is_speed_moving = is_moving;
        Self::evaluate_state(&mut state)
    }
    
    pub fn set_current_mode(&self, mode: TrackingMode) {
        let mut state = self.state.lock().unwrap();
        state.current_mode = mode;
    }
    
    pub fn set_use_geofences_when_stationary(&self, use_geofences: bool) {
        let mut state = self.state.lock().unwrap();
        state.use_geofences_when_stationary = use_geofences;
    }

    pub fn is_accel_moving(&self) -> bool {
        self.state.lock().unwrap().is_accel_moving
    }

    pub fn is_speed_moving(&self) -> bool {
        self.state.lock().unwrap().is_speed_moving
    }
}

impl SmartMotionCoordinator {
    fn evaluate_state(state: &mut CoordinatorState) -> CoordinatorAction {
        let should_be_moving = state.is_accel_moving || state.is_speed_moving;

        if should_be_moving && state.current_mode != TrackingMode::Continuous {
            state.current_mode = TrackingMode::Continuous;
            CoordinatorAction::SwitchToContinuous
        } else if !should_be_moving && state.current_mode == TrackingMode::Continuous {
            if state.use_geofences_when_stationary {
                state.current_mode = TrackingMode::StationaryGeofences;
                CoordinatorAction::SwitchToStationaryGeofences
            } else {
                state.current_mode = TrackingMode::StationaryPeriodic;
                CoordinatorAction::SwitchToStationaryPeriodic
            }
        } else {
            CoordinatorAction::None
        }
    }
}
