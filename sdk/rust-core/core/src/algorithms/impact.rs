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
            // 2.0 g (not 3.0) based on the VZCrash field-data study (#173): at 3.0 g
            // the speed-gated rule missed ~48% of real crashes (median impact ~2.2 g).
            // Crash detection is opt-in with a cancel-countdown, so favour recall.
            crash_g_threshold: 2.0,
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
    /// Epoch ms the candidate was registered — used to scope the #181 Δv
    /// (post-impact speed) corroboration to a short window after the impact.
    registered_ms: i64,
    /// Whether a post-impact speed sample has already been folded in (#181), so
    /// the one-shot Δv corroboration doesn't apply twice.
    dv_evaluated: bool,
}

struct DetectorState {
    next_id: i64,
    pending: HashMap<i64, Pending>,
    /// Epoch ms of the last registered candidate, used to debounce the burst of
    /// windows a single crash produces (primary spike + bounce / secondary
    /// impacts) so one event doesn't raise several "Are you OK?" prompts.
    last_register_ms: i64,
}

/// Refractory period after a candidate is registered during which further
/// impacts are ignored as part of the same event.
const REGISTER_REFRACTORY_MS: i64 = 5_000;

/// Peak rotation rate (deg/s) that corroborates a crash (#179). A real collision
/// spins the device fast; this is well above everyday handling/road vibration.
const GYRO_CORROBORATION_DPS: f64 = 100.0;

/// When rotation corroborates the impact, the crash g-threshold is relaxed by
/// this factor — so a sub-threshold jolt accompanied by a hard spin still counts
/// as a crash. Recovers the recall that an accel-only threshold misses while a
/// gyro reading of 0 (or below [`GYRO_CORROBORATION_DPS`]) leaves behaviour
/// unchanged — no regression.
const GYRO_THRESHOLD_RELAX: f64 = 0.7;

/// Small confidence bump applied when rotation corroborates the impact.
const GYRO_CONFIDENCE_BOOST: f64 = 0.1;

/// When a free-fall precedes the impact (#180), the fall g-threshold is relaxed
/// by this factor. Free-fall (near-0 total acceleration) is the canonical first
/// phase of a real fall, so it strongly corroborates the subsequent jolt.
const FREEFALL_THRESHOLD_RELAX: f64 = 0.7;

/// Confidence bump when a free-fall precedes the impact.
const FREEFALL_CONFIDENCE_BOOST: f64 = 0.15;

/// Confidence bump when **post-impact stillness** corroborates a fall (#180) —
/// the third phase of the canonical free-fall → impact → stillness model: after
/// a real fall the body comes to rest, so the acceleration settles back near 1 g
/// with little variance. Without it, behaviour is unchanged (no regression).
const POSTIMPACT_STILL_CONFIDENCE_BOOST: f64 = 0.1;

/// Window (ms) after a crash candidate during which a post-impact speed sample is
/// accepted for Δv corroboration (#181). Covers the 1–2 s it takes a GPS fix to
/// reflect the post-collision speed without bleeding into a later, separate event.
const DV_CORROBORATION_WINDOW_MS: i64 = 4_000;

/// Fraction of pre-impact speed that must vanish for a "sharp collapse" that
/// strongly corroborates a crash (#181) — e.g. 60 km/h falling to ≤ 24 km/h. The
/// simple window max−min Δv proxy was a weak discriminator (near-misses also
/// brake hard, #173); this impact-instant pre→post collapse is the strong signal.
const DV_COLLAPSE_FRACTION: f64 = 0.6;

/// Confidence bump when a sharp post-impact speed collapse corroborates a crash.
/// Δv only ever *raises* confidence — it never auto-cancels a candidate, so a
/// crash that kills the GPS feed (no post-impact sample) is never suppressed.
const DV_CONFIDENCE_BOOST: f64 = 0.15;

/// Detects crash/fall impacts with a confirmation window.
#[derive(uniffi::Object)]
pub struct ImpactDetector {
    config: ImpactConfig,
    state: Mutex<DetectorState>,
}

/// Confidence for a corroborated impact, in `[0, 1]`.
///
/// A candidate that just meets its magnitude threshold (and passes the speed /
/// on-foot corroboration in the caller) scores the **base** confidence, scaling
/// up toward `1.0` as the peak exceeds the threshold. The base is chosen so a
/// fully-corroborated crash exactly at `crash_g_threshold` already clears the
/// default `min_confidence` (0.6) — i.e. the documented threshold *is* the real
/// threshold, rather than being silently raised by the confidence gate.
/// `speed_factor` < 1 (used for the weaker on-foot fall context) deliberately
/// keeps falls more conservative.
fn confidence(peak_g: f64, threshold: f64, speed_factor: f64) -> f64 {
    let over = if threshold > 0.0 {
        ((peak_g - threshold) / threshold).clamp(0.0, 1.0)
    } else {
        1.0
    };
    (0.6 + 0.4 * over).min(1.0) * speed_factor
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
                last_register_ms: i64::MIN,
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
        gyro_peak_dps: f64,
        was_in_free_fall: bool,
        post_impact_still: bool,
        is_on_foot: bool,
        latitude: f64,
        longitude: f64,
        now_ms: i64,
        // #183 ML gating (Replace mode): when `crash_proba >= 0` an ML crash model
        // is active and **replaces** the g-threshold crash rule — a crash fires on
        // `crash_proba >= crash_proba_threshold` (still speed-gated). Pass a
        // negative value (e.g. -1) when no model is loaded to use the rule.
        crash_proba: f64,
        crash_proba_threshold: f64,
    ) -> Option<ImpactEvent> {
        let cfg = &self.config;
        let speed_kmh = speed_before_mps * 3.6;
        let ml_active = crash_proba >= 0.0;

        // Gyroscope corroboration (#179): a hard spin alongside the jolt is a
        // strong crash signal, so relax the magnitude threshold and bump
        // confidence when present. gyro=0 ⇒ no change (no regression).
        let gyro_corroborated = gyro_peak_dps >= GYRO_CORROBORATION_DPS;

        // Debounce: a single crash spans several windows (primary spike + bounce
        // / secondary impacts). Suppress new candidates within the refractory
        // period of the last one so one event raises a single prompt.
        {
            let st = self.state.lock().unwrap();
            if now_ms.saturating_sub(st.last_register_ms) < REGISTER_REFRACTORY_MS {
                return None;
            }
        }

        // ── Crash: spike corroborated by pre-impact speed (+ optional rotation) ──
        // In Replace mode (ml_active) the ML probability decides the crash and the
        // g-threshold rule is bypassed; otherwise the rule applies (with the #179
        // gyro relax). Both paths keep the pre-impact speed gate.
        let crash_threshold = if gyro_corroborated {
            cfg.crash_g_threshold * GYRO_THRESHOLD_RELAX
        } else {
            cfg.crash_g_threshold
        };
        let crash_fires = if ml_active {
            crash_proba >= crash_proba_threshold
        } else {
            peak_g >= crash_threshold
        };
        if cfg.enable_crash && crash_fires && speed_kmh >= cfg.crash_min_speed_kmh {
            // ML mode: confidence = the model probability, and the model's
            // threshold IS the gate (don't also apply the rule's min_confidence).
            // Rule mode: scale confidence by how far peak exceeds the threshold and
            // require it to clear min_confidence.
            if ml_active {
                let conf = crash_proba.clamp(0.0, 1.0);
                return Some(self.register(true, conf, peak_g, speed_before_mps, latitude, longitude, now_ms));
            }
            let mut conf = confidence(peak_g, cfg.crash_g_threshold, 1.0);
            if gyro_corroborated {
                conf = (conf + GYRO_CONFIDENCE_BOOST).min(1.0);
            }
            if conf >= cfg.min_confidence {
                return Some(self.register(true, conf, peak_g, speed_before_mps, latitude, longitude, now_ms));
            }
        }

        // ── Fall: spike while on foot at low speed (best-effort, opt-in) ──
        // A preceding free-fall (#180) is the canonical first phase of a real
        // fall, so it relaxes the threshold and boosts confidence. Without it,
        // behaviour is unchanged (no regression).
        let fall_threshold = if was_in_free_fall {
            cfg.fall_g_threshold * FREEFALL_THRESHOLD_RELAX
        } else {
            cfg.fall_g_threshold
        };
        if cfg.enable_fall
            && is_on_foot
            && peak_g >= fall_threshold
            && speed_kmh < cfg.crash_min_speed_kmh
        {
            // On-foot context gives weaker corroboration ⇒ scale confidence down.
            let mut conf = confidence(peak_g, cfg.fall_g_threshold, 0.85);
            if was_in_free_fall {
                conf = (conf + FREEFALL_CONFIDENCE_BOOST).min(1.0);
            }
            // Third phase of the canonical fall model (#180): the body coming to
            // rest after the jolt. Combined with the free-fall first phase this
            // is the full free-fall → impact → stillness signature.
            if post_impact_still {
                conf = (conf + POSTIMPACT_STILL_CONFIDENCE_BOOST).min(1.0);
            }
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

    /// Folds a **post-impact speed** sample into the most recent pending crash
    /// for Δv corroboration (#181). Call once, ~1–2 s after a `potential_crash`,
    /// with the current GPS speed (m/s).
    ///
    /// A sharp collapse of the pre-impact speed (e.g. 60 → 0 km/h) is one of the
    /// strongest single crash discriminators, so it *raises* the candidate's
    /// confidence. It deliberately never lowers confidence or cancels: a real
    /// crash can kill the GPS feed (no/garbage post-impact sample), and crash
    /// detection favours recall behind a user cancel-countdown (#173). Returns
    /// `true` when a candidate was found and a collapse corroborated it.
    pub fn corroborate_dv(&self, speed_after_mps: f64, now_ms: i64) -> bool {
        let mut st = self.state.lock().unwrap();
        // Most recent un-evaluated crash candidate still inside the Δv window.
        let target = st
            .pending
            .iter()
            .filter(|(_, p)| {
                p.is_crash
                    && !p.dv_evaluated
                    && now_ms.saturating_sub(p.registered_ms) <= DV_CORROBORATION_WINDOW_MS
            })
            .max_by_key(|(_, p)| p.registered_ms)
            .map(|(id, _)| *id);

        let Some(id) = target else { return false };
        let Some(p) = st.pending.get_mut(&id) else { return false };
        p.dv_evaluated = true;

        let speed_before_kmh = p.speed_before * 3.6;
        let speed_after_kmh = speed_after_mps.max(0.0) * 3.6;
        let drop = speed_before_kmh - speed_after_kmh;
        if speed_before_kmh > 0.0 && drop >= DV_COLLAPSE_FRACTION * speed_before_kmh {
            p.confidence = (p.confidence + DV_CONFIDENCE_BOOST).min(1.0);
            true
        } else {
            false
        }
    }

    /// Number of candidates awaiting confirmation.
    pub fn pending_count(&self) -> u32 {
        self.state.lock().unwrap().pending.len() as u32
    }

    /// Clears all pending candidates.
    pub fn reset(&self) {
        let mut st = self.state.lock().unwrap();
        st.pending.clear();
        st.last_register_ms = i64::MIN;
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
        st.last_register_ms = now_ms;
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
                registered_ms: now_ms,
                dv_evaluated: false,
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
        assert!(d.on_impact_window(4.0, 0.0, 0.0, false, false, false, 0.0, 0.0, 0, -1.0, 0.5).is_none());
    }

    // ── #183 ML Replace mode: crash_proba >= 0 bypasses the g-threshold rule ──

    #[test]
    fn ml_rescues_a_sub_threshold_crash() {
        // 1.0 g is FAR below the 2.0 g rule, but the model says crash (0.8 >= 0.5)
        // and the device was moving ⇒ Replace mode fires (the recall the rule misses).
        let d = ImpactDetector::new(Some(crash_cfg()));
        let speed = 60.0 / 3.6;
        let cand = d.on_impact_window(1.0, speed, 0.0, false, false, false, 0.0, 0.0, 0, 0.8, 0.5);
        assert!(cand.is_some(), "ML should fire a sub-g-threshold crash");
        let c = cand.unwrap();
        assert_eq!(c.kind, "potential_crash");
        assert!((c.confidence - 0.8).abs() < 1e-9, "confidence == model probability");
    }

    #[test]
    fn ml_suppresses_a_high_g_event_below_probability() {
        // Big 6 g spike at speed (the rule WOULD fire), but the model says not a
        // crash (0.2 < 0.5) ⇒ Replace mode suppresses it.
        let d = ImpactDetector::new(Some(crash_cfg()));
        let speed = 60.0 / 3.6;
        assert!(d
            .on_impact_window(6.0, speed, 0.0, false, false, false, 0.0, 0.0, 0, 0.2, 0.5)
            .is_none());
    }

    #[test]
    fn ml_still_speed_gated() {
        // High probability but stationary ⇒ no crash (speed gate still applies).
        let d = ImpactDetector::new(Some(crash_cfg()));
        assert!(d
            .on_impact_window(1.0, 0.0, 0.0, false, false, false, 0.0, 0.0, 0, 0.99, 0.5)
            .is_none());
    }

    #[test]
    fn crash_candidate_then_auto_confirm() {
        let d = ImpactDetector::new(Some(crash_cfg()));
        let speed = 60.0 / 3.6;
        let cand = d.on_impact_window(4.0, speed, 0.0, false, false, false, 1.0, 2.0, 1000, -1.0, 0.5).unwrap();
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
        let cand = d.on_impact_window(5.0, 70.0 / 3.6, 0.0, false, false, false, 0.0, 0.0, 0, -1.0, 0.5).unwrap();
        assert!(d.cancel(cand.id));
        assert!(d.check_confirmations(60000).is_empty());
        assert_eq!(d.pending_count(), 0);
    }

    #[test]
    fn explicit_confirm_fires_immediately_and_once() {
        let d = ImpactDetector::new(Some(crash_cfg()));
        let cand = d.on_impact_window(4.5, 80.0 / 3.6, 0.0, false, false, false, 0.0, 0.0, 0, -1.0, 0.5).unwrap();
        let ev = d.confirm(cand.id, 2000).unwrap();
        assert_eq!(ev.kind, "crash");
        // Not double-emitted later.
        assert!(d.check_confirmations(60000).is_empty());
    }

    #[test]
    fn fall_disabled_by_default() {
        let d = ImpactDetector::new(Some(crash_cfg())); // enable_fall = false
        assert!(d.on_impact_window(3.0, 1.0, 0.0, false, false, true, 0.0, 0.0, 0, -1.0, 0.5).is_none());
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
        let cand = d.on_impact_window(5.0, 0.5, 0.0, false, false, true, 0.0, 0.0, 0, -1.0, 0.5).unwrap();
        assert_eq!(cand.kind, "potential_fall");
        let confirmed = d.check_confirmations(60000);
        assert_eq!(confirmed[0].kind, "fall");
    }

    #[test]
    fn free_fall_rescues_a_sub_threshold_fall() {
        // 2.0 g is below the 2.5 g fall threshold, so on its own it's not a fall...
        let cfg = ImpactConfig { enable_fall: true, ..Default::default() };
        let no_ff = ImpactDetector::new(Some(cfg));
        assert!(
            no_ff.on_impact_window(2.0, 0.5, 0.0, false, false, true, 0.0, 0.0, 0, -1.0, 0.5).is_none(),
            "sub-threshold jolt with no free-fall must NOT fire (no regression)"
        );
        // ...but a preceding free-fall corroborates it ⇒ fall.
        let with_ff = ImpactDetector::new(Some(ImpactConfig { enable_fall: true, ..Default::default() }));
        let cand = with_ff.on_impact_window(2.0, 0.5, 0.0, true, false, true, 0.0, 0.0, 0, -1.0, 0.5);
        assert!(cand.is_some(), "free-fall must rescue a sub-threshold fall (#180)");
        assert_eq!(cand.unwrap().kind, "potential_fall");
    }

    #[test]
    fn weak_spike_below_threshold_ignored() {
        // 1.0 g is below the 2.0 g default threshold ⇒ not a crash.
        let d = ImpactDetector::new(Some(crash_cfg()));
        assert!(d.on_impact_window(1.0, 60.0 / 3.6, 0.0, false, false, false, 0.0, 0.0, 0, -1.0, 0.5).is_none());
    }

    #[test]
    fn crash_at_exact_threshold_fires() {
        // A fully-corroborated crash exactly at the default 2.0 g threshold must
        // register — the confidence gate must not silently raise it.
        let d = ImpactDetector::new(Some(crash_cfg()));
        let cand = d.on_impact_window(2.0, 60.0 / 3.6, 0.0, false, false, false, 0.0, 0.0, 1000, -1.0, 0.5);
        assert!(cand.is_some());
        assert_eq!(cand.unwrap().kind, "potential_crash");
    }

    #[test]
    fn gyro_rotation_rescues_a_sub_threshold_crash() {
        // 1.6 g is below the 2.0 g threshold, so accel-only would miss it...
        let speed = 60.0 / 3.6;
        let no_gyro = ImpactDetector::new(Some(crash_cfg()));
        assert!(
            no_gyro.on_impact_window(1.6, speed, 0.0, false, false, false, 0.0, 0.0, 0, -1.0, 0.5).is_none(),
            "sub-threshold jolt with no rotation must NOT fire (no regression)"
        );
        // ...but a hard spin (>= 100 deg/s) corroborates it ⇒ crash.
        let with_gyro = ImpactDetector::new(Some(crash_cfg()));
        let cand = with_gyro.on_impact_window(1.6, speed, 150.0, false, false, false, 0.0, 0.0, 0, -1.0, 0.5);
        assert!(cand.is_some(), "rotation must rescue a sub-threshold crash (#179)");
        assert_eq!(cand.unwrap().kind, "potential_crash");
    }

    #[test]
    fn gyro_does_not_rescue_far_below_threshold() {
        // 1.0 g is below even the rotation-relaxed threshold (2.0 * 0.7 = 1.4) ⇒ no crash.
        let d = ImpactDetector::new(Some(crash_cfg()));
        assert!(d.on_impact_window(1.0, 60.0 / 3.6, 200.0, false, false, false, 0.0, 0.0, 0, -1.0, 0.5).is_none());
    }

    #[test]
    fn one_crash_burst_yields_a_single_candidate() {
        // Primary spike + bounce/secondary impacts within the refractory window
        // must not spawn multiple candidates.
        let d = ImpactDetector::new(Some(crash_cfg()));
        let speed = 60.0 / 3.6;
        assert!(d.on_impact_window(5.0, speed, 0.0, false, false, false, 0.0, 0.0, 1000, -1.0, 0.5).is_some());
        assert!(d.on_impact_window(4.0, speed, 0.0, false, false, false, 0.0, 0.0, 1500, -1.0, 0.5).is_none()); // bounce
        assert!(d.on_impact_window(6.0, speed, 0.0, false, false, false, 0.0, 0.0, 2000, -1.0, 0.5).is_none()); // secondary
        assert_eq!(d.pending_count(), 1);
        // A genuinely separate impact after the refractory period is allowed.
        assert!(d.on_impact_window(5.0, speed, 0.0, false, false, false, 0.0, 0.0, 1000 + REGISTER_REFRACTORY_MS, -1.0, 0.5).is_some());
        assert_eq!(d.pending_count(), 2);
    }

    // ── #180 post-impact stillness: the third phase of the fall signature ──

    #[test]
    fn post_impact_stillness_boosts_fall_confidence() {
        // Same jolt with and without the post-impact stillness phase: stillness
        // (the body coming to rest) must raise the candidate's confidence.
        let cfg = ImpactConfig { enable_fall: true, ..Default::default() };
        let without = ImpactDetector::new(Some(cfg));
        let a = without
            .on_impact_window(5.0, 0.5, 0.0, false, false, true, 0.0, 0.0, 0, -1.0, 0.5)
            .unwrap();
        let with = ImpactDetector::new(Some(ImpactConfig { enable_fall: true, ..Default::default() }));
        let b = with
            .on_impact_window(5.0, 0.5, 0.0, false, true, true, 0.0, 0.0, 0, -1.0, 0.5)
            .unwrap();
        assert!(b.confidence > a.confidence, "post-impact stillness must raise fall confidence (#180)");
    }

    #[test]
    fn post_impact_stillness_rescues_a_sub_confidence_fall() {
        // A jolt whose confidence lands just under the gate on its own...
        let cfg = ImpactConfig { enable_fall: true, min_confidence: 0.6, ..Default::default() };
        let plain = ImpactDetector::new(Some(cfg));
        assert!(
            plain.on_impact_window(2.5, 0.5, 0.0, false, false, true, 0.0, 0.0, 0, -1.0, 0.5).is_none(),
            "bare at-threshold fall below the gate must NOT fire (no regression)"
        );
        // ...is rescued once the post-impact stillness phase corroborates it.
        let still = ImpactDetector::new(Some(ImpactConfig {
            enable_fall: true,
            min_confidence: 0.6,
            ..Default::default()
        }));
        let cand = still.on_impact_window(2.5, 0.5, 0.0, false, true, true, 0.0, 0.0, 0, -1.0, 0.5);
        assert!(cand.is_some(), "post-impact stillness must rescue the fall (#180)");
        assert_eq!(cand.unwrap().kind, "potential_fall");
    }

    // ── #181 impact-instant Δv (post-impact speed) corroboration ──

    #[test]
    fn dv_collapse_boosts_crash_confidence() {
        // 60 km/h pre-impact crash at the g-threshold (confidence 0.6, not
        // saturated); a post-impact reading of ~0 km/h is a sharp collapse that
        // strongly corroborates the crash ⇒ confidence rises.
        let d = ImpactDetector::new(Some(crash_cfg()));
        let speed = 60.0 / 3.6;
        let cand = d
            .on_impact_window(2.0, speed, 0.0, false, false, false, 0.0, 0.0, 1000, -1.0, 0.5)
            .unwrap();
        let before = cand.confidence;
        assert!(d.corroborate_dv(0.0, 2500), "a 60→0 collapse must corroborate (#181)");
        let confirmed = d.check_confirmations(60000);
        assert_eq!(confirmed.len(), 1);
        assert!(confirmed[0].confidence > before, "Δv collapse must raise confidence (#181)");
    }

    #[test]
    fn dv_no_collapse_does_not_change_confidence() {
        // Phone dropped in a still-moving car: pre-impact 60 km/h, post-impact
        // still ~58 km/h ⇒ no collapse ⇒ confidence unchanged (never lowered).
        let d = ImpactDetector::new(Some(crash_cfg()));
        let speed = 60.0 / 3.6;
        let cand = d
            .on_impact_window(2.0, speed, 0.0, false, false, false, 0.0, 0.0, 1000, -1.0, 0.5)
            .unwrap();
        let before = cand.confidence;
        assert!(!d.corroborate_dv(58.0 / 3.6, 2500), "maintained speed must not corroborate");
        let confirmed = d.check_confirmations(60000);
        assert!((confirmed[0].confidence - before).abs() < 1e-9, "confidence must be unchanged");
    }

    #[test]
    fn dv_is_one_shot_and_window_bounded() {
        let d = ImpactDetector::new(Some(crash_cfg()));
        let speed = 60.0 / 3.6;
        d.on_impact_window(4.0, speed, 0.0, false, false, false, 0.0, 0.0, 1000, -1.0, 0.5).unwrap();
        // First post-impact collapse corroborates; a second is ignored (one-shot).
        assert!(d.corroborate_dv(0.0, 2000));
        assert!(!d.corroborate_dv(0.0, 2500));
        // A fresh crash whose Δv sample arrives after the window is not corroborated.
        let d2 = ImpactDetector::new(Some(crash_cfg()));
        d2.on_impact_window(4.0, speed, 0.0, false, false, false, 0.0, 0.0, 1000, -1.0, 0.5).unwrap();
        assert!(
            !d2.corroborate_dv(0.0, 1000 + DV_CORROBORATION_WINDOW_MS + 1),
            "a sample past the Δv window must not corroborate (#181)"
        );
    }
}
