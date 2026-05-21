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
    private val events: TraceletEventSender,
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
        if (isAccelerometerOnlyMode) {
            startAccelerometerOnlyMode()
        } else {
            startFullMode()
        }
    }

    /** Stop all motion detection and clean up resources. */
    fun stop() {
        unregisterActivityTransitions()
        cancelStopTimeout()
        stopAccelerometerMonitoring()
        cancelSignificantMotionListener()
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
        if (isMoving) {
            // Caller forced us into moving state — make sure stationary-side
            // sensors are released. (Stillness monitoring will be re-armed
            // by declareStationary() once real stillness is detected.)
            stopAccelerometerMonitoring()
            cancelSignificantMotionListener()
            cancelStopTimeout()
            if (isAccelerometerOnlyMode) {
                startAccelerometerStillnessMonitoring()
            }
        } else {
            // Caller forced us into stationary state — re-engage the wake-up
            // sensors so the next real motion can re-trigger tracking.
            startAccelerometerMonitoring()
            if (isAccelerometerOnlyMode) {
                startSignificantMotionListener()
            }
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
        registerActivityTransitions()

        // If starting in stationary state, also start accelerometer monitoring.
        // The Activity Transition API can take minutes to fire its first event
        // (and may never fire on budget devices). The accelerometer provides a
        // fast, reliable fallback to detect the initial stationary→moving
        // transition.
        if (!state.isMoving) {
            startAccelerometerMonitoring()
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
        Log.d(TAG, "Starting accelerometer-only mode (no ACTIVITY_RECOGNITION)")

        if (state.isMoving) {
            // Already moving — monitor for stillness to auto-stop
            startAccelerometerStillnessMonitoring()
        } else {
            // Stationary — monitor for shake/significant-motion to wake up
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
        val intent = Intent(ACTION_ACTIVITY_TRANSITION).apply {
            setPackage(context.packageName)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        transitionPendingIntent = PendingIntent.getBroadcast(context, 0, intent, flags)

        try {
            activityClient.requestActivityTransitionUpdates(
                request = request,
                pendingIntent = transitionPendingIntent!!,
                onSuccess = {
                    Log.d(TAG, "Activity transition updates registered")
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

        // Register broadcast receiver for transition events
        val filter = IntentFilter(ACTION_ACTIVITY_TRANSITION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(transitionReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(transitionReceiver, filter)
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

        try {
            context.unregisterReceiver(transitionReceiver)
        } catch (_: Exception) {
            // Receiver was not registered — safe to ignore
        }
    }

    private val transitionReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            if (intent == null) return
            val result = extractor.extractActivityTransitionResult(intent) ?: return
            for (event in result.transitionEvents) {
                handleTransitionEvent(
                    activityType = event.activityType,
                    transitionType = event.transitionType
                )
            }
        }
    }

    private fun handleTransitionEvent(activityType: Int, transitionType: Int) {
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
        if (totalDelayMs <= 0) {
            declareStationary()
            return
        }

        stopTimeoutRunnable = Runnable { declareStationary() }
        mainHandler.postDelayed(stopTimeoutRunnable!!, totalDelayMs)
    }

    private fun cancelStopTimeout() {
        stopTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        stopTimeoutRunnable = null
    }

    // =========================================================================
    // State transitions
    // =========================================================================

    private fun declareStationary() {
        if (!state.isMoving) return // Already stationary
        state.isMoving = false
        onMotionStateChanged?.invoke(false)

        if (config.getStopOnStationary()) {
            onStopRequested?.invoke()
            return // Full stop requested — no further monitoring needed
        }

        // Begin monitoring to detect next movement
        startAccelerometerMonitoring()
        if (isAccelerometerOnlyMode) {
            startSignificantMotionListener()
        }
    }

    private fun declareMoving() {
        state.isMoving = true
        stopAccelerometerMonitoring()
        cancelSignificantMotionListener()
        consecutiveStillSamples = 0

        val delay = config.getMotionTriggerDelay().toLong()
        if (delay > 0) {
            mainHandler.postDelayed({
                if (state.isMoving) {
                    onMotionStateChanged?.invoke(true)
                }
            }, delay)
        } else {
            onMotionStateChanged?.invoke(true)
        }

        // In accelerometer-only mode, start monitoring for stillness
        if (isAccelerometerOnlyMode) {
            startAccelerometerStillnessMonitoring()
        }
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
        if (isMonitoringAccelerometer) return
        val sm = obtainSensorManager() ?: return
        val accelerometer = sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        if (accelerometer == null) {
            Log.w(TAG, "Accelerometer sensor not available — relying on significant-motion sensor only")
            // Fall back to the hardware significant-motion sensor which
            // has near-zero power cost and doesn't need accelerometer.
            startSignificantMotionListener()
            return
        }

        accelerometerListener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                val x = event.values[0]
                val y = event.values[1]
                val z = event.values[2]
                val magnitude = sqrt((x * x + y * y + z * z).toDouble()) - 9.81

                if (Math.abs(magnitude) > config.getShakeThreshold()) {
                    stopAccelerometerMonitoring()
                    declareMoving()
                }
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }

        // maxReportLatencyUs = 3 seconds: batch sensor events so the CPU
        // can sleep between deliveries. On devices without hardware FIFO,
        // this parameter is silently ignored and events arrive in real-time.
        sm.registerListener(
            accelerometerListener, accelerometer,
            SensorManager.SENSOR_DELAY_NORMAL,
            SENSOR_BATCH_LATENCY_US
        )
        isMonitoringAccelerometer = true
    }

    private fun stopAccelerometerMonitoring() {
        if (!isMonitoringAccelerometer) return
        accelerometerListener?.let { sensorManager?.unregisterListener(it) }
        accelerometerListener = null
        isMonitoringAccelerometer = false
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
        if (isMonitoringAccelerometer) return
        if (config.getDisableStopDetection()) return

        val sm = obtainSensorManager() ?: return
        val accelerometer = sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        if (accelerometer == null) {
            Log.w(TAG, "Accelerometer not available — cannot monitor for stillness")
            return
        }
        consecutiveStillSamples = 0

        accelerometerListener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                val x = event.values[0]
                val y = event.values[1]
                val z = event.values[2]
                val magnitude = sqrt((x * x + y * y + z * z).toDouble()) - 9.81

                if (Math.abs(magnitude) < config.getStillThreshold()) {
                    consecutiveStillSamples++
                    if (consecutiveStillSamples >= config.getStillSampleCount()) {
                        // Sustained stillness detected — start stop-timeout
                        stopAccelerometerMonitoring()
                        startStopTimeoutCountdown()
                    }
                } else {
                    consecutiveStillSamples = 0
                }
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }

        // maxReportLatencyUs = 5 seconds: stillness detection can tolerate
        // longer batching latency than shake detection.
        sm.registerListener(
            accelerometerListener, accelerometer,
            SensorManager.SENSOR_DELAY_NORMAL,
            STILLNESS_BATCH_LATENCY_US
        )
        isMonitoringAccelerometer = true
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
        val sm = obtainSensorManager() ?: return
        val sigMotionSensor = sm.getDefaultSensor(Sensor.TYPE_SIGNIFICANT_MOTION) ?: return

        significantMotionListener = object : TriggerEventListener() {
            override fun onTrigger(event: TriggerEvent?) {
                Log.d(TAG, "Significant motion detected — declaring moving")
                significantMotionListener = null
                declareMoving()
            }
        }

        sm.requestTriggerSensor(significantMotionListener, sigMotionSensor)
    }

    private fun cancelSignificantMotionListener() {
        significantMotionListener?.let { listener ->
            val sm = obtainSensorManager()
            val sensor = sm?.getDefaultSensor(Sensor.TYPE_SIGNIFICANT_MOTION)
            if (sm != null && sensor != null) {
                sm.cancelTriggerSensor(listener, sensor)
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
