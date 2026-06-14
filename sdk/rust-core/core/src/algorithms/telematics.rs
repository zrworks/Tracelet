//! Driving-behavior (telematics) event detection — Tier 1, GPS-derived.
//!
//! Scores successive accepted location fixes into driving events:
//! `harsh_braking`, `harsh_acceleration`, `harsh_cornering`, and `speeding`.
//! All inputs (speed, heading, timestamp) already exist in the location
//! pipeline, so this tier needs **no new sensors** and runs on every platform.
//!
//! GPS speed is ~1 Hz and noisy, so the engine favors **specificity over
//! sensitivity**: thresholds are expressed in g, gaps are rejected, and a
//! per-kind debounce collapses one maneuver into one event. A fused
//! accelerometer tier (higher fidelity + crash detection) is layered on later
//! via the accel-sample feed; this module is the GPS-only foundation.

use std::sync::Mutex;

/// Standard gravity (m/s²) used to express accelerations in g.
const GRAVITY: f64 = 9.81;

/// Tunable thresholds for driving-event detection. Defaults follow common
/// usage-based-insurance / fleet practice and are overridable by the caller.
#[derive(uniffi::Record, Clone, Copy, Debug)]
pub struct TelematicsConfig {
    /// Longitudinal deceleration (g) above which `harsh_braking` fires.
    pub harsh_braking_g: f64,
    /// Longitudinal acceleration (g) above which `harsh_acceleration` fires.
    pub harsh_acceleration_g: f64,
    /// Lateral acceleration (g) above which `harsh_cornering` fires.
    pub harsh_cornering_g: f64,
    /// Global speed limit in km/h. `0` disables threshold-based speeding
    /// (per-geofence limits can still be applied by the caller).
    pub speed_limit_kmh: f64,
    /// Grace (km/h) added to the limit before speeding counts.
    pub speeding_tolerance_kmh: f64,
    /// Sustained time over the limit (ms) before `speeding` fires.
    pub speeding_min_duration_ms: i64,
    /// Suppress brake/accel/corner events below this speed (km/h) to avoid
    /// parking-lot / GPS-jitter noise.
    pub min_speed_for_events_kmh: f64,
    /// Minimum time between two events of the same kind (ms) — debounce so a
    /// single maneuver spanning several fixes yields one event.
    pub event_debounce_ms: i64,
}

impl Default for TelematicsConfig {
    fn default() -> Self {
        Self {
            harsh_braking_g: 0.40,
            harsh_acceleration_g: 0.35,
            harsh_cornering_g: 0.40,
            speed_limit_kmh: 0.0,
            speeding_tolerance_kmh: 5.0,
            speeding_min_duration_ms: 3000,
            min_speed_for_events_kmh: 5.0,
            event_debounce_ms: 2000,
        }
    }
}

/// A detected driving event.
#[derive(uniffi::Record, Clone, Debug, PartialEq)]
pub struct DrivingEvent {
    /// `harsh_braking` | `harsh_acceleration` | `harsh_cornering` | `speeding`.
    pub kind: String,
    /// Normalized 0–1 severity (how far past the threshold).
    pub severity: f64,
    /// Speed at the event (m/s).
    pub speed: f64,
    /// The measured magnitude that triggered it: g for harsh events, km/h over
    /// the limit for speeding.
    pub value: f64,
    pub latitude: f64,
    pub longitude: f64,
    pub timestamp_ms: i64,
}

struct TelematicsState {
    prev_speed: Option<f64>,
    prev_heading: Option<f64>,
    prev_ts: Option<i64>,
    /// When the device first went over the speed limit (None = under).
    speeding_since_ms: Option<i64>,
    /// Whether a speeding event has already fired for the current overspeed run.
    speeding_fired: bool,
    /// Last fire time per kind, for debounce.
    last_braking_ms: i64,
    last_accel_ms: i64,
    last_corner_ms: i64,
    /// Accumulated score penalty (driving score = 100 − penalty, clamped).
    penalty: f64,
}

impl TelematicsState {
    fn new() -> Self {
        Self {
            prev_speed: None,
            prev_heading: None,
            prev_ts: None,
            speeding_since_ms: None,
            speeding_fired: false,
            last_braking_ms: i64::MIN,
            last_accel_ms: i64::MIN,
            last_corner_ms: i64::MIN,
            penalty: 0.0,
        }
    }
}

/// Detects driving events from a stream of accepted location fixes.
#[derive(uniffi::Object)]
pub struct TelematicsEngine {
    config: TelematicsConfig,
    state: Mutex<TelematicsState>,
}

/// Normalizes a heading delta (degrees) to the range [-180, 180].
fn normalize_heading_delta(mut d: f64) -> f64 {
    while d > 180.0 {
        d -= 360.0;
    }
    while d < -180.0 {
        d += 360.0;
    }
    d
}

/// Severity as a fraction past threshold, clamped to [0, 1].
fn severity(magnitude: f64, threshold: f64) -> f64 {
    if threshold <= 0.0 {
        return 1.0;
    }
    ((magnitude - threshold) / threshold).clamp(0.0, 1.0)
}

#[uniffi::export]
impl TelematicsEngine {
    /// Creates an engine. Pass `None` for default thresholds.
    #[uniffi::constructor]
    pub fn new(config: Option<TelematicsConfig>) -> Self {
        Self {
            config: config.unwrap_or_default(),
            state: Mutex::new(TelematicsState::new()),
        }
    }

    /// Processes one accepted fix and returns any driving events it triggers.
    ///
    /// `speed` is m/s, `heading` is degrees (negative ⇒ unknown), `timestamp_ms`
    /// is epoch ms. Returns empty until a second fix establishes deltas, on
    /// time gaps, or when nothing crosses a threshold.
    pub fn process_fix(
        &self,
        speed: f64,
        heading: f64,
        latitude: f64,
        longitude: f64,
        timestamp_ms: i64,
    ) -> Vec<DrivingEvent> {
        let cfg = &self.config;
        let mut st = self.state.lock().unwrap();
        let mut events = Vec::new();

        // Speeding is evaluated from the absolute speed (no previous fix needed).
        if cfg.speed_limit_kmh > 0.0 {
            let speed_kmh = speed * 3.6;
            let ceiling = cfg.speed_limit_kmh + cfg.speeding_tolerance_kmh;
            if speed_kmh > ceiling {
                let since = *st.speeding_since_ms.get_or_insert(timestamp_ms);
                if !st.speeding_fired
                    && timestamp_ms - since >= cfg.speeding_min_duration_ms
                {
                    st.speeding_fired = true;
                    let over = speed_kmh - cfg.speed_limit_kmh;
                    let sev = severity(over, cfg.speeding_tolerance_kmh.max(1.0));
                    st.penalty += 5.0 * (0.5 + sev);
                    events.push(DrivingEvent {
                        kind: "speeding".to_string(),
                        severity: sev,
                        speed,
                        value: over,
                        latitude,
                        longitude,
                        timestamp_ms,
                    });
                }
            } else {
                // Back under the ceiling — reset the overspeed run.
                st.speeding_since_ms = None;
                st.speeding_fired = false;
            }
        }

        // Harsh events need a previous fix and a sane time delta.
        let (prev_speed, prev_ts) = match (st.prev_speed, st.prev_ts) {
            (Some(s), Some(t)) => (s, t),
            _ => {
                st.prev_speed = Some(speed);
                st.prev_heading = Some(heading);
                st.prev_ts = Some(timestamp_ms);
                return events;
            }
        };
        let prev_heading = st.prev_heading;

        let dt = (timestamp_ms - prev_ts) as f64 / 1000.0;
        // Reject non-positive or large gaps (signal loss / resume).
        let valid_dt = dt > 0.0 && dt <= 10.0;
        // Suppress maneuver events at very low speed (jitter dominates).
        let fast_enough =
            speed.max(prev_speed) * 3.6 >= cfg.min_speed_for_events_kmh;

        if valid_dt && fast_enough {
            // ── Longitudinal: braking / acceleration ──
            let long_accel = (speed - prev_speed) / dt; // m/s²
            let long_g = long_accel / GRAVITY;

            if long_g <= -cfg.harsh_braking_g
                && timestamp_ms.saturating_sub(st.last_braking_ms) >= cfg.event_debounce_ms
            {
                st.last_braking_ms = timestamp_ms;
                let mag = long_g.abs();
                let sev = severity(mag, cfg.harsh_braking_g);
                st.penalty += 4.0 * (0.5 + sev);
                events.push(DrivingEvent {
                    kind: "harsh_braking".to_string(),
                    severity: sev,
                    speed,
                    value: mag,
                    latitude,
                    longitude,
                    timestamp_ms,
                });
            } else if long_g >= cfg.harsh_acceleration_g
                && timestamp_ms.saturating_sub(st.last_accel_ms) >= cfg.event_debounce_ms
            {
                st.last_accel_ms = timestamp_ms;
                let sev = severity(long_g, cfg.harsh_acceleration_g);
                st.penalty += 3.0 * (0.5 + sev);
                events.push(DrivingEvent {
                    kind: "harsh_acceleration".to_string(),
                    severity: sev,
                    speed,
                    value: long_g,
                    latitude,
                    longitude,
                    timestamp_ms,
                });
            }

            // ── Lateral: cornering (needs valid headings) ──
            if heading >= 0.0 {
                if let Some(ph) = prev_heading.filter(|h| *h >= 0.0) {
                    let yaw_rad = normalize_heading_delta(heading - ph).to_radians();
                    let yaw_rate = yaw_rad / dt; // rad/s
                    let lateral = (yaw_rate * speed).abs(); // m/s²
                    let lat_g = lateral / GRAVITY;
                    if lat_g >= cfg.harsh_cornering_g
                        && timestamp_ms.saturating_sub(st.last_corner_ms) >= cfg.event_debounce_ms
                    {
                        st.last_corner_ms = timestamp_ms;
                        let sev = severity(lat_g, cfg.harsh_cornering_g);
                        st.penalty += 3.0 * (0.5 + sev);
                        events.push(DrivingEvent {
                            kind: "harsh_cornering".to_string(),
                            severity: sev,
                            speed,
                            value: lat_g,
                            latitude,
                            longitude,
                            timestamp_ms,
                        });
                    }
                }
            }
        }

        st.prev_speed = Some(speed);
        st.prev_heading = Some(heading);
        st.prev_ts = Some(timestamp_ms);
        events
    }

    /// Rolling driving score in [0, 100] (100 = flawless). Penalties accrue
    /// per event weighted by severity.
    pub fn current_score(&self) -> f64 {
        let penalty = self.state.lock().unwrap().penalty;
        (100.0 - penalty).clamp(0.0, 100.0)
    }

    /// Clears all state (call on trip start / tracking restart).
    pub fn reset(&self) {
        *self.state.lock().unwrap() = TelematicsState::new();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn engine() -> TelematicsEngine {
        TelematicsEngine::new(None)
    }

    // Helper: feed a fix and return the kinds emitted.
    fn kinds(ev: &[DrivingEvent]) -> Vec<&str> {
        ev.iter().map(|e| e.kind.as_str()).collect()
    }

    #[test]
    fn first_fix_emits_nothing() {
        let e = engine();
        assert!(e.process_fix(20.0, 90.0, 0.0, 0.0, 0).is_empty());
    }

    #[test]
    fn harsh_braking_detected() {
        let e = engine();
        e.process_fix(20.0, 90.0, 0.0, 0.0, 0); // prime
        // 20 → 8 m/s in 1 s = -12 m/s² ≈ -1.22 g
        let ev = e.process_fix(8.0, 90.0, 0.0, 0.0, 1000);
        assert_eq!(kinds(&ev), vec!["harsh_braking"]);
        assert!(ev[0].severity > 0.5);
    }

    #[test]
    fn harsh_acceleration_detected() {
        let e = engine();
        e.process_fix(5.0, 90.0, 0.0, 0.0, 0);
        // 5 → 12 m/s in 1 s = 7 m/s² ≈ 0.71 g (> 0.35)
        let ev = e.process_fix(12.0, 90.0, 0.0, 0.0, 1000);
        assert_eq!(kinds(&ev), vec!["harsh_acceleration"]);
    }

    #[test]
    fn gentle_changes_ignored() {
        let e = engine();
        e.process_fix(10.0, 90.0, 0.0, 0.0, 0);
        // +1 m/s over 1 s ≈ 0.1 g
        assert!(e.process_fix(11.0, 90.0, 0.0, 0.0, 1000).is_empty());
    }

    #[test]
    fn harsh_cornering_detected() {
        let e = engine();
        e.process_fix(15.0, 0.0, 0.0, 0.0, 0);
        // 30° turn in 1 s at 15 m/s ⇒ lateral ≈ 7.85 m/s² ≈ 0.8 g
        let ev = e.process_fix(15.0, 30.0, 0.0, 0.0, 1000);
        assert!(kinds(&ev).contains(&"harsh_cornering"));
    }

    #[test]
    fn cornering_skipped_when_heading_unknown() {
        let e = engine();
        e.process_fix(15.0, -1.0, 0.0, 0.0, 0);
        let ev = e.process_fix(15.0, -1.0, 0.0, 0.0, 1000);
        assert!(!kinds(&ev).contains(&"harsh_cornering"));
    }

    #[test]
    fn low_speed_suppresses_events() {
        let e = engine();
        e.process_fix(1.0, 90.0, 0.0, 0.0, 0);
        // big relative change but both speeds < 5 km/h
        assert!(e.process_fix(0.0, 90.0, 0.0, 0.0, 1000).is_empty());
    }

    #[test]
    fn time_gap_rejected() {
        let e = engine();
        e.process_fix(20.0, 90.0, 0.0, 0.0, 0);
        // 30 s gap (> 10 s) ⇒ no event despite big delta
        assert!(e.process_fix(2.0, 90.0, 0.0, 0.0, 30_000).is_empty());
    }

    #[test]
    fn braking_debounced_across_adjacent_fixes() {
        let e = engine();
        e.process_fix(25.0, 90.0, 0.0, 0.0, 0);
        // Three consecutive hard-braking samples 500 ms apart; debounce = 2 s.
        let mut total = 0;
        for (i, s) in [15.0, 6.0, 0.0].iter().enumerate() {
            let t = 500 * (i as i64 + 1);
            total += e
                .process_fix(*s, 90.0, 0.0, 0.0, t)
                .iter()
                .filter(|e| e.kind == "harsh_braking")
                .count();
        }
        assert_eq!(total, 1, "debounce should collapse one maneuver to one event");
    }

    #[test]
    fn speeding_requires_sustained_duration() {
        let cfg = TelematicsConfig {
            speed_limit_kmh: 50.0,
            ..Default::default()
        };
        let e = TelematicsEngine::new(Some(cfg));
        // 60 km/h = 16.67 m/s, ceiling = 55 km/h. min duration 3 s.
        let s = 60.0 / 3.6;
        assert!(e.process_fix(s, 90.0, 0.0, 0.0, 0).is_empty()); // just started
        assert!(e.process_fix(s, 90.0, 0.0, 0.0, 2000).is_empty()); // 2 s < 3 s
        let ev = e.process_fix(s, 90.0, 0.0, 0.0, 3500); // 3.5 s ≥ 3 s
        assert!(kinds(&ev).contains(&"speeding"));
        // Doesn't re-fire while still speeding.
        assert!(!kinds(&e.process_fix(s, 90.0, 0.0, 0.0, 5000)).contains(&"speeding"));
    }

    #[test]
    fn speeding_resets_when_back_under_limit() {
        let cfg = TelematicsConfig {
            speed_limit_kmh: 50.0,
            ..Default::default()
        };
        let e = TelematicsEngine::new(Some(cfg));
        let fast = 60.0 / 3.6;
        let slow = 40.0 / 3.6;
        e.process_fix(fast, 90.0, 0.0, 0.0, 0);
        e.process_fix(fast, 90.0, 0.0, 0.0, 4000); // fires
        e.process_fix(slow, 90.0, 0.0, 0.0, 6000); // back under — reset
        // New overspeed run can fire again after its own duration.
        e.process_fix(fast, 90.0, 0.0, 0.0, 8000);
        let ev = e.process_fix(fast, 90.0, 0.0, 0.0, 12_000);
        assert!(kinds(&ev).contains(&"speeding"));
    }

    #[test]
    fn score_decreases_after_events_and_resets() {
        let e = engine();
        assert_eq!(e.current_score(), 100.0);
        e.process_fix(25.0, 90.0, 0.0, 0.0, 0);
        e.process_fix(5.0, 90.0, 0.0, 0.0, 1000); // hard brake
        assert!(e.current_score() < 100.0);
        e.reset();
        assert_eq!(e.current_score(), 100.0);
    }
}
