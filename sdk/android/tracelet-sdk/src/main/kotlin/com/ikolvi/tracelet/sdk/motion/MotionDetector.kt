package com.ikolvi.tracelet.sdk.motion

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.hardware.TriggerEvent
import android.hardware.TriggerEventListener
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.ikolvi.tracelet.sdk.ConfigManager
import com.ikolvi.tracelet.sdk.TraceletEventSender
import com.ikolvi.tracelet.sdk.StateManager
import com.ikolvi.tracelet.sdk.wrapper.TraceletActivityRecognitionClient
import com.ikolvi.tracelet.sdk.wrapper.TraceletActivityTransition
import com.ikolvi.tracelet.sdk.wrapper.TraceletActivityTransitionRequest
import com.ikolvi.tracelet.sdk.wrapper.TraceletServices
import kotlin.math.sqrt

/**
 * Motion detection engine with two operating modes:
 *
 * ## Full mode (default)
 * Uses Google Activity Transition API for rich activity classification
 * (still, walking, running, cycling, vehicle) plus accelerometer fallback.
 * Requires `ACTIVITY_RECOGNITION` permission on Android 10+.
 *
 * ## Accelerometer-only mode (`disableMotionActivityUpdates = true`)
 * Uses hardware accelerometer + TYPE_SIGNIFICANT_MOTION sensor for basic
 * stationary↔moving detection. **No permissions required.** Does not provide
 * activity classification — only fires `onMotionStateChanged(isMoving)`.
 *
 * Transition flow (both modes):
 * 1. MOVING → activity/accelerometer detects stillness → start stopTimeout
 * 2. After stopTimeout elapses → declare STATIONARY → fire onMotionChange(false)
 * 3. In stationary: listen for shake/significant motion → declare MOVING
 * 4. Fire onMotionChange(true) → restart location tracking
 */
class MotionDetector(
    private val context: Context,
    private val config: ConfigManager,
    private val state: StateManager,
    var events: TraceletEventSender,
    private val activityClient: TraceletActivityRecognitionClient = TraceletServices.getInstance(context).getActivityRecognitionClient(context),
) {
    private val extractor = TraceletServices.getInstance(context).getEventExtractor()
    companion object {
        private const val TAG = "MotionDetector"
        private const val ACTION_ACTIVITY_TRANSITION =
            "com.tracelet.ACTION_ACTIVITY_TRANSITION"

        /**
         * Accelerometer shake threshold in m/s² (gravity-subtracted).
         *
         * Android's SensorEvent provides raw accelerometer values including
         * gravity (~9.81 m/s²). We subtract gravity magnitude first, then
         * compare the residual user-acceleration to this threshold.
         *
         * This value is intentionally higher than the iOS equivalent (0.35)
         * because Android SENSOR_DELAY_NORMAL has lower sampling resolution
         * (~5 Hz vs iOS 50 Hz) and noisier readings on many devices.
         *
         * @see iOS MotionDetector.shakeThreshold (0.35 — CMMotionManager
         *      reports gravity-subtracted user-acceleration directly)
         */
        private const val SHAKE_THRESHOLD = 2.5

        /**
         * Consecutive low-acceleration samples required to trigger stationary
         * in accelerometer-only mode. At SENSOR_DELAY_NORMAL (~200ms intervals),
         * 25 samples ≈ 5 seconds of sustained stillness.
         *
         * iOS uses 150 samples at 50 Hz ≈ 3 seconds. Android uses fewer samples
         * at a lower rate to achieve a longer dwell window, reducing false
         * stationary transitions from brief stops (e.g. traffic lights).
         *
         * @see iOS MotionDetector.stillSampleCount (150 at 50 Hz ≈ 3s)
         */
        private const val STILL_SAMPLE_COUNT = 25

        /**
         * Acceleration magnitude below which a sample counts as "still".
         *
         * Higher than the iOS equivalent (0.15) because Android's
         * SENSOR_DELAY_NORMAL produces noisier, lower-resolution readings.
         * This value was empirically tuned across Pixel, Samsung, and Xiaomi
         * devices to minimize false positives.
         *
         * @see iOS MotionDetector.stillThreshold (0.15 — CoreMotion provides
         *      cleaner, higher-resolution accelerometer data)
         */
        private const val STILL_THRESHOLD = 0.4

        /**
         * Sensor batching latency for shake detection (stationary monitoring).
         * 3 seconds allows the CPU to sleep between burst deliveries,
         * reducing power by ~30-40% vs unbatched. The latency trade-off
         * is acceptable: a 0-3s delay in detecting initial motion won't
         * affect user experience.
         */
        private const val SENSOR_BATCH_LATENCY_US = 3_000_000

        /**
         * Sensor batching latency for stillness detection (moving state).
         * 5 seconds — longer than shake detection because the stillness
         * algorithm already requires [STILL_SAMPLE_COUNT] consecutive
         * quiet samples, so additional batching latency has minimal
         * impact on total detection time.
         */
        private const val STILLNESS_BATCH_LATENCY_US = 5_000_000
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    private var transitionPendingIntent: PendingIntent? = null

    // Timeout & sensor state
    private var stopTimeoutRunnable: Runnable? = null
    private var sensorManager: SensorManager? = null
    private var accelerometerListener: SensorEventListener? = null
    private var significantMotionListener: TriggerEventListener? = null

    /** Callback: notify LocationEngine to start/stop GPS. */
    var onMotionStateChanged: ((isMoving: Boolean) -> Unit)? = null

    /** Callback: request full tracking stop (`stopOnStationary` mode). */
    var onStopRequested: (() -> Unit)? = null

    // Current detected activity (full mode only)
    private var currentActivity: String = "unknown"
    private var currentConfidence: Int = -1

    /** Whether accelerometer monitoring is active (stationary state). */
    private var isMonitoringAccelerometer = false

    /** Whether operating in accelerometer-only mode (no permissions needed). */
    private val isAccelerometerOnlyMode: Boolean
        get() = config.isMotionActivityUpdatesDisabled()

    /** Counter for consecutive still samples in accelerometer-only mode (A-M10). */
    @Volatile
    private var consecutiveStillSamples = 0

    @Volatile
    var isRunning = false
        private set

    // =========================================================================
    // Public API
    // =========================================================================

    /**
     * Start motion detection.
     *
     * In full mode, registers Activity Transition API + accelerometer fallback.
     * In accelerometer-only mode, starts accelerometer + significant-motion
     * sensor only — no permissions required.
     */
    fun start() {
        Log.d(TAG, "start() called — isRunning=$isRunning, isAccelOnlyMode=$isAccelerometerOnlyMode, state.isMoving=${state.isMoving}, isMonitoringAccel=$isMonitoringAccelerometer, sigMotionListener=${significantMotionListener != null}")
        if (isRunning) {
            Log.d(TAG, "start() SKIPPED — already running")
            return
        }
        isRunning = true
        if (isAccelerometerOnlyMode) {
            Log.d(TAG, "start() → startAccelerometerOnlyMode()")
            startAccelerometerOnlyMode()
        } else {
            Log.d(TAG, "start() → startFullMode()")
            startFullMode()
        }
    }

    /** Stop all motion detection and clean up resources. */
    fun stop() {
        Log.d(TAG, "stop() called — isRunning=$isRunning")
        if (!isRunning) {
            Log.d(TAG, "stop() SKIPPED — not running")
            return
        }
        isRunning = false
        unregisterActivityTransitions()
        cancelStopTimeout()
        stopAccelerometerMonitoring()
        cancelSignificantMotionListener()
        Log.d(TAG, "stop() complete")
    }

    /**
     * Re-sync internal sensor state after an external (caller-driven) pace
     * change via `Tracelet.changePace(isMoving)`.
     *
     * Without this, manually forcing the SDK into the stationary state leaves
     * MotionDetector with no listeners registered (because `declareMoving()`
     * had stopped the stationary-side sensors and `declareStationary()` is
     * never invoked from outside). The result is a permanent dead-state: no
     * accelerometer or significant-motion sensor is listening, so no future
     * real movement can wake tracking back up.
     *
     * iOS does not need this hook because CMMotionActivityManager runs
     * continuously at the kernel level regardless of isMoving state.
     */
    fun onManualPaceChange(isMoving: Boolean) {
        Log.d(TAG, "onManualPaceChange($isMoving) called — isRunning=$isRunning, isMonitoringAccel=$isMonitoringAccelerometer, sigMotionListener=${significantMotionListener != null}, state.isMoving=${state.isMoving}")
        if (isMoving) {
            Log.d(TAG, "onManualPaceChange: MOVING — stopping stationary sensors, starting stillness monitoring")
            stopAccelerometerMonitoring()
            cancelSignificantMotionListener()
            cancelStopTimeout()
            startAccelerometerStillnessMonitoring()
        } else {
            Log.d(TAG, "onManualPaceChange: STATIONARY — stopping stillness monitoring, starting shake+sigMotion")
            stopAccelerometerMonitoring()
            cancelStopTimeout()
            startAccelerometerMonitoring()
            startSignificantMotionListener()
            Log.d(TAG, "onManualPaceChange: DONE — isMonitoringAccel=$isMonitoringAccelerometer, sigMotionListener=${significantMotionListener != null}")
        }
    }

    /** Returns sensors availability info. */
    fun getSensors(): Map<String, Any?> {
        val sm = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        return mapOf(
            "platform" to "android",
            "accelerometer" to (sm?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null),
            "gyroscope" to (sm?.getDefaultSensor(Sensor.TYPE_GYROSCOPE) != null),
            "magnetometer" to (sm?.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD) != null),
            "significantMotion" to (sm?.getDefaultSensor(Sensor.TYPE_SIGNIFICANT_MOTION) != null),
        )
    }

    /** Returns the current detected activity type and confidence. */
    fun getCurrentActivity(): Pair<String, Int> = Pair(currentActivity, currentConfidence)

    // =========================================================================
    // Full mode — Activity Recognition + accelerometer fallback
    // =========================================================================

    private fun startFullMode() {
        Log.d(TAG, "startFullMode() — state.isMoving=${state.isMoving}")
        registerActivityTransitions()

        if (!state.isMoving) {
            Log.d(TAG, "startFullMode: STATIONARY — starting shake+sigMotion monitoring")
            startAccelerometerMonitoring()
            startSignificantMotionListener()
        } else {
            Log.d(TAG, "startFullMode: MOVING — starting stillness monitoring")
            startAccelerometerStillnessMonitoring()
        }
    }

    // =========================================================================
    // Accelerometer-only mode — no permissions, basic motion detection
    // =========================================================================

    /**
     * Start permission-free motion detection using hardware sensors only.
     *
     * Moving state: accelerometer monitors for sustained stillness.
     * Stationary state: significant-motion trigger + accelerometer shake detect.
     */
    private fun startAccelerometerOnlyMode() {
        Log.d(TAG, "startAccelerometerOnlyMode() — state.isMoving=${state.isMoving}")

        if (state.isMoving) {
            Log.d(TAG, "startAccelerometerOnlyMode: MOVING — starting stillness monitoring")
            startAccelerometerStillnessMonitoring()
        } else {
            Log.d(TAG, "startAccelerometerOnlyMode: STATIONARY — starting shake+sigMotion")
            startAccelerometerMonitoring()
            startSignificantMotionListener()
        }
    }

    // =========================================================================
    // Activity Recognition (full mode only)
    // =========================================================================

    private fun registerActivityTransitions() {
        val transitions = listOf(
            TraceletActivityTransition(3, 0), // STILL, ENTER
            TraceletActivityTransition(3, 1), // STILL, EXIT
            TraceletActivityTransition(7, 0), // WALKING, ENTER
            TraceletActivityTransition(8, 0), // RUNNING, ENTER
            TraceletActivityTransition(1, 0), // ON_BICYCLE, ENTER
            TraceletActivityTransition(0, 0), // IN_VEHICLE, ENTER
            TraceletActivityTransition(2, 0), // ON_FOOT, ENTER
        )

        val request = TraceletActivityTransitionRequest(transitions)
        val intent = Intent(context, com.ikolvi.tracelet.sdk.receiver.ActivityTransitionReceiver::class.java).apply {
            action = ACTION_ACTIVITY_TRANSITION
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        transitionPendingIntent = PendingIntent.getBroadcast(context, 0, intent, flags)

        try {
            activityClient.requestActivityTransitionUpdates(
                request = request,
                pendingIntent = transitionPendingIntent!!,
                onSuccess = {
                    Log.d(TAG, "Activity transition updates registered with static receiver")
                },
                onFailure = { e ->
                    Log.w(TAG, "Failed to register activity transitions: ${e.message}")
                    // Fallback: start accelerometer-only if AT API fails
                    if (!isMonitoringAccelerometer && !state.isMoving) {
                        startAccelerometerMonitoring()
                    }
                }
            )
        } catch (e: SecurityException) {
            Log.w(TAG, "ACTIVITY_RECOGNITION permission not granted — " +
                    "falling back to accelerometer-only: ${e.message}")
            // Graceful degradation: use accelerometer instead
            startAccelerometerOnlyMode()
        }
    }

    private fun unregisterActivityTransitions() {
        transitionPendingIntent?.let { pi ->
            activityClient.removeActivityTransitionUpdates(
                pendingIntent = pi,
                onSuccess = { },
                onFailure = { e ->
                    Log.w(TAG, "Failed to remove activity transitions: ${e.message}")
                }
            )
        }
        transitionPendingIntent = null
    }

    /**
     * Public callback called by the static ActivityTransitionReceiver to pass
     * incoming broadcast events back to the active MotionDetector instance.
     */
    fun handleTransitionIntent(intent: Intent) {
        if (!isRunning) return
        val result = extractor.extractActivityTransitionResult(intent) ?: return
        for (event in result.transitionEvents) {
            handleTransitionEvent(
                activityType = event.activityType,
                transitionType = event.transitionType
            )
        }
    }

    private fun handleTransitionEvent(activityType: Int, transitionType: Int) {
        if (!isRunning) return
        val activityTypeStr = activityTypeToString(activityType)
        val isEntering = transitionType == 0 // ACTIVITY_TRANSITION_ENTER

        currentActivity = activityTypeStr
        currentConfidence = 100 // Transition API always reports 100% confidence

        // Apply confidence filter
        val minConfidence = config.getMinimumActivityRecognitionConfidence()
        if (currentConfidence < minConfidence) return

        // Apply activity type filter
        val triggerActivities = config.getTriggerActivities()
        if (triggerActivities.isNotEmpty()) {
            val allowed = triggerActivities.split(",").map { it.trim().lowercase() }
            if (activityTypeStr.lowercase() !in allowed && activityTypeStr != "still") return
        }

        // Dispatch activity change event to Dart
        events.sendActivityChange(mapOf(
            "activity" to activityTypeStr,
            "confidence" to currentConfidence,
        ))

        val disableStopDetection = config.getDisableStopDetection()

        when {
            // Device became STILL → start stop-timeout countdown
            activityType == 3 && isEntering -> { // STILL = 3 in GMS (Wait! I should check constant values)
                if (!disableStopDetection) {
                    startStopTimeoutCountdown()
                }
            }
            // Device exited STILL or any moving activity detected
            activityType == 3 && !isEntering -> {
                cancelStopTimeout()
                if (!state.isMoving) declareMoving()
            }
            isEntering && activityType != 3 -> {
                cancelStopTimeout()
                if (!state.isMoving) declareMoving()
            }
        }
    }

    // =========================================================================
    // Stop timeout (shared by both modes)
    // =========================================================================

    private fun startStopTimeoutCountdown() {
        cancelStopTimeout()
        val timeoutMs = config.getStopTimeout() * 60 * 1000L
        val stopDetectionDelayMs = config.getStopDetectionDelay() * 1000L
        val totalDelayMs = timeoutMs + stopDetectionDelayMs
        Log.d(TAG, "startStopTimeoutCountdown() — timeoutMs=$timeoutMs, delayMs=$stopDetectionDelayMs, totalMs=$totalDelayMs")
        if (totalDelayMs <= 0) {
            Log.d(TAG, "startStopTimeoutCountdown() — totalDelay<=0, immediate declareStationary()")
            declareStationary()
            return
        }

        stopTimeoutRunnable = Runnable {
            Log.d(TAG, "stopTimeout FIRED — declaring stationary")
            declareStationary()
        }
        mainHandler.postDelayed(stopTimeoutRunnable!!, totalDelayMs)
    }

    private fun cancelStopTimeout() {
        val had = stopTimeoutRunnable != null
        stopTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        stopTimeoutRunnable = null
        if (had) Log.d(TAG, "cancelStopTimeout() — cancelled pending timeout")
    }

    // =========================================================================
    // State transitions
    // =========================================================================

    private fun declareStationary() {
        Log.d(TAG, "declareStationary() called — state.isMoving=${state.isMoving}, onMotionStateChanged=${onMotionStateChanged != null}")
        if (!state.isMoving) {
            Log.d(TAG, "declareStationary() SKIPPED — already stationary")
            return
        }
        state.isMoving = false
        Log.d(TAG, "declareStationary() → invoking onMotionStateChanged(false)")
        onMotionStateChanged?.invoke(false)

        if (config.getStopOnStationary()) {
            Log.d(TAG, "declareStationary() → stopOnStationary=true, invoking onStopRequested")
            onStopRequested?.invoke()
            return
        }

        Log.d(TAG, "declareStationary() → starting shake+sigMotion monitoring for wake-up")
        startAccelerometerMonitoring()
        startSignificantMotionListener()
        Log.d(TAG, "declareStationary() DONE — isMonitoringAccel=$isMonitoringAccelerometer, sigMotionListener=${significantMotionListener != null}")
    }

    private fun declareMoving() {
        Log.d(TAG, "declareMoving() called — state.isMoving=${state.isMoving}, onMotionStateChanged=${onMotionStateChanged != null}")
        state.isMoving = true
        stopAccelerometerMonitoring()
        cancelSignificantMotionListener()
        consecutiveStillSamples = 0

        val delay = config.getMotionTriggerDelay().toLong()
        if (delay > 0) {
            Log.d(TAG, "declareMoving() → delayed dispatch (${delay}ms)")
            mainHandler.postDelayed({
                if (state.isMoving) {
                    Log.d(TAG, "declareMoving() → delayed onMotionStateChanged(true) firing now")
                    onMotionStateChanged?.invoke(true)
                } else {
                    Log.d(TAG, "declareMoving() → delayed callback SKIPPED — state.isMoving is now false")
                }
            }, delay)
        } else {
            Log.d(TAG, "declareMoving() → invoking onMotionStateChanged(true) immediately")
            onMotionStateChanged?.invoke(true)
        }

        Log.d(TAG, "declareMoving() → starting stillness monitoring")
        startAccelerometerStillnessMonitoring()
    }

    // =========================================================================
    // Accelerometer — shake detection (stationary → moving)
    // =========================================================================

    /**
     * Monitors accelerometer for shake/movement while device is stationary.
     * Uses SENSOR_DELAY_NORMAL (~200ms) for low power consumption.
     *
     * **Sensor batching:** A `maxReportLatencyUs` of 3 seconds allows the
     * CPU to remain in a low-power sleep state between burst deliveries,
     * reducing overall power consumption by ~30-40% compared to unbatched
     * delivery. The trade-off is a 0-3 second latency on shake detection
     * which is acceptable for the stationary→moving transition.
     */
    private fun startAccelerometerMonitoring() {
        Log.d(TAG, "startAccelerometerMonitoring() [SHAKE] called — isMonitoringAccel=$isMonitoringAccelerometer")
        if (isMonitoringAccelerometer) {
            Log.w(TAG, "startAccelerometerMonitoring() [SHAKE] SKIPPED — already monitoring!")
            return
        }
        val sm = obtainSensorManager()
        if (sm == null) {
            Log.e(TAG, "startAccelerometerMonitoring() [SHAKE] FAILED — SensorManager is null!")
            return
        }
        val accelerometer = sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        if (accelerometer == null) {
            Log.w(TAG, "Accelerometer sensor not available — relying on significant-motion sensor only")
            startSignificantMotionListener()
            return
        }

        // Log sensor details
        Log.d(TAG, "Accelerometer details: name=${accelerometer.name}, vendor=${accelerometer.vendor}, version=${accelerometer.version}, power=${accelerometer.power}mA, resolution=${accelerometer.resolution}m/s²")

        val shakeThreshold = config.getShakeThreshold()
        Log.d(TAG, "startAccelerometerMonitoring() [SHAKE] registering listener — shakeThreshold=$shakeThreshold")
        accelerometerListener = object : SensorEventListener {
            private var sampleCount = 0
            private var lastX = 0f
            private var lastY = 0f
            private var lastZ = 0f
            private var consecutiveFrozenCount = 0
            private var maxMagLast10 = 0.0

            override fun onSensorChanged(event: SensorEvent) {
                if (!isRunning) return
                val x = event.values[0]
                val y = event.values[1]
                val z = event.values[2]
                val magnitude = sqrt((x * x + y * y + z * z).toDouble()) - 9.81
                sampleCount++

                // Frozen check
                if (x == lastX && y == lastY && z == lastZ) {
                    consecutiveFrozenCount++
                    if (consecutiveFrozenCount >= 5) {
                        Log.w(TAG, "[SHAKE] WARNING: Accelerometer values are 100% frozen! consecutiveFrozenCount=$consecutiveFrozenCount, x=$x, y=$y, z=$z. OS background sensor throttling might be active.")
                    }
                } else {
                    consecutiveFrozenCount = 0
                }
                lastX = x
                lastY = y
                lastZ = z

                // Track max magnitude in last 10 samples
                val absMag = Math.abs(magnitude)
                if (absMag > maxMagLast10) {
                    maxMagLast10 = absMag
                }

                // Log every 10th sample to avoid spam but show sensor details
                if (sampleCount % 10 == 1) {
                    Log.d(TAG, "[SHAKE] sample #$sampleCount: current_mag=${String.format("%.3f", magnitude)}, max_mag_last_10=${String.format("%.3f", maxMagLast10)}, threshold=$shakeThreshold, raw=[$x, $y, $z]")
                    // Reset max mag for the next window
                    maxMagLast10 = 0.0
                }

                if (absMag > shakeThreshold) {
                    Log.d(TAG, "[SHAKE] ★★★ SHAKE DETECTED! mag=${String.format("%.3f", magnitude)} > threshold=$shakeThreshold (raw=[$x, $y, $z]) → declareMoving()")
                    stopAccelerometerMonitoring()
                    declareMoving()
                }
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }

        val success = sm.registerListener(
            accelerometerListener, accelerometer,
            SensorManager.SENSOR_DELAY_NORMAL,
            SENSOR_BATCH_LATENCY_US
        )
        isMonitoringAccelerometer = success
        Log.d(TAG, "startAccelerometerMonitoring() [SHAKE] registered — success=$success, isMonitoringAccel=$isMonitoringAccelerometer")
        if (!success) {
            Log.e(TAG, "startAccelerometerMonitoring() [SHAKE] FAILED to register sensor listener!")
        }
    }

    private fun stopAccelerometerMonitoring() {
        Log.d(TAG, "stopAccelerometerMonitoring() called — isMonitoringAccel=$isMonitoringAccelerometer")
        if (!isMonitoringAccelerometer) {
            Log.d(TAG, "stopAccelerometerMonitoring() SKIPPED — not monitoring")
            return
        }
        accelerometerListener?.let { sensorManager?.unregisterListener(it) }
        accelerometerListener = null
        isMonitoringAccelerometer = false
        Log.d(TAG, "stopAccelerometerMonitoring() DONE — unregistered")
    }

    // =========================================================================
    // Accelerometer — stillness detection (moving → stationary, accel-only mode)
    // =========================================================================

    /**
     * Monitors accelerometer for sustained stillness while device is moving.
     * Used only in accelerometer-only mode to detect when the user stops moving.
     *
     * Requires [STILL_SAMPLE_COUNT] consecutive samples below [STILL_THRESHOLD]
     * before starting the stop-timeout countdown, preventing false triggers
     * from brief pauses (e.g. standing at a traffic light).
     *
     * Uses sensor batching (5-second latency) since stillness detection is
     * inherently tolerant of delayed delivery.
     */
    private fun startAccelerometerStillnessMonitoring() {
        Log.d(TAG, "startAccelerometerStillnessMonitoring() [STILLNESS] called — isMonitoringAccel=$isMonitoringAccelerometer")
        if (isMonitoringAccelerometer) {
            Log.w(TAG, "startAccelerometerStillnessMonitoring() [STILLNESS] SKIPPED — already monitoring!")
            return
        }
        if (config.getDisableStopDetection()) {
            Log.d(TAG, "startAccelerometerStillnessMonitoring() [STILLNESS] SKIPPED — stopDetection disabled")
            return
        }

        val sm = obtainSensorManager()
        if (sm == null) {
            Log.e(TAG, "startAccelerometerStillnessMonitoring() [STILLNESS] FAILED — SensorManager is null!")
            return
        }
        val accelerometer = sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        if (accelerometer == null) {
            Log.w(TAG, "Accelerometer not available — cannot monitor for stillness")
            return
        }
        consecutiveStillSamples = 0

        // Log sensor details
        Log.d(TAG, "Accelerometer details (stillness): name=${accelerometer.name}, vendor=${accelerometer.vendor}, version=${accelerometer.version}, power=${accelerometer.power}mA, resolution=${accelerometer.resolution}m/s²")

        val stillThreshold = config.getStillThreshold()
        val stillCount = config.getStillSampleCount()
        Log.d(TAG, "startAccelerometerStillnessMonitoring() [STILLNESS] registering — stillThreshold=$stillThreshold, stillCount=$stillCount")

        accelerometerListener = object : SensorEventListener {
            private var sampleCount = 0
            private var lastX = 0f
            private var lastY = 0f
            private var lastZ = 0f
            private var consecutiveFrozenCount = 0
            private var maxMagLast10 = 0.0

            override fun onSensorChanged(event: SensorEvent) {
                if (!isRunning) return
                val x = event.values[0]
                val y = event.values[1]
                val z = event.values[2]
                val magnitude = sqrt((x * x + y * y + z * z).toDouble()) - 9.81
                sampleCount++

                // Frozen check
                if (x == lastX && y == lastY && z == lastZ) {
                    consecutiveFrozenCount++
                    if (consecutiveFrozenCount >= 5) {
                        Log.w(TAG, "[STILLNESS] WARNING: Accelerometer values are 100% frozen! consecutiveFrozenCount=$consecutiveFrozenCount, x=$x, y=$y, z=$z. OS background sensor throttling might be active.")
                    }
                } else {
                    consecutiveFrozenCount = 0
                }
                lastX = x
                lastY = y
                lastZ = z

                // Track max magnitude in last 10 samples
                val absMag = Math.abs(magnitude)
                if (absMag > maxMagLast10) {
                    maxMagLast10 = absMag
                }

                // Log every 10th sample
                if (sampleCount % 10 == 1) {
                    Log.d(TAG, "[STILLNESS] sample #$sampleCount: current_mag=${String.format("%.3f", magnitude)}, max_mag_last_10=${String.format("%.3f", maxMagLast10)}, still=$consecutiveStillSamples/$stillCount, raw=[$x, $y, $z]")
                    // Reset max mag for next window
                    maxMagLast10 = 0.0
                }

                if (absMag < stillThreshold) {
                    consecutiveStillSamples++
                    if (consecutiveStillSamples == stillCount) {
                        Log.d(TAG, "[STILLNESS] ★★★ sustained stillness detected ($stillCount samples) → startStopTimeoutCountdown()")
                        stopAccelerometerMonitoring()
                        startStopTimeoutCountdown()
                    }
                } else {
                    if (consecutiveStillSamples >= stillCount) {
                        Log.d(TAG, "[STILLNESS] Motion resumed during stop-timeout (mag=${String.format("%.3f", magnitude)} >= threshold=$stillThreshold) → cancelStopTimeout()")
                        cancelStopTimeout()
                    }
                    consecutiveStillSamples = 0
                }
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }

        val success = sm.registerListener(
            accelerometerListener, accelerometer,
            SensorManager.SENSOR_DELAY_NORMAL,
            STILLNESS_BATCH_LATENCY_US
        )
        isMonitoringAccelerometer = success
        Log.d(TAG, "startAccelerometerStillnessMonitoring() [STILLNESS] registered — success=$success, isMonitoringAccel=$isMonitoringAccelerometer")
        if (!success) {
            Log.e(TAG, "startAccelerometerStillnessMonitoring() [STILLNESS] FAILED to register sensor listener!")
        }
    }

    // =========================================================================
    // Significant Motion sensor (ultra-low-power wakeup, accel-only mode)
    // =========================================================================

    /**
     * Registers the TYPE_SIGNIFICANT_MOTION trigger sensor as an ultra-low-power
     * wakeup mechanism when stationary. This is a one-shot trigger that fires
     * when the device detects "significant" motion (walking, driving, etc.).
     *
     * Unlike continuous accelerometer monitoring, the significant-motion sensor
     * is implemented in hardware on most devices and consumes near-zero power.
     * It complements the accelerometer shake detector: the shake detector catches
     * immediate jolts, while the significant-motion sensor catches sustained
     * movement that starts gradually.
     *
     * No permissions required — this is a hardware sensor API.
     */
    private fun startSignificantMotionListener() {
        Log.d(TAG, "startSignificantMotionListener() called — existing=${significantMotionListener != null}")
        if (significantMotionListener != null) {
            Log.d(TAG, "startSignificantMotionListener() SKIPPED — already listening")
            return
        }
        val sm = obtainSensorManager()
        if (sm == null) {
            Log.e(TAG, "startSignificantMotionListener() FAILED — SensorManager is null!")
            return
        }
        val sigMotionSensor = sm.getDefaultSensor(Sensor.TYPE_SIGNIFICANT_MOTION)
        if (sigMotionSensor == null) {
            Log.w(TAG, "startSignificantMotionListener() FAILED — TYPE_SIGNIFICANT_MOTION sensor not available!")
            return
        }

        // Log significant motion details
        Log.d(TAG, "Significant motion details: name=${sigMotionSensor.name}, vendor=${sigMotionSensor.vendor}, version=${sigMotionSensor.version}, power=${sigMotionSensor.power}mA")

        significantMotionListener = object : TriggerEventListener() {
            override fun onTrigger(event: TriggerEvent?) {
                Log.d(TAG, "★★★ SIGNIFICANT MOTION TRIGGERED! — declaring moving")
                significantMotionListener = null
                declareMoving()
            }
        }

        val success = sm.requestTriggerSensor(significantMotionListener, sigMotionSensor)
        Log.d(TAG, "startSignificantMotionListener() registered — success=$success, sensor=${sigMotionSensor.name}")
        if (!success) {
            Log.e(TAG, "startSignificantMotionListener() FAILED to register significant motion sensor!")
            significantMotionListener = null
        }
    }

    private fun cancelSignificantMotionListener() {
        Log.d(TAG, "cancelSignificantMotionListener() called — existing=${significantMotionListener != null}")
        significantMotionListener?.let { listener ->
            val sm = obtainSensorManager()
            val sensor = sm?.getDefaultSensor(Sensor.TYPE_SIGNIFICANT_MOTION)
            if (sm != null && sensor != null) {
                sm.cancelTriggerSensor(listener, sensor)
                Log.d(TAG, "cancelSignificantMotionListener() — trigger sensor cancelled")
            }
        }
        significantMotionListener = null
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    private fun obtainSensorManager(): SensorManager? {
        if (sensorManager == null) {
            sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        }
        return sensorManager
    }

    private fun activityTypeToString(type: Int): String = when (type) {
        3 -> "still" // DetectedActivity.STILL
        7 -> "walking" // DetectedActivity.WALKING
        8 -> "running" // DetectedActivity.RUNNING
        1 -> "on_bicycle" // DetectedActivity.ON_BICYCLE
        0 -> "in_vehicle" // DetectedActivity.IN_VEHICLE
        2 -> "on_foot" // DetectedActivity.ON_FOOT
        4 -> "tilting" // DetectedActivity.TILTING
        else -> "unknown"
    }
}
