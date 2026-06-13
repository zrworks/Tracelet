//! Accelerometer feature-window computation — the shared keystone.
//!
//! Both platforms already sample the accelerometer at ~10 Hz for motion
//! detection. Rather than push raw 10 Hz samples across the FFI continuously,
//! the native layer forwards ~1 s batches of gravity-subtracted magnitudes
//! (in g) into [`compute_accel_window`], which derives the lightweight features
//! consumed by the transport-mode classifier and the impact detector. Keeping
//! the DSP here makes it the single, testable source of truth for both
//! consumers instead of being re-implemented per platform.

/// Lightweight features summarizing one accelerometer window.
#[derive(uniffi::Record, Clone, Copy, Debug, PartialEq)]
pub struct AccelWindow {
    /// Mean magnitude (g, gravity-subtracted).
    pub mean_g: f64,
    /// Variance of the magnitude — separates steady (vehicle) from bouncy
    /// (running) motion.
    pub variance: f64,
    /// Largest single magnitude in the window (g) — the impact signal.
    pub peak_g: f64,
    /// Dominant oscillation frequency (Hz), estimated from mean-crossings —
    /// the cadence cue distinguishing walking (~2 Hz) from running (~3 Hz).
    pub dominant_cadence_hz: f64,
    /// Number of samples in the window.
    pub sample_count: u32,
    /// Window duration (ms).
    pub duration_ms: i64,
}

impl AccelWindow {
    /// An all-zero window (used when no samples are present).
    pub fn empty(duration_ms: i64) -> Self {
        Self {
            mean_g: 0.0,
            variance: 0.0,
            peak_g: 0.0,
            dominant_cadence_hz: 0.0,
            sample_count: 0,
            duration_ms,
        }
    }
}

/// Computes [`AccelWindow`] features from a batch of gravity-subtracted
/// magnitudes (g) spanning `duration_ms`.
#[uniffi::export]
pub fn compute_accel_window(magnitudes_g: Vec<f64>, duration_ms: i64) -> AccelWindow {
    let n = magnitudes_g.len();
    if n == 0 {
        return AccelWindow::empty(duration_ms);
    }

    let mean = magnitudes_g.iter().sum::<f64>() / n as f64;
    let variance =
        magnitudes_g.iter().map(|v| (v - mean).powi(2)).sum::<f64>() / n as f64;
    let peak = magnitudes_g
        .iter()
        .fold(0.0_f64, |acc, v| acc.max(v.abs()));

    // Cadence via mean-crossings: each full oscillation crosses the mean twice.
    let mut crossings = 0_u32;
    for pair in magnitudes_g.windows(2) {
        let a = pair[0] - mean;
        let b = pair[1] - mean;
        if (a <= 0.0 && b > 0.0) || (a > 0.0 && b <= 0.0) {
            crossings += 1;
        }
    }
    let duration_s = (duration_ms as f64 / 1000.0).max(1e-3);
    let dominant_cadence_hz = (crossings as f64 / 2.0) / duration_s;

    AccelWindow {
        mean_g: mean,
        variance,
        peak_g: peak,
        dominant_cadence_hz,
        sample_count: n as u32,
        duration_ms,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_batch_is_zeroed() {
        let w = compute_accel_window(vec![], 1000);
        assert_eq!(w.sample_count, 0);
        assert_eq!(w.peak_g, 0.0);
        assert_eq!(w.dominant_cadence_hz, 0.0);
    }

    #[test]
    fn peak_is_absolute_max() {
        let w = compute_accel_window(vec![0.1, -0.9, 0.3], 1000);
        assert!((w.peak_g - 0.9).abs() < 1e-9);
    }

    #[test]
    fn steady_signal_has_low_variance_and_no_cadence() {
        let w = compute_accel_window(vec![0.05; 10], 1000);
        assert!(w.variance < 1e-9);
        assert_eq!(w.dominant_cadence_hz, 0.0);
    }

    #[test]
    fn oscillation_yields_expected_cadence() {
        // 20 samples over 1 s oscillating +/- around 0 at 2 full cycles ⇒ ~2 Hz.
        // Build 2 cycles: 4 mean-crossings ⇒ cadence = 4/2 / 1s = 2 Hz.
        let mut s = Vec::new();
        for cycle in 0..2 {
            let _ = cycle;
            s.extend_from_slice(&[1.0, 1.0, -1.0, -1.0, 1.0]); // up/down per cycle
        }
        let w = compute_accel_window(s, 1000);
        assert!(w.dominant_cadence_hz >= 1.0 && w.dominant_cadence_hz <= 3.0);
    }
}
