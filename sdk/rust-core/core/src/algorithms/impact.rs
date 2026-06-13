//! Crash & fall detection.
//!
//! Safety-critical, so the design centers on **false-positive suppression**: a
//! crash is only raised when an impact spike is *corroborated* by motion
//! context (the device was moving at speed), never from a lone spike. Detection
//! emits a `potential_*` event with a confirmation deadline so the host app can
//! show a cancel countdown (standard SOS UX); if not cancelled, a confirmed
//! event fires. Tracelet provides the trustworthy trigger + cancel window; it
//! never places emergency calls itself.
//!
//! Consumes the peak magnitude from the [`AccelWindow`](crate::algorithms::sensor_features)
//! keystone plus speed/context supplied by the location pipeline.

use std::collections::HashMap;
use std::sync::Mutex;

/// Impact detector tuning.
#[derive(uniffi::Record, Clone, Copy, Debug)]
pub struct ImpactConfig {
    /// Enable vehicle crash detection.
    pub enable_crash: bool,
    /// Enable personal fall detection (best-effort; more false positives).
    pub enable_fall: bool,
    /// Impact magnitude (g) for a crash candidate.
    pub crash_g_threshold: f64,
    /// Pre-impact speed (km/h) required to corroborate a crash.
    pub crash_min_speed_kmh: f64,
    /// Impact magnitude (g) for a fall candidate.
    pub fall_g_threshold: f64,
    /// Countdown (ms) before a candidate auto-confirms.
    pub confirm_window_ms: i64,
    /// Suppress candidates below this confidence.
    pub min_confidence: f64,
}

impl Default for ImpactConfig {
    fn default() -> Self {
        Self {
            enable_crash: false,
            enable_fall: false,
            crash_g_threshold: 3.0,
            crash_min_speed_kmh: 25.0,
            fall_g_threshold: 2.5,
            confirm_window_ms: 15000,
            min_confidence: 0.6,
        }
    }
}

/// An impact event.
#[derive(uniffi::Record, Clone, Debug, PartialEq)]
pub struct ImpactEvent {
    /// `potential_crash` | `crash` | `potential_fall` | `fall`.
    pub kind: String,
    /// Candidate id — pair `potential_*` with its later `confirm`/`cancel`.
    pub id: i64,
    /// 0–1 confidence.
    pub confidence: f64,
    /// Peak magnitude (g) of the impact.
    pub peak_g: f64,
    /// Speed before impact (m/s).
    pub speed_before: f64,
    pub latitude: f64,
    pub longitude: f64,
    pub timestamp_ms: i64,
    /// For `potential_*`: epoch ms at which it auto-confirms unless cancelled.
    pub confirm_deadline_ms: i64,
}

struct Pending {
    is_crash: bool,
    confidence: f64,
    peak_g: f64,
    speed_before: f64,
    latitude: f64,
    longitude: f64,
    deadline_ms: i64,
}

struct DetectorState {
    next_id: i64,
    pending: HashMap<i64, Pending>,
}

/// Detects crash/fall impacts with a confirmation window.
#[derive(uniffi::Object)]
pub struct ImpactDetector {
    config: ImpactConfig,
    state: Mutex<DetectorState>,
}

fn confidence(peak_g: f64, threshold: f64, speed_factor: f64) -> f64 {
    let over = if threshold > 0.0 {
        ((peak_g - threshold) / threshold).clamp(0.0, 1.0)
    } else {
        1.0
    };
    (0.5 + 0.5 * over).min(1.0) * speed_factor
}

#[uniffi::export]
impl ImpactDetector {
    /// Creates a detector. Pass `None` for defaults (both detections off).
    #[uniffi::constructor]
    pub fn new(config: Option<ImpactConfig>) -> Self {
        Self {
            config: config.unwrap_or_default(),
            state: Mutex::new(DetectorState {
                next_id: 1,
                pending: HashMap::new(),
            }),
        }
    }

    /// Feeds one accel window's peak plus motion context. Returns a
    /// `potential_*` event when an impact is detected (and registers it for
    /// confirmation), else `None`.
    pub fn on_impact_window(
        &self,
        peak_g: f64,
        speed_before_mps: f64,
        is_on_foot: bool,
        latitude: f64,
        longitude: f64,
        now_ms: i64,
    ) -> Option<ImpactEvent> {
        let cfg = &self.config;
        let speed_kmh = speed_before_mps * 3.6;

        // ── Crash: spike corroborated by pre-impact speed ──
        if cfg.enable_crash
            && peak_g >= cfg.crash_g_threshold
            && speed_kmh >= cfg.crash_min_speed_kmh
        {
            let conf = confidence(peak_g, cfg.crash_g_threshold, 1.0);
            if conf >= cfg.min_confidence {
                return Some(self.register(true, conf, peak_g, speed_before_mps, latitude, longitude, now_ms));
            }
        }

        // ── Fall: spike while on foot at low speed (best-effort, opt-in) ──
        if cfg.enable_fall
            && is_on_foot
            && peak_g >= cfg.fall_g_threshold
            && speed_kmh < cfg.crash_min_speed_kmh
        {
            // On-foot context gives weaker corroboration ⇒ scale confidence down.
            let conf = confidence(peak_g, cfg.fall_g_threshold, 0.85);
            if conf >= cfg.min_confidence {
                return Some(self.register(false, conf, peak_g, speed_before_mps, latitude, longitude, now_ms));
            }
        }

        None
    }

    /// Fires confirmed events for candidates whose deadline has elapsed without
    /// a cancel. Call on a timer.
    pub fn check_confirmations(&self, now_ms: i64) -> Vec<ImpactEvent> {
        let mut st = self.state.lock().unwrap();
        let due: Vec<i64> = st
            .pending
            .iter()
            .filter(|(_, p)| now_ms >= p.deadline_ms)
            .map(|(id, _)| *id)
            .collect();

        let mut out = Vec::new();
        for id in due {
            if let Some(p) = st.pending.remove(&id) {
                out.push(confirmed_event(id, &p, now_ms));
            }
        }
        out
    }

    /// User (or app) explicitly confirms a candidate is a real emergency now.
    pub fn confirm(&self, id: i64, now_ms: i64) -> Option<ImpactEvent> {
        let mut st = self.state.lock().unwrap();
        st.pending.remove(&id).map(|p| confirmed_event(id, &p, now_ms))
    }

    /// User cancels a candidate ("I'm fine") — no confirmed event will fire.
    pub fn cancel(&self, id: i64) -> bool {
        self.state.lock().unwrap().pending.remove(&id).is_some()
    }

    /// Number of candidates awaiting confirmation.
    pub fn pending_count(&self) -> u32 {
        self.state.lock().unwrap().pending.len() as u32
    }

    /// Clears all pending candidates.
    pub fn reset(&self) {
        let mut st = self.state.lock().unwrap();
        st.pending.clear();
    }
}

impl ImpactDetector {
    #[allow(clippy::too_many_arguments)]
    fn register(
        &self,
        is_crash: bool,
        conf: f64,
        peak_g: f64,
        speed_before: f64,
        latitude: f64,
        longitude: f64,
        now_ms: i64,
    ) -> ImpactEvent {
        let mut st = self.state.lock().unwrap();
        let id = st.next_id;
        st.next_id += 1;
        let deadline = now_ms + self.config.confirm_window_ms;
        st.pending.insert(
            id,
            Pending {
                is_crash,
                confidence: conf,
                peak_g,
                speed_before,
                latitude,
                longitude,
                deadline_ms: deadline,
            },
        );
        ImpactEvent {
            kind: if is_crash { "potential_crash" } else { "potential_fall" }.to_string(),
            id,
            confidence: conf,
            peak_g,
            speed_before,
            latitude,
            longitude,
            timestamp_ms: now_ms,
            confirm_deadline_ms: deadline,
        }
    }
}

fn confirmed_event(id: i64, p: &Pending, now_ms: i64) -> ImpactEvent {
    ImpactEvent {
        kind: if p.is_crash { "crash" } else { "fall" }.to_string(),
        id,
        confidence: p.confidence,
        peak_g: p.peak_g,
        speed_before: p.speed_before,
        latitude: p.latitude,
        longitude: p.longitude,
        timestamp_ms: now_ms,
        confirm_deadline_ms: now_ms,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn crash_cfg() -> ImpactConfig {
        ImpactConfig {
            enable_crash: true,
            confirm_window_ms: 15000,
            ..Default::default()
        }
    }

    #[test]
    fn lone_spike_without_speed_is_not_a_crash() {
        let d = ImpactDetector::new(Some(crash_cfg()));
        // 4 g but stationary ⇒ no crash (corroboration fails).
        assert!(d.on_impact_window(4.0, 0.0, false, 0.0, 0.0, 0).is_none());
    }

    #[test]
    fn crash_candidate_then_auto_confirm() {
        let d = ImpactDetector::new(Some(crash_cfg()));
        let speed = 60.0 / 3.6;
        let cand = d.on_impact_window(4.0, speed, false, 1.0, 2.0, 1000).unwrap();
        assert_eq!(cand.kind, "potential_crash");
        assert_eq!(d.pending_count(), 1);

        // Before deadline ⇒ nothing.
        assert!(d.check_confirmations(5000).is_empty());
        // After deadline ⇒ confirmed crash.
        let confirmed = d.check_confirmations(20000);
        assert_eq!(confirmed.len(), 1);
        assert_eq!(confirmed[0].kind, "crash");
        assert_eq!(confirmed[0].id, cand.id);
        assert_eq!(d.pending_count(), 0);
    }

    #[test]
    fn cancel_prevents_confirmation() {
        let d = ImpactDetector::new(Some(crash_cfg()));
        let cand = d.on_impact_window(5.0, 70.0 / 3.6, false, 0.0, 0.0, 0).unwrap();
        assert!(d.cancel(cand.id));
        assert!(d.check_confirmations(60000).is_empty());
        assert_eq!(d.pending_count(), 0);
    }

    #[test]
    fn explicit_confirm_fires_immediately_and_once() {
        let d = ImpactDetector::new(Some(crash_cfg()));
        let cand = d.on_impact_window(4.5, 80.0 / 3.6, false, 0.0, 0.0, 0).unwrap();
        let ev = d.confirm(cand.id, 2000).unwrap();
        assert_eq!(ev.kind, "crash");
        // Not double-emitted later.
        assert!(d.check_confirmations(60000).is_empty());
    }

    #[test]
    fn fall_disabled_by_default() {
        let d = ImpactDetector::new(Some(crash_cfg())); // enable_fall = false
        assert!(d.on_impact_window(3.0, 1.0, true, 0.0, 0.0, 0).is_none());
    }

    #[test]
    fn fall_detected_when_enabled() {
        let cfg = ImpactConfig {
            enable_fall: true,
            ..Default::default()
        };
        let d = ImpactDetector::new(Some(cfg));
        // A real fall spikes well past the 2.5 g floor; 3.0 g is below the
        // confidence gate by design (weak corroboration on foot).
        let cand = d.on_impact_window(5.0, 0.5, true, 0.0, 0.0, 0).unwrap();
        assert_eq!(cand.kind, "potential_fall");
        let confirmed = d.check_confirmations(60000);
        assert_eq!(confirmed[0].kind, "fall");
    }

    #[test]
    fn weak_spike_below_threshold_ignored() {
        let d = ImpactDetector::new(Some(crash_cfg()));
        assert!(d.on_impact_window(2.0, 60.0 / 3.6, false, 0.0, 0.0, 0).is_none());
    }
}
