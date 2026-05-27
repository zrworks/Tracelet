package com.ikolvi.tracelet.sdk.service

import android.Manifest
import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import com.ikolvi.tracelet.sdk.ConfigManager
import com.ikolvi.tracelet.sdk.HeadersRefreshable
import com.ikolvi.tracelet.sdk.ListenerEventSender
import com.ikolvi.tracelet.sdk.TraceletBootstrap
import com.ikolvi.tracelet.sdk.TraceletEventSender
import com.ikolvi.tracelet.sdk.StateManager
import com.ikolvi.tracelet.sdk.geofence.GeofenceManager
import com.ikolvi.tracelet.sdk.location.LocationEngine
import com.ikolvi.tracelet.sdk.location.PeriodicLocationWorker
import com.ikolvi.tracelet.sdk.receiver.GeofenceBroadcastReceiver
import com.ikolvi.tracelet.sdk.model.TrackingMode
import com.ikolvi.tracelet.sdk.util.OemCompat

/**
 * Foreground service for persistent background location tracking.
 *
 * Android requires a foreground service with FOREGROUND_SERVICE_TYPE_LOCATION
 * for reliable background location access (especially Android 14+).
 *
 * This service displays a persistent notification and keeps the location
 * engine alive when the app UI is removed from recents.
 *
 * After a device reboot (started via [BootReceiver]), the service bootstraps
 * a native [LocationEngine] to immediately resume tracking without waiting
 * for a Dart FlutterEngine. Locations are persisted to SQLite and also
 * forwarded to the headless dispatcher if a headless callback is registered.
 */
class LocationService : Service(), DefaultLifecycleObserver {

    companion object {
        private const val TAG = "LocationService"
        private const val NOTIFICATION_ID = 7701
        const val ACTION_START = "com.tracelet.ACTION_START"
        const val ACTION_STOP = "com.tracelet.ACTION_STOP"
        const val ACTION_UPDATE_NOTIFICATION = "com.tracelet.ACTION_UPDATE_NOTIFICATION"
        const val ACTION_BUTTON = "com.tracelet.ACTION_BUTTON"
        const val EXTRA_BUTTON_ACTION = "button_action"
        const val EXTRA_BOOT_START = "boot_start"

        @Volatile
        private var isRunning = false

        // Boot-mode native tracking state — accessible by the plugin.
        @Volatile
        var bootLocationEngine: LocationEngine? = null
            private set



        @Volatile
        var bootSpeedMotionManager: com.ikolvi.tracelet.sdk.motion.SpeedMotionManager? = null
            private set

        @Volatile
        var bootMotionDetector: com.ikolvi.tracelet.sdk.motion.MotionDetector? = null
            private set

        @Volatile
        var bootSmartMotionCoordinator: com.ikolvi.tracelet.sdk.motion.SmartMotionCoordinator? = null
            private set

        // Boot-mode heartbeat timer state.
        @Volatile
        private var bootHeartbeatHandler: Handler? = null
        @Volatile
        private var bootHeartbeatRunnable: Runnable? = null

        @Volatile
        var stationaryTimerHandler: Handler? = null
            private set
        @Volatile
        var stationaryTimerRunnable: Runnable? = null
            private set

        /**
         * Switches the location engine to stationary periodic mode.
         * Sets up a timer to fire a location fix every N minutes.
         */
        fun switchToStationaryPeriodic(
            engine: com.ikolvi.tracelet.sdk.location.LocationEngine,
            config: ConfigManager,
            state: StateManager
        ) {
            stopStationaryTimer()
            engine.stop()
            state.trackingMode = TrackingMode.PERIODIC

            val intervalMs = config.getStationaryPeriodicInterval() * 1000L
            val accuracy = config.getStationaryPeriodicAccuracy()

            val handler = Handler(Looper.getMainLooper())
            stationaryTimerHandler = handler

            val lastLoc = engine.getLastLocation()
            var lastLat = lastLoc?.latitude ?: Double.NaN
            var lastLng = lastLoc?.longitude ?: Double.NaN
            var lastTime = lastLoc?.time ?: 0L

            val runnable = object : Runnable {
                override fun run() {
                    engine.getCurrentPosition(mapOf("desiredAccuracy" to accuracy)) { locationMap -> 
                        if (locationMap != null) {
                            val coords = locationMap["coords"] as? Map<*, *>
                            var speed = (coords?.get("speed") as? Number)?.toDouble() ?: 0.0
                            val lat = (coords?.get("latitude") as? Number)?.toDouble()
                            val lng = (coords?.get("longitude") as? Number)?.toDouble()
                            
                            val now = System.currentTimeMillis()
                            
                            // If platform speed is 0 or missing, calculate from distance
                            if (speed <= 0.0 && lat != null && lng != null && !lastLat.isNaN() && !lastLng.isNaN()) {
                                val results = FloatArray(1)
                                android.location.Location.distanceBetween(lastLat, lastLng, lat, lng, results)
                                val distance = results[0].toDouble()
                                val timeDelta = (now - lastTime) / 1000.0
                                if (timeDelta > 0) {
                                    speed = distance / timeDelta
                                }
                                
                                val stationaryRadius = config.getStationaryRadius()
                                val movingThreshold = config.getSpeedMovingThreshold()
                                if (distance >= stationaryRadius && speed < movingThreshold) {
                                    speed = movingThreshold + 0.1
                                }
                            }
                            
                            if (lat != null && lng != null) {
                                lastLat = lat
                                lastLng = lng
                                lastTime = now
                                
                                // Update odometer if accuracy is acceptable
                                val accuracy = (coords?.get("accuracy") as? Number)?.toDouble() ?: 0.0
                                val lastPeriodicLat = state.lastPeriodicLatitude
                                val lastPeriodicLng = state.lastPeriodicLongitude
                                if (!lastPeriodicLat.isNaN() && !lastPeriodicLng.isNaN()) {
                                    val results = FloatArray(1)
                                    android.location.Location.distanceBetween(lastPeriodicLat, lastPeriodicLng, lat, lng, results)
                                    val dist = results[0].toDouble()
                                    val threshold = config.getOdometerAccuracyThreshold()
                                    if (threshold <= 0 || accuracy <= threshold) {
                                        state.addOdometer(dist)
                                    }
                                }
                                state.lastPeriodicLatitude = lat
                                state.lastPeriodicLongitude = lng
                            }
                            
                            // Send location to the UI so it updates during STATIONARY mode
                            val enriched = locationMap.toMutableMap()
                            enriched["event"] = "periodic"
                            enriched["odometer"] = state.odometer
                            engine.events?.sendLocation(enriched)
                            
                            engine.speedMotionSpeedSink?.invoke(speed)
                        }
                    }
                    handler.postDelayed(this, intervalMs)
                }
            }
            stationaryTimerRunnable = runnable

            // Fire first fix after one interval.
            handler.postDelayed(runnable, intervalMs)
            Log.d(TAG, "switchToStationaryPeriodic() — interval=${intervalMs}ms, accuracy=$accuracy")
        }

        /**
         * Switches to stationary geofences mode.
         */
        fun switchToStationaryGeofences(engine: com.ikolvi.tracelet.sdk.location.LocationEngine, state: StateManager) {
            stopStationaryTimer()
            engine.stop()
            state.trackingMode = TrackingMode.GEOFENCES
            Log.d(TAG, "switchToStationaryGeofences() — continuous stopped, geofences active")
        }

        /**
         * Switches back to continuous tracking.
         */
        fun switchToContinuous(engine: com.ikolvi.tracelet.sdk.location.LocationEngine, state: StateManager) {
            stopStationaryTimer()
            state.trackingMode = TrackingMode.CONTINUOUS
            engine.start()
            Log.d(TAG, "switchToContinuous() — continuous tracking resumed")
        }

        /** Cancels the stationary periodic timer if active. */
        fun stopStationaryTimer() {
            stationaryTimerRunnable?.let { stationaryTimerHandler?.removeCallbacks(it) }
            stationaryTimerRunnable = null
            stationaryTimerHandler = null
        }

        fun isServiceRunning(): Boolean = isRunning

        fun start(context: Context) {
            val intent = Intent(context, LocationService::class.java).apply {
                action = ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /** Start from BootReceiver with the boot flag for native tracking. */
        fun startFromBoot(context: Context) {
            val intent = Intent(context, LocationService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_BOOT_START, true)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, LocationService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }

        fun updateNotification(context: Context) {
            val intent = Intent(context, LocationService::class.java).apply {
                action = ACTION_UPDATE_NOTIFICATION
            }
            context.startService(intent)
        }

        /**
         * Stops and releases the boot-mode LocationEngine.
         *
         * Called by [TraceletAndroidPlugin] when it attaches and takes over
         * tracking with its own engine + EventChannels.
         */
        fun stopBootTracking() {
            stopBootHeartbeat()
            bootLocationEngine?.destroy()
            bootLocationEngine = null
            Log.d(TAG, "Boot-mode native tracking stopped — ready() taking over")
        }

        private fun stopBootHeartbeat() {
            bootHeartbeatRunnable?.let { bootHeartbeatHandler?.removeCallbacks(it) }
            bootHeartbeatRunnable = null
            bootHeartbeatHandler = null
        }
    }

    // Populated from ConfigManager at start time
    private lateinit var configManager: ConfigManager

    private var isForegroundService = false
    private var lastInForeground: Boolean? = null
    private var wakeLock: PowerManager.WakeLock? = null

    // Callback for notification action button taps dispatched to TraceletEventSender
    var onNotificationAction: ((String) -> Unit)? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super<Service>.onCreate()
        configManager = ConfigManager.getInstance(applicationContext)

        // Layer 1: Process-level lifecycle monitoring.
        // We register as an observer to automatically manage notification
        // visibility when the app moves between foreground and background.
        ProcessLifecycleOwner.get().lifecycle.addObserver(this)
    }

    override fun onStart(owner: LifecycleOwner) {
        Log.d(TAG, "App moved to FOREGROUND — checking notification visibility")
        updateNotificationVisibility()
        try {
            val sdk = com.ikolvi.tracelet.sdk.TraceletSdk.getInstance(applicationContext)
            if (sdk.isReady) {
                Log.d(TAG, "App moved to FOREGROUND — requesting state flush to Dart")
                sdk.requestStateFlush()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error flushing state on foreground transition: ${e.message}")
        }
    }

    override fun onStop(owner: LifecycleOwner) {
        Log.d(TAG, "App moved to BACKGROUND — checking notification visibility")
        updateNotificationVisibility()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand: action=${intent?.action}")
        
        // Initial setup for the very first start command
        if (lastInForeground == null) {
            lastInForeground = isAppInForeground()
        }

        // Requirement #3 & #4: Ensure the foreground contract is satisfied immediately.
        // We set isRunning true immediately so updateNotificationVisibility() works on the first call.
        if (intent?.action == ACTION_START || intent?.action == null) {
            isRunning = true
        }

        if (!isForegroundService) {
            Log.d(TAG, "Satisfying foreground contract...")
            startForegroundWithNotification()
            isForegroundService = true
        }

        updateNotificationVisibility()

        when (intent?.action) {
            ACTION_START -> {
                acquireOemWakelock()
                // If started after a device reboot, bootstrap native tracking
                val isBootStart = intent.getBooleanExtra(EXTRA_BOOT_START, false)
                if (isBootStart) {
                    startBootTracking()
                }
            }
            ACTION_STOP -> {
                Log.d(TAG, "Stopping service via ACTION_STOP")
                stopBootTrackingInternal()
                releaseOemWakelock()
                stopForeground(STOP_FOREGROUND_REMOVE)
                isForegroundService = false
                stopSelf()
                isRunning = false
            }
            ACTION_UPDATE_NOTIFICATION -> {
                // Visibility is managed by updateNotificationVisibility()
            }
            ACTION_BUTTON -> {
                val action = intent.getStringExtra(EXTRA_BUTTON_ACTION)
                if (action != null) {
                    onNotificationAction?.invoke(action)
                }
            }
            null -> {
                // Sticky restart after system kill
                acquireOemWakelock()
            }
        }

        // Final sync of visibility state
        updateNotificationVisibility()

        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        // If stopOnTerminate is false, keep tracking alive.
        // The plugin's LocationEngine is about to be destroyed when the
        // FlutterEngine is torn down, so we bootstrap native tracking.
        if (!configManager.getStopOnTerminate()) {

            // Guard: verify background location permission before attempting
            // to continue tracking in a killed/background context.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val hasBackground = ContextCompat.checkSelfPermission(
                    applicationContext, Manifest.permission.ACCESS_BACKGROUND_LOCATION
                ) == PackageManager.PERMISSION_GRANTED
                if (!hasBackground) {
                    Log.w(TAG, "ACCESS_BACKGROUND_LOCATION not granted — stopping tracking on task removal")
                    stopBootTrackingInternal()
                    releaseOemWakelock()
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    stopSelf()
                    isRunning = false
                    return
                }
                Log.d(TAG, "ACCESS_BACKGROUND_LOCATION granted — continuing tracking after task removal")
            }

            val state = StateManager(applicationContext)

            // For periodic mode without foreground service, we don't need
            // the foreground service at all — WorkManager/AlarmManager handles
            // the scheduling independently. Stop the service to avoid showing
            // an unnecessary persistent notification.
            if (state.trackingMode == TrackingMode.PERIODIC && !configManager.getPeriodicUseForegroundService()) {
                // Ensure WorkManager/AlarmManager is scheduled (may already be)
                PeriodicLocationWorker.eventSender = null // No UI

                // HTTP sync is handled natively by Rust Core now

                if (configManager.getPeriodicUseExactAlarms()) {
                    PeriodicLocationWorker.scheduleOneTime(applicationContext)
                    PeriodicLocationWorker.scheduleExactAlarm(
                        applicationContext,
                        configManager.getPeriodicLocationInterval(),
                    )
                } else {
                    PeriodicLocationWorker.schedule(
                        applicationContext,
                        configManager.getPeriodicLocationInterval(),
                    )
                }
                Log.d(TAG, "Task removed — periodic mode continues via WorkManager/AlarmManager")
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                isRunning = false
                return
            }

            startBootTracking()
            return // Service survives task removal with native tracking
        }
        stopBootTrackingInternal()
        releaseOemWakelock()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        isRunning = false
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy")
        stopBootTrackingInternal()
        releaseOemWakelock()
        isRunning = false
        super<Service>.onDestroy()
    }

    // =========================================================================
    // OEM wakelock management
    // =========================================================================

    /**
     * Acquires an OEM-safe partial wakelock.
     *
     * On Huawei EMUI 9+, uses the "LocationManagerService" tag to bypass
     * PowerGenie process killing. On other devices, uses a standard tag.
     * The wakelock is held for the lifetime of the service to prevent
     * aggressive OEM power managers from suspending our process.
     */
    private fun acquireOemWakelock() {
        if (wakeLock?.isHeld == true) return
        wakeLock = OemCompat.acquireOemSafeWakelock(applicationContext)
    }

    private fun releaseOemWakelock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
                Log.d(TAG, "Released OEM wakelock")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing wakelock: ${e.message}")
        }
        wakeLock = null
    }

    // =========================================================================
    // Boot-mode native tracking
    // =========================================================================

    /**
     * Bootstraps a native [LocationEngine] for post-boot / task-removal tracking.
     *
     * Creates minimal versions of the required managers and restarts
     * the correct tracking mode based on persisted [StateManager.trackingMode]:
     * - Mode 0 (continuous): starts LocationEngine.start()
     * - Mode 1 (geofences): starts LocationEngine.start() for proximity monitoring
     *   (geofences are re-registered by Google Play Services automatically)
     * - Mode 2 (periodic): restarts the configured periodic strategy
     *   (foreground-service timer, exact alarms, or WorkManager)
     *
     * Locations are persisted to SQLite. Events are routed to the headless
     * dispatcher via [TraceletBootstrap] if a headless callback was
     * previously registered.
     */
    private fun startBootTracking() {
        if (bootLocationEngine != null) return // Already tracking

        val ctx = applicationContext

        // Guard: require background location permission for boot/task-removal tracking.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val hasBackground = ContextCompat.checkSelfPermission(
                ctx, Manifest.permission.ACCESS_BACKGROUND_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
            if (!hasBackground) {
                Log.w(TAG, "ACCESS_BACKGROUND_LOCATION not granted \u2014 cannot bootstrap boot tracking")
                return
            }
            Log.d(TAG, "ACCESS_BACKGROUND_LOCATION granted \u2014 bootstrapping native tracking")
        }

        val config = ConfigManager.getInstance(ctx)
        val state = StateManager(ctx)

        val eventSender = TraceletBootstrap.eventSenderFactory?.invoke(ctx)
            ?: run {
                // Fallback: use a no-op ListenerEventSender so native tracking
                // and HTTP sync still work even when the Flutter engine hasn't
                // set the factory (e.g., cold boot before plugin initialization).
                Log.w(TAG, "No event sender factory — falling back to ListenerEventSender for boot tracking")
                ListenerEventSender()
            }

        // Headless dispatcher — used for 401 authorization refresh in boot mode.
        // Note: headless event routing is handled by the EventDispatcher's
        // headlessFallback, which is wired by the host framework's
        // eventSenderFactory (e.g. TraceletAndroidPlugin).
        val headless = TraceletBootstrap.headlessDispatcherFactory?.invoke(ctx)

        // HTTP sync is handled natively by Rust Core now

        val trackingMode = state.trackingMode
        Log.d(TAG, "Bootstrapping native tracking after boot/task-removal (trackingMode=$trackingMode)")

        when (trackingMode) {
            TrackingMode.PERIODIC -> {
                // Periodic mode — restart the correct scheduling strategy.
                // Wire the shared event sender so WorkManager workers can dispatch.
                PeriodicLocationWorker.eventSender = eventSender

                if (config.getPeriodicUseForegroundService()) {
                    // Foreground service + timer strategy — needs a LocationEngine
                    val engine = LocationEngine(ctx, config, state, eventSender)
                    engine.startPeriodic()
                    bootLocationEngine = engine
                    Log.d(TAG, "Periodic mode restored with foreground-service timer")
                } else if (config.getPeriodicUseExactAlarms()) {
                    // Exact alarms + OneTimeWorkRequest — no LocationEngine needed
                    PeriodicLocationWorker.scheduleOneTime(ctx)
                    PeriodicLocationWorker.scheduleExactAlarm(
                        ctx,
                        config.getPeriodicLocationInterval(),
                    )
                    Log.d(TAG, "Periodic mode restored with exact alarms")
                } else {
                    // WorkManager — already survives app kill natively,
                    // but explicitly re-schedule to ensure consistency after boot
                    PeriodicLocationWorker.schedule(
                        ctx,
                        config.getPeriodicLocationInterval(),
                    )
                    Log.d(TAG, "Periodic mode restored with WorkManager")
                }

                // Start heartbeat for periodic mode if configured
                if (bootLocationEngine != null) {
                    startBootHeartbeat(config, bootLocationEngine!!, eventSender)
                }
            }
            else -> {
                // Continuous (0) or geofences (1) — start full LocationEngine
                val engine = LocationEngine(ctx, config, state, eventSender)
                engine.start()
                bootLocationEngine = engine
                Log.d(TAG, "Boot-mode native tracking started (trackingMode=$trackingMode)")
                startBootHeartbeat(config, engine, eventSender)

                // Speed, Accelerometer, or Smart motion detection setup
                val motionMode = config.getMotionDetectionMode()
                if (motionMode == com.ikolvi.tracelet.sdk.model.MotionDetectionMode.SPEED) {
                    val smm = com.ikolvi.tracelet.sdk.motion.SpeedMotionManager(
                        config, state, eventSender,
                        object : com.ikolvi.tracelet.sdk.motion.SpeedMotionManager.SpeedMotionCallback {
                            override fun switchToContinuous() {
                                LocationService.switchToContinuous(engine, state)
                            }
                            override fun switchToStationaryPeriodic() {
                                LocationService.switchToStationaryPeriodic(engine, config, state)
                            }
                            override fun switchToStationaryGeofences() {
                                LocationService.switchToStationaryGeofences(engine, state)
                            }
                        },
                    )
                    smm.start()
                    bootSpeedMotionManager = smm
                    engine.speedMotionSpeedSink = { speed -> smm.onLocation(speed) }
                    Log.d(TAG, "Speed-based motion detection started (boot mode)")

                    // If persisted state was STATIONARY, immediately switch to
                    // the appropriate stationary tracking mode.
                    if (state.speedMotionState == com.ikolvi.tracelet.sdk.model.SpeedMotionState.STATIONARY) {
                        when (config.getStationaryTrackingMode()) {
                            com.ikolvi.tracelet.sdk.model.StationaryTrackingMode.GEOFENCES -> LocationService.switchToStationaryGeofences(engine, state)
                            else -> LocationService.switchToStationaryPeriodic(engine, config, state)
                        }
                        Log.d(TAG, "Restored stationary mode from persisted speed state")
                    }
                } else if (motionMode == com.ikolvi.tracelet.sdk.model.MotionDetectionMode.SMART) {
                    val detector = com.ikolvi.tracelet.sdk.motion.MotionDetector(
                        ctx, config, state, eventSender
                    )
                    bootMotionDetector = detector

                    val smm = com.ikolvi.tracelet.sdk.motion.SpeedMotionManager(
                        config, state, eventSender,
                        object : com.ikolvi.tracelet.sdk.motion.SpeedMotionManager.SpeedMotionCallback {
                            override fun switchToContinuous() {
                                bootSmartMotionCoordinator?.onSpeedStateChange(true)
                            }
                            override fun switchToStationaryPeriodic() {
                                bootSmartMotionCoordinator?.onSpeedStateChange(false)
                            }
                            override fun switchToStationaryGeofences() {
                                bootSmartMotionCoordinator?.onSpeedStateChange(false)
                            }
                        }
                    )
                    smm.start()
                    bootSpeedMotionManager = smm
                    engine.speedMotionSpeedSink = { speed -> smm.onLocation(speed) }

                    val coordinator = com.ikolvi.tracelet.sdk.motion.SmartMotionCoordinator(
                        ctx, config, state, eventSender, engine, detector
                    )
                    bootSmartMotionCoordinator = coordinator
                    coordinator.syncCurrentMode()

                    detector.onMotionStateChanged = { isMoving ->
                        bootSpeedMotionManager?.onManualPaceChange(isMoving)
                        coordinator.onAccelStateChange(isMoving)
                    }
                    detector.onStopRequested = {}

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val hasMotion = ContextCompat.checkSelfPermission(
                            ctx, Manifest.permission.ACTIVITY_RECOGNITION
                        ) == PackageManager.PERMISSION_GRANTED
                        if (hasMotion) {
                            detector.start()
                        } else {
                            Log.w(TAG, "ACTIVITY_RECOGNITION not granted in boot mode")
                        }
                    } else {
                        detector.start()
                    }
                    Log.d(TAG, "Smart-based motion detection started (boot mode)")
                } else {
                    // Accelerometer / Activity Recognition only
                    val detector = com.ikolvi.tracelet.sdk.motion.MotionDetector(
                        ctx, config, state, eventSender
                    )
                    bootMotionDetector = detector
                    detector.onMotionStateChanged = { isMoving ->
                        if (isMoving) {
                            LocationService.switchToContinuous(engine, state)
                        } else {
                            when (config.getStationaryTrackingMode()) {
                                com.ikolvi.tracelet.sdk.model.StationaryTrackingMode.GEOFENCES -> LocationService.switchToStationaryGeofences(engine, state)
                                else -> LocationService.switchToStationaryPeriodic(engine, config, state)
                            }
                        }
                    }
                    detector.onStopRequested = {}

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val hasMotion = ContextCompat.checkSelfPermission(
                            ctx, Manifest.permission.ACTIVITY_RECOGNITION
                        ) == PackageManager.PERMISSION_GRANTED
                        if (hasMotion) {
                            detector.start()
                        } else {
                            Log.w(TAG, "ACTIVITY_RECOGNITION not granted in boot mode")
                        }
                    } else {
                        detector.start()
                    }
                    Log.d(TAG, "Accelerometer-based motion detection started (boot mode)")
                }

                // Geofence mode: re-register persisted geofences with Play Services
                // and restore the static BroadcastReceiver reference so transition
                // events are not silently dropped after process death.
                if (trackingMode == TrackingMode.GEOFENCES) {
                    val geoManager = GeofenceManager(ctx, config, eventSender)
                    geoManager.reRegisterAll()
                    GeofenceBroadcastReceiver.geofenceManager = geoManager
                    Log.d(TAG, "Geofence registrations restored after boot/task-removal")
                }
            }
        }
    }

    /**
     * Starts a self-rescheduling heartbeat timer for boot-mode tracking.
     *
     * Mirrors the heartbeat logic in [TraceletAndroidPlugin.startHeartbeat]
     * but uses the boot-mode [LocationEngine] and [TraceletEventSender].
     */
    private fun startBootHeartbeat(
        config: ConfigManager,
        engine: LocationEngine,
        dispatcher: TraceletEventSender
    ) {
        stopBootHeartbeat()
        val intervalSeconds = config.getHeartbeatInterval()
        if (intervalSeconds <= 0) return

        val handler = Handler(Looper.getMainLooper())
        bootHeartbeatHandler = handler

        val runnable = object : Runnable {
            override fun run() {
                if (bootLocationEngine == null) return // Tracking stopped
                Log.d(TAG, "Boot heartbeat fired")
                val cached = engine.getLastGpsLocation()
                if (cached != null) {
                    val locationData = engine.enrichLocation(cached, "heartbeat").toMutableMap()
                    dispatcher.sendHeartbeat(mapOf("location" to locationData))
                    Log.d(TAG, "Boot heartbeat: lat=${cached.latitude}, lon=${cached.longitude}, acc=${cached.accuracy}m")
                } else {
                    Log.d(TAG, "Boot heartbeat: no cached location, skipping")
                }
                handler.postDelayed(this, intervalSeconds * 1000L)
            }
        }
        bootHeartbeatRunnable = runnable
        handler.postDelayed(runnable, intervalSeconds * 1000L)
        Log.d(TAG, "Boot-mode heartbeat started (interval=${intervalSeconds}s)")
    }

    private fun stopBootTrackingInternal() {
        stopBootHeartbeat()
        LocationService.stopStationaryTimer()
        bootSpeedMotionManager?.stop()
        bootSpeedMotionManager = null
        bootMotionDetector?.stop()
        bootMotionDetector = null
        bootSmartMotionCoordinator = null
        bootLocationEngine?.speedMotionSpeedSink = null
        bootLocationEngine?.destroy()
        bootLocationEngine = null
    }

    // =========================================================================
    // Notification
    // =========================================================================

    private fun startForegroundWithNotification() {
        createNotificationChannel()
        val notification = buildNotification()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = configManager.getFgChannelId()
            val channelName = configManager.getFgChannelName()
            val importance = when (configManager.getFgNotificationPriority()) {
                -2 -> NotificationManager.IMPORTANCE_MIN
                -1 -> NotificationManager.IMPORTANCE_LOW
                0 -> NotificationManager.IMPORTANCE_DEFAULT
                1 -> NotificationManager.IMPORTANCE_HIGH
                2 -> NotificationManager.IMPORTANCE_HIGH
                else -> NotificationManager.IMPORTANCE_DEFAULT
            }

            val channel = NotificationChannel(channelId, channelName, importance).apply {
                setShowBadge(false)
                enableVibration(false)
                enableLights(false)
            }

            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val channelId = configManager.getFgChannelId()
        val title = configManager.getFgNotificationTitle()
        val text = configManager.getFgNotificationText()
        val ongoing = configManager.getFgNotificationOngoing()

        // Launch activity intent
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = if (launchIntent != null) {
            PendingIntent.getActivity(
                this, 0, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        } else null

        val builder = NotificationCompat.Builder(this, channelId)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(ongoing)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(configManager.getFgNotificationPriority())

        // Set small icon
        val smallIconName = configManager.getFgNotificationSmallIcon()
        val smallIconResId = if (smallIconName != null) {
            resources.getIdentifier(smallIconName, "drawable", packageName)
        } else {
            // Default: app icon
            applicationInfo.icon
        }
        if (smallIconResId != 0) {
            builder.setSmallIcon(smallIconResId)
        } else {
            builder.setSmallIcon(applicationInfo.icon)
        }

        // Color
        val colorStr = configManager.getFgNotificationColor()
        if (colorStr != null) {
            try {
                builder.color = android.graphics.Color.parseColor(colorStr)
            } catch (_: IllegalArgumentException) {
            }
        }

        pendingIntent?.let { builder.setContentIntent(it) }

        // Add action buttons
        val actions = configManager.getFgActions()
        for ((index, actionLabel) in actions.withIndex()) {
            val actionIntent = Intent(this, LocationService::class.java).apply {
                action = ACTION_BUTTON
                putExtra(EXTRA_BUTTON_ACTION, actionLabel)
            }
            val actionPendingIntent = PendingIntent.getService(
                this, 1000 + index, actionIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            builder.addAction(0, actionLabel, actionPendingIntent)
        }

        return builder.build()
    }

    private fun updateNotificationContent() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ID, buildNotification())
    }

    private fun updateNotificationVisibility() {
        if (!isRunning) return
        val showOnPauseOnly = configManager.getShowNotificationOnPauseOnly()
        val inForeground = isAppInForeground()

        val changed = inForeground != lastInForeground
        lastInForeground = inForeground

        if (showOnPauseOnly) {
            if (inForeground) {
                if (isForegroundService) {
                    Log.d(TAG, "Suppressing notification (App in foreground)")
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    isForegroundService = false
                }
            } else {
                // Show in background if not already shown OR if we just transitioned.
                if (!isForegroundService || changed) {
                    Log.d(TAG, "Showing notification (App in background)")
                    startForegroundWithNotification()
                    isForegroundService = true
                }
            }
        } else {
            // Persistent mode: Always ensure it's shown.
            if (!isForegroundService) {
                Log.d(TAG, "Showing persistent notification")
                startForegroundWithNotification()
                isForegroundService = true
            } else if (changed && !inForeground) {
                // Optimization: Re-show when moving to background in case it was
                // manually dismissed while the app was in the foreground.
                Log.d(TAG, "Restoring persistent notification on background transition")
                startForegroundWithNotification()
                isForegroundService = true
            }
        }
    }

    private fun isAppInForeground(): Boolean {
        // Layer 1: Process-level lifecycle check (Accuracy-focused)
        val lifecycleState = ProcessLifecycleOwner.get().lifecycle.currentState
        val lifecycleForeground = lifecycleState.isAtLeast(Lifecycle.State.STARTED)

        // Layer 2: OS-level process importance check (Reliability-focused)
        // Using getMyMemoryState is more efficient and reliable for the current process.
        val processInfo = ActivityManager.RunningAppProcessInfo()
        ActivityManager.getMyMemoryState(processInfo)
        val importanceForeground = processInfo.importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_VISIBLE

        Log.d(TAG, "Foreground check: lifecycle=$lifecycleState, importance=${processInfo.importance}")

        return lifecycleForeground || importanceForeground
    }
}
