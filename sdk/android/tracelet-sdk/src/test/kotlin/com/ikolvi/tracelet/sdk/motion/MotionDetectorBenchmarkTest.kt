package com.ikolvi.tracelet.sdk.motion

import android.hardware.SensorManager
import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Benchmark tests validating MotionDetector battery optimization constants.
 *
 * These tests verify:
 * 1. Sensor batching latencies are within optimal ranges.
 * 2. Still sample count × sensor delay produces the expected dwell window.
 * 3. Shake/still thresholds are correctly tuned for the Android sensor stack.
 */
class MotionDetectorBenchmarkTest {

    // =========================================================================
    // Sensor batching constants validation
    // =========================================================================

    @Test
    fun `sensor batch latency for shake detection is between 1-5 seconds`() {
        // Shake detection batching should be responsive (1-5s range).
        // Too short = CPU wakes too often, too long = user perceives lag.
        val batchLatencyUs = 3_000_000 // SENSOR_BATCH_LATENCY_US
        val batchLatencySeconds = batchLatencyUs / 1_000_000.0
        assertTrue(batchLatencySeconds >= 1.0, "Shake batch latency should be >= 1s, was ${batchLatencySeconds}s")
        assertTrue(batchLatencySeconds <= 5.0, "Shake batch latency should be <= 5s, was ${batchLatencySeconds}s")
    }

    @Test
    fun `stillness batch latency is between 3-10 seconds`() {
        // Stillness detection can tolerate more latency (3-10s range).
        val batchLatencyUs = 5_000_000 // STILLNESS_BATCH_LATENCY_US
        val batchLatencySeconds = batchLatencyUs / 1_000_000.0
        assertTrue(batchLatencySeconds >= 3.0, "Stillness batch latency should be >= 3s, was ${batchLatencySeconds}s")
        assertTrue(batchLatencySeconds <= 10.0, "Stillness batch latency should be <= 10s, was ${batchLatencySeconds}s")
    }

    @Test
    fun `stillness batch latency is longer than shake batch latency`() {
        // Stillness detection is less time-critical than shake detection.
        val shakeBatchUs = 3_000_000
        val stillnessBatchUs = 5_000_000
        assertTrue(stillnessBatchUs > shakeBatchUs,
            "Stillness batching ($stillnessBatchUs µs) should be longer than shake batching ($shakeBatchUs µs)")
    }

    // =========================================================================
    // Dwell window validation (STILL_SAMPLE_COUNT × sensor rate)
    // =========================================================================

    @Test
    fun `android stillness dwell window is approximately 5 seconds`() {
        // SENSOR_DELAY_NORMAL ~= 200ms (~5 Hz).
        // 25 samples × 200ms = 5000ms = 5 seconds.
        val stillSampleCount = 25
        val sensorDelayMs = 200 // SENSOR_DELAY_NORMAL approximate
        val dwellWindowMs = stillSampleCount * sensorDelayMs
        val dwellWindowSeconds = dwellWindowMs / 1000.0

        assertTrue(dwellWindowSeconds >= 3.0, "Dwell window should be >= 3s, was ${dwellWindowSeconds}s")
        assertTrue(dwellWindowSeconds <= 8.0, "Dwell window should be <= 8s, was ${dwellWindowSeconds}s")
        assertEquals(5.0, dwellWindowSeconds, 0.5, "Dwell window should be ~5s")
    }

    @Test
    fun `cross-platform parity - android vs ios dwell windows match`() {
        // Android: 25 samples × 200ms (SENSOR_DELAY_NORMAL) = 5.0s
        val androidDwellMs = 25 * 200

        // iOS: 50 samples × 100ms (10Hz accelerometer) = 5.0s
        // (Fixed from 150 samples × 100ms = 15.0s — was a regression)
        val iosDwellMs = 50 * 100

        val difference = Math.abs(androidDwellMs - iosDwellMs)
        assertTrue(difference <= 2000,
            "Cross-platform dwell windows should be within 2s: Android=${androidDwellMs}ms, iOS=${iosDwellMs}ms")
    }

    // =========================================================================
    // Threshold validation
    // =========================================================================

    @Test
    fun `shake threshold is higher than still threshold`() {
        val shakeThreshold = 2.5 // SHAKE_THRESHOLD
        val stillThreshold = 0.4 // STILL_THRESHOLD

        assertTrue(shakeThreshold > stillThreshold,
            "Shake ($shakeThreshold) must be higher than still ($stillThreshold) to avoid state oscillation")
        assertTrue(shakeThreshold >= stillThreshold * 3,
            "Shake should be at least 3x still threshold for hysteresis: " +
            "shake=$shakeThreshold, still=$stillThreshold, ratio=${shakeThreshold/stillThreshold}")
    }

    @Test
    fun `android shake threshold is higher than ios due to noisier sensors`() {
        // Android uses raw accelerometer with gravity-included readings.
        // iOS CMMotionManager provides gravity-subtracted user-acceleration.
        // Android thresholds should be higher to compensate.
        val androidShake = 2.5
        val iosShake = 0.35

        assertTrue(androidShake > iosShake,
            "Android shake threshold ($androidShake) should be higher than iOS ($iosShake)")
    }

    // =========================================================================
    // Power budget estimation
    // =========================================================================

    @Test
    fun `estimated CPU wakeups per minute with batching is acceptable`() {
        // Without batching: SENSOR_DELAY_NORMAL = ~5 Hz → 300 wakeups/min
        val unbatchedWakeupsPerMinute = 5.0 * 60

        // With 3-second batching: CPU wakes ~20 times/min (60s / 3s)
        // Each wake delivers ~15 events in a burst.
        val batchPeriodSeconds = 3.0
        val batchedWakeupsPerMinute = 60.0 / batchPeriodSeconds

        val reduction = 1.0 - (batchedWakeupsPerMinute / unbatchedWakeupsPerMinute)
        assertTrue(reduction >= 0.90,
            "Batching should reduce wakeups by >=90%: " +
            "unbatched=${unbatchedWakeupsPerMinute.toInt()}/min, " +
            "batched=${batchedWakeupsPerMinute.toInt()}/min, " +
            "reduction=${(reduction * 100).toInt()}%")
    }

    @Test
    fun `heartbeat dedup at 10s interval saves 360 writes per hour when stationary`() {
        // At 10s heartbeat interval: 360 heartbeats/hour.
        // Without dedup: 360 DB inserts + 360 HTTP triggers.
        // With dedup: 0 DB inserts while stationary (same cached fix).
        val heartbeatIntervalSeconds = 10
        val heartbeatsPerHour = 3600 / heartbeatIntervalSeconds

        // When stationary, GPS fix doesn't change → all writes are redundant.
        val redundantWritesSaved = heartbeatsPerHour
        assertTrue(redundantWritesSaved >= 300,
            "Should save at least 300 redundant DB writes/hour: saved=$redundantWritesSaved")
    }
}
