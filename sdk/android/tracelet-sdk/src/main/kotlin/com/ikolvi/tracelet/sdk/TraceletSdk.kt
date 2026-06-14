package com.ikolvi.tracelet.sdk

import android.Manifest
import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import com.ikolvi.tracelet.sdk.algorithm.BatteryBudgetEngine
import com.ikolvi.tracelet.sdk.algorithm.TripManager
import com.ikolvi.tracelet.sdk.attestation.DeviceAttestor
import com.ikolvi.tracelet.sdk.audit.AuditTrailManager
import uniffi.tracelet_core.DatabaseManager as RustDatabaseManager
import uniffi.tracelet_core.EngineState as RustEngineState
import uniffi.tracelet_core.EventDispatcher as RustEventDispatcher


import com.ikolvi.tracelet.sdk.geofence.GeofenceManager
import com.ikolvi.tracelet.sdk.location.LocationDataSink
import com.ikolvi.tracelet.sdk.location.LocationEngine
import com.ikolvi.tracelet.sdk.location.PeriodicLocationWorker
import com.ikolvi.tracelet.sdk.motion.MotionDetector
import com.ikolvi.tracelet.sdk.privacy.PrivacyZoneManager
import com.ikolvi.tracelet.sdk.receiver.BootReceiver
import com.ikolvi.tracelet.sdk.receiver.GeofenceBroadcastReceiver
import com.ikolvi.tracelet.sdk.schedule.ScheduleManager
import com.ikolvi.tracelet.sdk.service.LocationService
import com.ikolvi.tracelet.sdk.model.TraceletTripEvent
import com.ikolvi.tracelet.sdk.model.AuthorizationStatus
import com.ikolvi.tracelet.sdk.model.TrackingMode
import com.ikolvi.tracelet.sdk.util.BatteryUtils
import com.ikolvi.tracelet.sdk.util.OemCompat
import com.ikolvi.tracelet.sdk.util.SoundManager
import com.ikolvi.tracelet.sdk.util.TraceletLogger
import com.ikolvi.tracelet.sdk.util.TraceletPermissionManager
import com.ikolvi.tracelet.sdk.sync.DartSyncInterceptor

/**
 * Main entry point for the Tracelet Background Geolocation SDK (Android).
 *
 * Framework-agnostic singleton that orchestrates all subsystems: location
 * engine, motion detector, geofence manager, HTTP sync, database, and
 * foreground service. Flutter, React Native, or native Android apps inject
 * their own [TraceletEventSender] before calling [initialize].
 *
 * Usage:
 * ```kotlin
 * val sdk = TraceletSdk.getInstance(context)
 * sdk.setEventSender(myEventSender)
 * sdk.initialize()
 * sdk.ready(configMap) { state -> /* ready */ }
 * sdk.start()
 * ```
 */
class TraceletSdk private constructor(private val context: Context) {

    companion object {
        @Volatile
        private var instance: TraceletSdk? = null

        /** Battery budget sampling interval: 5 minutes. */
        private const val BATTERY_SAMPLE_INTERVAL_MS = 5 * 60 * 1000L

        fun getInstance(context: Context): TraceletSdk {
            return instance ?: synchronized(this) {
                instance ?: TraceletSdk(context.applicationContext).also { instance = it }
            }
        }
    }

    // =========================================================================
    // Subsystems — public so host frameworks (Flutter, React Native, etc.)
    // can do post-init wiring (e.g. connecting headless callbacks)
    // =========================================================================

    val configManager: ConfigManager by lazy { ConfigManager.getInstance(context) }
    val stateManager: StateManager by lazy { StateManager(context) }

    lateinit var locationEngine: LocationEngine
        internal set
    lateinit var motionDetector: MotionDetector
        internal set
    lateinit var speedMotionManager: com.ikolvi.tracelet.sdk.motion.SpeedMotionManager
        internal set
    lateinit var geofenceManager: GeofenceManager
        internal set
    lateinit var smartMotionCoordinator: com.ikolvi.tracelet.sdk.motion.SmartMotionCoordinator
        internal set

    lateinit var scheduleManager: ScheduleManager
        internal set
    val logger: TraceletLogger by lazy { TraceletLogger(context, configManager) }
    lateinit var soundManager: SoundManager
        internal set
    lateinit var permissionManager: TraceletPermissionManager
        internal set
    lateinit var auditTrailManager: AuditTrailManager
        internal set
    lateinit var privacyZoneManager: PrivacyZoneManager
        internal set

    lateinit var deviceAttestor: DeviceAttestor
        internal set

    // ── Rust Core subsystems ──
    /** Rust-native SQLite database for location persistence. */
    var rustDatabase: RustDatabaseManager? = null
        private set

    /** Rust-native engine state (config + health). */
    var rustEngineState: RustEngineState? = null
        private set
    /** Rust-native event dispatcher that orchestrates persist → sync. */
    var rustEventDispatcher: RustEventDispatcher? = null
        private set

    private lateinit var eventSender: TraceletEventSender
    val mainHandler by lazy { Handler(Looper.getMainLooper()) }

    // Algorithms
    lateinit var tripManager: TripManager
        internal set
    private var batteryBudgetEngine: BatteryBudgetEngine? = null
    private var batteryBudgetRunnable: Runnable? = null

    // 3.3.0 behavior engines (opt-in, default off)
    private var telematicsEngine: uniffi.tracelet_core.TelematicsEngine? = null
    private var transportClassifier: uniffi.tracelet_core.TransportModeClassifier? = null
    private var impactDetector: uniffi.tracelet_core.ImpactDetector? = null
    private val accelBuffer = java.util.Collections.synchronizedList(mutableListOf<Double>())
    private var accelWindowRunnable: Runnable? = null
    private var impactConfirmRunnable: Runnable? = null
    @Volatile private var lastSpeedMps: Double = 0.0
    @Volatile private var lastLat: Double = 0.0
    @Volatile private var lastLng: Double = 0.0
    private val accelWindowMs = 1000L
    private val impactConfirmPollMs = 1000L

    var activity: Activity? = null
    var isReady: Boolean = false
        private set

    val isTracking: Boolean
        get() = ::locationEngine.isInitialized && (locationEngine.isTracking || LocationService.isServiceRunning())

    interface SyncProvider {
        fun syncBatchBlocking(config: uniffi.tracelet_core.HttpConfig, records: List<uniffi.tracelet_core.DbLocationRecord>): Long

        /**
         * Cancels any pending/in-flight auto-sync (e.g. a debounced background
         * sync) so nothing keeps POSTing after [stop] is called. Default no-op
         * for providers that don't queue work.
         */
        fun cancelPendingSync() {}
    }

    var syncProvider: SyncProvider? = null
    var dartSyncInterceptor: DartSyncInterceptor? = null

    private var heartbeatRunnable: Runnable? = null
    private var stopAfterElapsedRunnable: Runnable? = null
    private var syncIntervalRunnable: Runnable? = null

    /**
     * Running total of locations that have been successfully synced and pruned
     * from the local store since the last [destroySyncedLocations] call (#154).
     */
    private val syncedLocationsRemoved = java.util.concurrent.atomic.AtomicLong(0L)

    /** Async permission callback — set before triggering OS dialog. */
    internal var pendingPermissionCallback: ((AuthorizationStatus) -> Unit)? = null

    /**
     * Clears any pending permission callback, invoking it with the current
     * permission status so callers are not left waiting indefinitely.
     *
     * Called by the Flutter plugin when the Activity is detached while a
     * permission dialog may still be showing.
     */
    fun clearPendingPermissionCallback() {
        val callback = pendingPermissionCallback
        pendingPermissionCallback = null
        callback?.invoke(getPermissionStatus())
    }

    // =========================================================================
    // Injection
    // =========================================================================

    /**
     * Sets the event sender implementation. Must be called before [initialize].
     */
    fun setEventSender(sender: TraceletEventSender) {
        this.eventSender = sender
        
        if (::locationEngine.isInitialized) locationEngine.events = sender
        if (::motionDetector.isInitialized) motionDetector.events = sender
        if (::speedMotionManager.isInitialized) speedMotionManager.events = sender
        
        // Propagate to active background boot trackers so the UI gets events
        // after being swiped away and reopened.
        try {
            com.ikolvi.tracelet.sdk.service.LocationService.bootLocationEngine?.events = sender
            com.ikolvi.tracelet.sdk.service.LocationService.bootMotionDetector?.events = sender
            com.ikolvi.tracelet.sdk.service.LocationService.bootSpeedMotionManager?.events = sender
            com.ikolvi.tracelet.sdk.service.LocationService.bootSmartMotionCoordinator?.events = sender
        } catch (e: Exception) {
            android.util.Log.e("Tracelet", "Failed to update boot event senders: ${e.message}")
        }
    }

    fun getEventSender(): TraceletEventSender = eventSender

    /**
     * Safely registers a SyncProvider (like TraceletSyncSink).
     * This ensures it attaches to the foreground LocationEngine if ready() was called,
     * OR the background LocationService.bootLocationEngine if the app launched in the background
     * and ready() was bypassed.
     */
    fun registerSyncProvider(provider: SyncProvider) {
        this.syncProvider = provider
        if (provider is com.ikolvi.tracelet.sdk.location.LocationDataSink) {
            if (::locationEngine.isInitialized) {
                locationEngine.registerSink(provider)
            }
            com.ikolvi.tracelet.sdk.service.LocationService.bootLocationEngine?.registerSink(provider)
        }
    }

    // =========================================================================
    // Initialization
    // =========================================================================

    /**
     * Creates all subsystems. Call [setEventSender] first.
     */
    fun initialize() {
        check(::eventSender.isInitialized) {
            "setEventSender() must be called before initialize()"
        }

        // Bootstrap factory for headless/boot restart
        TraceletBootstrap.eventSenderFactory = { ctx ->
            getInstance(ctx).getEventSender()
        }

        // Persistence and Logger are now lazy properties.

        // ── Rust Core bootstrap ──
        val dbDir = context.filesDir.resolve("tracelet")
        if (!dbDir.exists()) dbDir.mkdirs()
        val dbPath = dbDir.resolve("tracelet.db").absolutePath
        try {
            val db = RustDatabaseManager(dbPath)
            
            val savedConfig = configManager.getConfig()
            if (savedConfig["encryptDatabase"] == true) {
                val key = configManager.getEncryptionKey() ?: ""
                db.setEncryptionKey(key)
            } else {
                db.setEncryptionKey("")
            }
            
            rustDatabase = db
            logger.rustDatabase = db // Inject the DB instance so it can persist logs
            logger.debug("Successfully initialized Rust Native Database: $dbPath")

            val state = RustEngineState()
            val dispatcher = RustEventDispatcher(db, state)
            rustDatabase = db
            rustEngineState = state
            rustEventDispatcher = dispatcher
            logger.info("Rust Core initialized: $dbPath")
            syncConfigToRustFlat()
        } catch (e: Exception) {
            logger.error("Failed to initialize Rust Core: ${e.message}")
        }

        // Enterprise
        auditTrailManager = AuditTrailManager(context, configManager, rustDatabase)
        privacyZoneManager = PrivacyZoneManager(context, configManager, rustDatabase)
        deviceAttestor = DeviceAttestor(context)

        // Location engine
        locationEngine = LocationEngine(
            context, configManager, stateManager, eventSender
        )
        locationEngine.auditTrailManager = auditTrailManager
        locationEngine.privacyZoneManager = privacyZoneManager
        locationEngine.onLocationPersisted = {
        }
        
        // Register the Rust Database sink
        locationEngine.registerSink(object : com.ikolvi.tracelet.sdk.location.LocationDataSink {
            override fun insertLocation(location: Map<String, Any?>) {
                this@TraceletSdk.insertLocation(location)
                processTelematics(location)
            }
        })

        // Register sync provider as a sink if it was attached prior to initialization
        if (syncProvider is com.ikolvi.tracelet.sdk.location.LocationDataSink) {
            locationEngine.registerSink(syncProvider as com.ikolvi.tracelet.sdk.location.LocationDataSink)
        }

        // Trip manager
        tripManager = TripManager()
        tripManager.onTripEnd = { data -> eventSender.sendTrip(data) }

        // Motion detector
        motionDetector = MotionDetector(
            context, configManager, stateManager, eventSender, logger
        )
        motionDetector.onMotionStateChanged = { isMoving ->
            handleMotionStateChange(isMoving)
            // Keep the LocationEngine's activity in sync so enriched locations
            // don't report a permanent "unknown" (#155).
            val (activityType, activityConfidence) = motionDetector.getCurrentActivity()
            locationEngine.setCurrentActivity(activityType, activityConfidence)
        }
        // Push activity into the LocationEngine the moment it changes, even when
        // no motion-state transition occurs (#155).
        motionDetector.onActivityChanged = { type, confidence ->
            locationEngine.setCurrentActivity(type, confidence)
        }
        // 3.3.0: feed accelerometer samples (g) to the classifier/impact window
        // keystone — only buffers while a consumer engine is active.
        motionDetector.onAccelSample = { magnitudeG ->
            if (transportClassifier != null || impactDetector != null) {
                accelBuffer.add(magnitudeG)
            }
        }
        motionDetector.onStopRequested = {
            mainHandler.post {
                stateManager.enabled = false
                stateManager.isMoving = false
                locationEngine.stop()
                motionDetector.stop()
                stopHeartbeat()
                if (configManager.isForegroundServiceEnabled()) {
                    LocationService.stop(context)
                }
                eventSender.sendEnabledChange(false)
                logger.info("stopOnStationary — tracking stopped by motion detector")
            }
        }

        // Speed-based motion detector
        speedMotionManager = com.ikolvi.tracelet.sdk.motion.SpeedMotionManager(
            configManager, stateManager, eventSender,
            object : com.ikolvi.tracelet.sdk.motion.SpeedMotionManager.SpeedMotionCallback {
                override fun switchToContinuous() {
                    if (configManager.getMotionDetectionMode() == com.ikolvi.tracelet.sdk.model.MotionDetectionMode.SMART) {
                        smartMotionCoordinator.onSpeedStateChange(true)
                        return
                    }
                    val useForeground = configManager.isForegroundServiceEnabled()
                    if (useForeground) {
                        LocationService.switchToContinuous(locationEngine, stateManager)
                    } else {
                        PeriodicLocationWorker.cancel(context)
                        stateManager.trackingMode = TrackingMode.CONTINUOUS
                        locationEngine.start()
                    }
                    // Dispatch motionchange event so Flutter UI updates _isMoving
                    stateManager.isMoving = true
                    val locationMap = locationEngine.getLastLocation()?.let {
                        locationEngine.enrichLocation(it, "motionchange")
                    } ?: mapOf("is_moving" to true)
                    eventSender.sendMotionChange(locationMap)
                }

                override fun switchToStationaryPeriodic() {
                    if (configManager.getMotionDetectionMode() == com.ikolvi.tracelet.sdk.model.MotionDetectionMode.SMART) {
                        smartMotionCoordinator.onSpeedStateChange(false)
                        return
                    }
                    val useForeground = configManager.isForegroundServiceEnabled()
                    if (useForeground) {
                        LocationService.switchToStationaryPeriodic(locationEngine, configManager, stateManager)
                    } else {
                        locationEngine.stop()
                        val lastLoc = locationEngine.getLastLocation()
                        if (lastLoc != null) {
                            stateManager.lastPeriodicLatitude = lastLoc.latitude
                            stateManager.lastPeriodicLongitude = lastLoc.longitude
                            stateManager.lastLocationTime = lastLoc.time
                        }
                        stateManager.trackingMode = TrackingMode.PERIODIC
                        val interval = configManager.getStationaryPeriodicInterval()
                        
                        val useExactAlarms = configManager.getPeriodicUseExactAlarms() || interval < 900
                        if (useExactAlarms) {
                            PeriodicLocationWorker.scheduleOneTime(context)
                            PeriodicLocationWorker.scheduleExactAlarm(context, interval)
                        } else {
                            PeriodicLocationWorker.schedule(context, interval)
                        }
                    }
                    // Dispatch motionchange event so Flutter UI updates _isMoving
                    stateManager.isMoving = false
                    val locationMap = locationEngine.getLastLocation()?.let {
                        locationEngine.enrichLocation(it, "motionchange")
                    } ?: mapOf("is_moving" to false)
                    eventSender.sendMotionChange(locationMap)
                }

                override fun switchToStationaryGeofences() {
                    if (configManager.getMotionDetectionMode() == com.ikolvi.tracelet.sdk.model.MotionDetectionMode.SMART) {
                        smartMotionCoordinator.onSpeedStateChange(false)
                        return
                    }
                    val useForeground = configManager.isForegroundServiceEnabled()
                    if (useForeground) {
                        LocationService.switchToStationaryGeofences(locationEngine, stateManager)
                    } else {
                        locationEngine.stop()
                        stateManager.trackingMode = TrackingMode.GEOFENCES
                    }
                    // Dispatch motionchange event so Flutter UI updates _isMoving
                    stateManager.isMoving = false
                    val locationMap = locationEngine.getLastLocation()?.let {
                        locationEngine.enrichLocation(it, "motionchange")
                    } ?: mapOf("is_moving" to false)
                    eventSender.sendMotionChange(locationMap)
                }
            }
        )
        
        smartMotionCoordinator = com.ikolvi.tracelet.sdk.motion.SmartMotionCoordinator(
            context, configManager, stateManager, eventSender, locationEngine, motionDetector, logger
        )
        smartMotionCoordinator.syncCurrentMode()

        // Geofencing
        geofenceManager = GeofenceManager(
            context, configManager, eventSender, rustDatabase
        ).apply {
            onGeofenceEvent = { eventMap ->
                insertLocation(eventMap)
            }
        }
        GeofenceBroadcastReceiver.geofenceManager = geofenceManager

        // Schedule
        scheduleManager = ScheduleManager(
            context, configManager, stateManager, eventSender
        )
        scheduleManager.onScheduleStart = { handleScheduleStart() }
        scheduleManager.onScheduleStop = { handleScheduleStop() }

        // Utilities
        soundManager = SoundManager(context, configManager)
        permissionManager = TraceletPermissionManager(context)

        // Re-wire periodic mode if already active (process restart)
        if (stateManager.enabled && stateManager.trackingMode == TrackingMode.PERIODIC) {
            PeriodicLocationWorker.eventSender = eventSender
        }
    }

    // =========================================================================
    // Lifecycle — ready
    // =========================================================================

    /**
     * Initializes configuration and completes SDK startup.
     *
     * Typed overload that accepts a [TraceletConfig] for type-safe
     * configuration matching the Dart API:
     *
     * ```kotlin
     * sdk.ready(TraceletConfig(
     *     app = AppConfig(stopOnTerminate = false, startOnBoot = true),
     * )) { state -> /* ready */ }
     * ```
     */
    fun requestStateFlush() {
        val providerState = locationEngine.buildProviderState().toMutableMap()
        providerState["event"] = "providerchange"
        eventSender.sendProviderChange(providerState)
        
        val isMoving = stateManager.isMoving
        val locationMap = locationEngine.getLastGpsLocation()?.let { 
            val map = locationEngine.enrichLocation(it, "motionchange").toMutableMap()
            map["is_moving"] = isMoving
            map
        } ?: mutableMapOf<String, Any?>("is_moving" to isMoving)
        eventSender.sendMotionChange(locationMap)
    }

    /**
     * Initializes configuration and completes SDK startup.
     *
     * Example:
     * ```
     *
     * @param config Typed configuration.
     * @param callback Receives the current state map when ready.
     */
    fun ready(config: com.ikolvi.tracelet.sdk.model.TraceletConfig, callback: (Map<String, Any?>) -> Unit) {
        ready(config.toMap(), callback)
    }

    /**
     * Initializes configuration and completes SDK startup.
     *
     * @param config Configuration map.
     * @param callback Receives the current state map when ready.
     */
    fun ready(config: Map<String, Any?>, callback: (Map<String, Any?>) -> Unit) {
        val merged = configManager.setConfig(config)

        if (merged["encryptDatabase"] == true) {
            val key = merged["encryptionKey"] as? String ?: ""
            rustDatabase?.setEncryptionKey(key)
        } else {
            rustDatabase?.setEncryptionKey("")
        }

        // Auto-encrypt if enabled
        if (merged["encryptDatabase"] == true) {
            encryptDatabase()
        }

        // Remote config
        val remoteUrl = configManager.getRemoteConfigUrl()
        if (!remoteUrl.isNullOrEmpty()) {
            fetchRemoteConfig(remoteUrl, merged, callback)
            return
        }

        completeReady(merged, callback)
    }

    private fun fetchRemoteConfig(
        url: String,
        localConfig: Map<String, Any?>,
        callback: (Map<String, Any?>) -> Unit,
    ) {
        // Reject non-HTTPS URLs
        if (!url.startsWith("https://")) {
            logger.warning("Remote config URL rejected: only HTTPS is allowed")
            completeReady(localConfig, callback)
            return
        }

        val timeout = configManager.getRemoteConfigTimeout()
        val headers = configManager.getRemoteConfigHeaders()
        // TODO: Port remote config fetch to Rust
        // For now, proceed with localConfig
        completeReady(localConfig, callback)
    }

    private fun completeReady(
        config: Map<String, Any?>,
        callback: (Map<String, Any?>) -> Unit,
    ) {
        // Stop boot-mode native tracking now that the Dart side has
        // explicitly called ready().  Deferring this from initialize()
        // ensures killed-state / headless-restart boot tracking keeps
        // running until the foreground app is fully ready to take over.
        LocationService.stopBootTracking()

        if (configManager.isDebug()) soundManager.start()

        logger.pruneOldLogs()
        updateBootReceiverState()

        if (configManager.getAttestationEnabled()) {
            deviceAttestor.startRefresh(configManager.getAttestationRefreshInterval())
        }

        // Initialize battery budget engine from config
        val budgetPerHour = configManager.getBatteryBudgetPerHour()
        if (budgetPerHour > 0) {
            batteryBudgetEngine = BatteryBudgetEngine(
                targetBudgetPerHour = budgetPerHour,
                initialDistanceFilter = configManager.getDistanceFilter(),
                initialAccuracyIndex = configManager.getDesiredAccuracy(),
            )
        } else {
            batteryBudgetEngine = null
        }

        initBehaviorEngines()

        isReady = true
        syncConfigToRustFlat()
        checkSyncProvider()

        // Apply the interval-based sync cadence from the freshly-applied config (#149).
        startSyncIntervalTimer()

        // Rebuild the native location processor with the config just applied by
        // ready(). Without this the engine keeps the previous/default processor
        // (e.g. distanceFilter=20) in memory and silently filters fixes the new
        // config (e.g. distanceFilter=0) should have accepted (#157).
        if (::locationEngine.isInitialized) locationEngine.rebuildProcessor()

        if (stateManager.enabled) {
            val motionMode = configManager.getMotionDetectionMode()
            if (motionMode == com.ikolvi.tracelet.sdk.model.MotionDetectionMode.SMART || 
                motionMode == com.ikolvi.tracelet.sdk.model.MotionDetectionMode.SPEED) {
                logger.info("Resuming tracking with motion detection on ready/takeover")
                start(isResume = true)
            } else {
                when (stateManager.trackingMode) {
                    TrackingMode.CONTINUOUS -> {
                        logger.info("Resuming continuous tracking on ready/takeover")
                        start(isResume = true)
                    }
                    TrackingMode.PERIODIC -> {
                        logger.info("Resuming periodic tracking on ready/takeover")
                        startPeriodic()
                    }
                    TrackingMode.GEOFENCES -> {
                        logger.info("Resuming geofence tracking on ready/takeover")
                        startGeofences()
                    }
                }
            }
        }

        val stateMap = stateManager.toMap(config)
        logger.info("ready() called")
        callback(stateMap)
    }

    // =========================================================================
    // Lifecycle — start / stop
    // =========================================================================

    /**
     * Starts continuous location tracking.
     *
     * @return Error string if not ready or permission denied, null on success.
     */
    fun start(isResume: Boolean = false): String? {
        if (!isReady) return "NOT_READY"

        val authStatus = permissionManager.getAuthorizationStatus(activity)
        if (authStatus != AuthorizationStatus.WHEN_IN_USE &&
            authStatus != AuthorizationStatus.ALWAYS
        ) {
            return "PERMISSION_DENIED"
        }

        // Clean up boot tracking
        LocationService.stopBootTracking()

        // Stop periodic if active
        locationEngine.stopPeriodic()
        PeriodicLocationWorker.cancel(context)
        PeriodicLocationWorker.eventSender = null

        // A manual start() while tracking is ALREADY active is a no-op. Previously
        // it reset isMoving to the configured default (isMoving=false) and forced
        // changePace(false), so calling start() a second time slammed the device
        // into the STATIONARY state even while moving. Calling start() again must
        // not disturb the live motion state — use changePace() to change pace.
        if (!isResume && isTracking) {
            stateManager.enabled = true
            stateManager.trackingMode = TrackingMode.CONTINUOUS
            logger.debug("start() — already tracking; ignoring redundant start (no pace reset)")
            return null
        }

        stateManager.enabled = true
        stateManager.trackingMode = TrackingMode.CONTINUOUS
        if (!isResume) {
            stateManager.isMoving = configManager.getIsMoving()
        }

        val shouldForceMoving = stateManager.isMoving

        if (configManager.isForegroundServiceEnabled()) {
            LocationService.start(context)
        }

        // Wire proximity-based geofence monitoring + trip waypoints
        locationEngine.onLocationUpdate = { lat, lng ->
            geofenceManager.updateProximity(lat, lng)
            if (configManager.getGeofenceModeHighAccuracy()) {
                geofenceManager.evaluateHighAccuracyProximity(lat, lng)
            }
            tripManager.onLocationReceived(lat, lng, System.currentTimeMillis().toString())
        }

        // Start the appropriate motion detector
        val motionMode = configManager.getMotionDetectionMode()
        
        if (motionMode == com.ikolvi.tracelet.sdk.model.MotionDetectionMode.SPEED) {
            speedMotionManager.start(forceMoving = shouldForceMoving)
            if (!shouldForceMoving) {
                val restoredMoving = speedMotionManager.getCurrentState() != "stationary"
                if (::smartMotionCoordinator.isInitialized) {
                    smartMotionCoordinator.onSpeedStateChange(restoredMoving)
                }
                stateManager.isMoving = restoredMoving
            }
            locationEngine.speedMotionSpeedSink = { speed -> speedMotionManager.onLocation(speed) }
            
            // Feed the last known GPS speed immediately on startup to prevent deadlocks when physically stationary
            speedMotionManager.onLocation(locationEngine.lastEffectiveSpeed)
            
            if (shouldForceMoving || stateManager.isMoving) {
                val locationMap = locationEngine.getLastLocation()?.let {
                    locationEngine.enrichLocation(it, "motionchange")
                } ?: mapOf("is_moving" to stateManager.isMoving)
                eventSender.sendMotionChange(locationMap)
            }
        } else if (motionMode == com.ikolvi.tracelet.sdk.model.MotionDetectionMode.SMART) {
            speedMotionManager.start(forceMoving = shouldForceMoving)
            if (!shouldForceMoving) {
                val restoredMoving = speedMotionManager.getCurrentState() != "stationary"
                if (::smartMotionCoordinator.isInitialized) {
                    smartMotionCoordinator.onSpeedStateChange(restoredMoving)
                }
                stateManager.isMoving = restoredMoving
            }
            locationEngine.speedMotionSpeedSink = { speed -> speedMotionManager.onLocation(speed) }
            
            // Feed the last known GPS speed immediately on startup to prevent deadlocks when physically stationary
            speedMotionManager.onLocation(locationEngine.lastEffectiveSpeed)
            
            if (shouldForceMoving || stateManager.isMoving) {
                val locationMap = locationEngine.getLastLocation()?.let {
                    locationEngine.enrichLocation(it, "motionchange")
                } ?: mapOf("is_moving" to stateManager.isMoving)
                eventSender.sendMotionChange(locationMap)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val hasMotion = ContextCompat.checkSelfPermission(
                    context, Manifest.permission.ACTIVITY_RECOGNITION
                ) == PackageManager.PERMISSION_GRANTED
                if (!hasMotion) {
                    permissionManager.requestActivityRecognition(activity)
                } else {
                    motionDetector.start()
                }
            } else {
                motionDetector.start()
            }
        } else {
            // Activity recognition permission + accelerometer motion detector
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val hasMotion = ContextCompat.checkSelfPermission(
                    context, Manifest.permission.ACTIVITY_RECOGNITION
                ) == PackageManager.PERMISSION_GRANTED
                if (!hasMotion) {
                    permissionManager.requestActivityRecognition(activity)
                } else {
                    motionDetector.start()
                }
            } else {
                motionDetector.start()
            }
        }

        if (stateManager.isMoving) {
            locationEngine.start()
        } else {
            changePace(false)
        }

        startHeartbeat()
        startStopAfterElapsedTimer()
        startBatteryBudgetSampling()
        startBehaviorSampling()

        eventSender.sendEnabledChange(true)
        logger.info("start() — tracking started")
        return null // success
    }

    fun stop() {
        stateManager.enabled = false
        stateManager.isMoving = false

        if (::locationEngine.isInitialized) {
            locationEngine.stop()
            locationEngine.onLocationUpdate = null
            locationEngine.speedMotionSpeedSink = null
        }
        // Cancel any pending/in-flight background sync so it doesn't keep POSTing
        // after tracking is stopped (e.g. a debounced headless sync mid-flight).
        syncProvider?.cancelPendingSync()
        if (::motionDetector.isInitialized) motionDetector.stop()
        if (::speedMotionManager.isInitialized) speedMotionManager.stop()
        stopHeartbeat()
        stopSyncIntervalTimer()
        cancelStopAfterElapsedTimer()
        if (::tripManager.isInitialized) tripManager.reset()
        stopBatteryBudgetSampling()
        batteryBudgetEngine?.reset()
        stopBehaviorSampling()
        telematicsEngine?.reset()

        PeriodicLocationWorker.cancel(context)
        PeriodicLocationWorker.eventSender = null

        // Tear down service-side tracking synchronously. The stationary
        // periodic timer and boot-mode engine live in LocationService's
        // companion, not in this SDK's locationEngine, so relying on the
        // async ACTION_STOP intent alone leaves them running (e.g. SMART
        // mode switched to stationary-periodic while backgrounded, or a
        // sticky service restart bootstrapped a boot engine).
        LocationService.stopStationaryTimer()
        LocationService.stopBootTracking()

        if (configManager.isForegroundServiceEnabled() || LocationService.isServiceRunning()) {
            LocationService.stop(context)
        }

        if (::eventSender.isInitialized) eventSender.sendEnabledChange(false)
        logger.info("stop() — tracking stopped")
    }

    fun getState(): Map<String, Any?> {
        return stateManager.toMap(configManager.getConfig())
    }

    // =========================================================================
    // Lifecycle — startGeofences
    // =========================================================================

    fun startGeofences(): String? {
        if (!isReady) return "NOT_READY"

        stateManager.enabled = true
        stateManager.trackingMode = TrackingMode.GEOFENCES

        geofenceManager.reRegisterAll()

        locationEngine.onLocationUpdate = { lat, lng ->
            geofenceManager.updateProximity(lat, lng)
            if (configManager.getGeofenceModeHighAccuracy()) {
                geofenceManager.evaluateHighAccuracyProximity(lat, lng)
            }
        }

        if (configManager.getGeofenceModeHighAccuracy()) {
            geofenceManager.clearHighAccuracyState()
        }
        locationEngine.start()

        if (configManager.isForegroundServiceEnabled()) {
            LocationService.start(context)
        }

        eventSender.sendEnabledChange(true)
        logger.info(
            "startGeofences() — geofence-only mode " +
                "(highAccuracy=${configManager.getGeofenceModeHighAccuracy()})"
        )
        return null
    }

    // =========================================================================
    // Lifecycle — startPeriodic
    // =========================================================================

    fun startPeriodic(): String? {
        if (!isReady) return "NOT_READY"

        val authStatus = permissionManager.getAuthorizationStatus(activity)
        if (authStatus != AuthorizationStatus.WHEN_IN_USE &&
            authStatus != AuthorizationStatus.ALWAYS
        ) {
            return "PERMISSION_DENIED"
        }

        LocationService.stopBootTracking()

        locationEngine.stop()
        motionDetector.stop()
        if (configManager.isForegroundServiceEnabled()) {
            LocationService.stop(context)
        }

        stateManager.enabled = true
        stateManager.trackingMode = TrackingMode.PERIODIC
        stateManager.isMoving = false

        PeriodicLocationWorker.eventSender = eventSender

        val interval = configManager.getPeriodicLocationInterval()
        val useForeground = configManager.getPeriodicUseForegroundService()
        val useExactAlarms = configManager.getPeriodicUseExactAlarms() ||
            (!useForeground && interval < 900)

        if (useForeground) {
            if (configManager.isForegroundServiceEnabled()) {
                LocationService.start(context)
            }
            locationEngine.startPeriodic()
        } else if (useExactAlarms) {
            if (!PeriodicLocationWorker.canScheduleExactAlarms(context)) {
                logger.warning(
                    "SCHEDULE_EXACT_ALARM not granted — timing will be approximate. " +
                        "Grant 'Alarms & reminders' permission in Settings for precise intervals."
                )
                // Auto-prompt: open exact alarm settings if an Activity is available
                if (activity != null) {
                    openExactAlarmSettings()
                }
            }
            PeriodicLocationWorker.scheduleOneTime(context)
            PeriodicLocationWorker.scheduleExactAlarm(context, interval)
        } else {
            PeriodicLocationWorker.schedule(context, interval)
            PeriodicLocationWorker.scheduleOneTime(context)
        }

        startHeartbeat()
        startStopAfterElapsedTimer()
        eventSender.sendEnabledChange(true)

        val strategy = when {
            useForeground -> "foreground-service"
            useExactAlarms -> "exact-alarms"
            else -> "workmanager"
        }
        logger.info(
            "startPeriodic() — periodic tracking started " +
                "(interval=${interval}s, strategy=$strategy)"
        )
        return null
    }

    // =========================================================================
    // Config
    // =========================================================================

    /**
     * Update the SDK configuration using a typed [TraceletConfig].
     *
     * Delegates to [setConfig] with the map produced by [TraceletConfig.toMap].
     */
    fun setConfig(config: com.ikolvi.tracelet.sdk.model.TraceletConfig): Map<String, Any?> {
        return setConfig(config.toMap())
    }

    fun setConfig(config: Map<String, Any?>): Map<String, Any?> {
        if (!isReady) return mapOf(
            "enabled" to false, "isMoving" to false,
            "trackingMode" to TrackingMode.CONTINUOUS.value, "schedulerEnabled" to false, "odometer" to 0.0,
        )
        val oldConfig = configManager.getConfig()
        val merged = configManager.setConfig(config)

        if (merged["encryptDatabase"] == true) {
            val key = merged["encryptionKey"] as? String ?: ""
            rustDatabase?.setEncryptionKey(key)
        } else {
            rustDatabase?.setEncryptionKey("")
        }

        if (stateManager.enabled) {
            val locationKeys = listOf(
                "desiredAccuracy", "distanceFilter", "locationUpdateInterval",
                "fastestLocationUpdateInterval", "stationaryRadius", "deferTime",
                "disableElasticity", "elasticityMultiplier",
            )
            val needsRestart = locationKeys.any { key -> oldConfig[key] != merged[key] }
            if (needsRestart) {
                locationEngine.stop()
                locationEngine.start()
            }
        }

        updateBootReceiverState()
        syncConfigToRustFlat()
        checkSyncProvider()
        return stateManager.toMap(merged)
    }

    internal fun bootstrapForBackground(sender: TraceletEventSender) {
        if (!::eventSender.isInitialized) {
            setEventSender(sender)
        }
        if (rustDatabase == null) {
            initialize()
        }
        checkSyncProvider()
    }

    internal fun checkSyncProvider() {
        val url = configManager.getHttpUrl()
        if (!url.isNullOrEmpty() && syncProvider == null) {
            try {
                val clazz = Class.forName("com.ikolvi.tracelet.sdk.sync.NativeSyncProvider")
                val constructor = clazz.getConstructor(TraceletSdk::class.java)
                val instance = constructor.newInstance(this)
                val sink = instance as LocationDataSink
                if (::locationEngine.isInitialized) {
                    locationEngine.registerSink(sink)
                }
                syncProvider = instance as SyncProvider
                logger.info("NativeSyncProvider loaded for background sync.")
            } catch (e: Throwable) {
                logger.warning("⚠️ WARNING [Tracelet]: Failed to load NativeSyncProvider (tracelet_sync may be absent): ${e.message}")
            }
        }
    }

    fun reset(newConfig: Map<String, Any?>?) {
        if (!isReady) return
        locationEngine.destroy()
        motionDetector.stop()
        stopHeartbeat()
        stopSyncIntervalTimer()
        geofenceManager.destroy()
        LocationService.stop(context)

        stateManager.reset()
        configManager.reset(newConfig)
        isReady = false

        logger.info("reset() — all subsystems reset")
    }

    // =========================================================================
    // Location
    // =========================================================================

    fun getCurrentPosition(
        options: Map<String, Any?>,
        callback: (Map<String, Any?>?) -> Unit,
    ) {
        if (!isReady) { callback(null); return }
        locationEngine.getCurrentPosition(options, callback)
    }

    fun getLastKnownLocation(
        options: Map<String, Any?>,
        callback: (Map<String, Any?>?) -> Unit,
    ) {
        if (!isReady) { callback(null); return }
        locationEngine.getLastKnownLocation(options, callback)
    }

    fun watchPosition(options: Map<String, Any?>): Int {
        if (!isReady) return -1
        return locationEngine.watchPosition(options)
    }

    fun stopWatchPosition(watchId: Int): Boolean {
        if (!isReady) return false
        return locationEngine.stopWatchPosition(watchId)
    }

    fun changePace(isMoving: Boolean): Map<String, Any?> {
        if (!isReady) return mapOf(
            "enabled" to false, "isMoving" to false,
            "trackingMode" to TrackingMode.CONTINUOUS.value, "schedulerEnabled" to false, "odometer" to 0.0,
        )
        
        val mode = configManager.getMotionDetectionMode()
        if (mode == com.ikolvi.tracelet.sdk.model.MotionDetectionMode.SPEED) {
            if (::speedMotionManager.isInitialized) {
                speedMotionManager.onManualPaceChange(isMoving)
            }
        } else if (mode == com.ikolvi.tracelet.sdk.model.MotionDetectionMode.SMART) {
            if (::speedMotionManager.isInitialized) {
                speedMotionManager.onManualPaceChange(isMoving)
            }
            if (::motionDetector.isInitialized) {
                motionDetector.onManualPaceChange(isMoving)
            }
            if (::smartMotionCoordinator.isInitialized) {
                smartMotionCoordinator.onManualPaceChange(isMoving)
            }
        } else {
            locationEngine.changePace(isMoving)
            // Re-sync MotionDetector's sensor state so it can wake the SDK back up
            // on real motion after a manual changePace(false). Without this, the
            // accelerometer + significant-motion listeners stay torn down and we
            // can never recover from the forced-stationary state.
            if (::motionDetector.isInitialized) {
                motionDetector.onManualPaceChange(isMoving)
            }
        }
        return stateManager.toMap(configManager.getConfig())
    }

    fun getOdometer(): Double {
        if (!isReady) return 0.0
        return locationEngine.getOdometer()
    }

    fun setOdometer(value: Double): Map<String, Any?> {
        if (!isReady) return mapOf(
            "enabled" to false, "isMoving" to false,
            "trackingMode" to TrackingMode.CONTINUOUS.value, "schedulerEnabled" to false, "odometer" to 0.0,
        )
        return locationEngine.setOdometer(value)
    }

    // =========================================================================
    // Geofences
    // =========================================================================

    fun addGeofence(geofence: Map<String, Any?>): Boolean {
        if (!isReady) return false
        return geofenceManager.addGeofence(geofence)
    }

    /** Add a geofence using a typed [TraceletGeofence] model. */
    fun addGeofence(geofence: com.ikolvi.tracelet.sdk.model.TraceletGeofence): Boolean {
        return addGeofence(geofence.toMap())
    }

    fun addGeofences(geofences: List<Map<String, Any?>>) {
        if (!isReady) return
        geofenceManager.addGeofences(geofences)
    }

    /** Add multiple geofences using typed [TraceletGeofence] models. */
    fun addTypedGeofences(geofences: List<com.ikolvi.tracelet.sdk.model.TraceletGeofence>) {
        addGeofences(geofences.map { it.toMap() })
    }

    fun removeGeofence(identifier: String): Boolean {
        if (!isReady) return false
        return geofenceManager.removeGeofence(identifier)
    }

    fun removeGeofences(): Boolean {
        if (!isReady) return false
        return geofenceManager.removeGeofences()
    }

    fun getGeofences(): List<Map<String, Any?>> {
        return geofenceManager.getGeofences()
    }

    fun getGeofence(identifier: String): Map<String, Any?>? {
        return geofenceManager.getGeofence(identifier)
    }

    fun geofenceExists(identifier: String): Boolean {
        return geofenceManager.geofenceExists(identifier)
    }

    // =========================================================================
    // Persistence
    // =========================================================================

    fun getLocations(query: Map<String, Any?>?): List<Map<String, Any?>> {
        if (!isReady) return emptyList()
        val db = rustDatabase ?: return emptyList()
        
        val startTimeMs = (query?.get("start") as? Number)?.toLong() ?: (query?.get("from") as? Number)?.toLong()
        val endTimeMs = (query?.get("end") as? Number)?.toLong() ?: (query?.get("to") as? Number)?.toLong()
        val limit = (query?.get("limit") as? Number)?.toInt()
        val offset = (query?.get("offset") as? Number)?.toInt()
        val orderDescending = (query?.get("order") as? Number)?.toInt()?.let { it == 1 }
        
        val rustQuery = uniffi.tracelet_core.LocationQuery(
            startTimeMs = startTimeMs,
            endTimeMs = endTimeMs,
            limit = limit,
            offset = offset,
            orderDescending = orderDescending
        )
        
        return try {
            val records = db.getLocationsBatch(rustQuery)
            records.map { mapRecordToLocation(it) }
        } catch (e: Exception) {
            logger.error("getLocations failed: ${e.message}")
            emptyList()
        }
    }

    /**
     * Canonical mapping of a persisted [uniffi.tracelet_core.DbLocationRecord]
     * into the nested location schema used by `onLocation` and `getLocations`.
     *
     * Single source of truth so every consumer (getLocations + the sync
     * interceptor sinks) emits an identical shape and restores
     * `route_context` / audit-hash metadata (Issue #126). See [LocationMapper].
     */
    fun mapRecordToLocation(record: uniffi.tracelet_core.DbLocationRecord): Map<String, Any?> {
        val odometer = if (::locationEngine.isInitialized) locationEngine.getOdometer() else 0.0
        return com.ikolvi.tracelet.sdk.location.LocationMapper.buildLocationMap(
            id = record.id,
            uuid = record.uuid,
            timestamp = record.timestamp,
            latitude = record.latitude,
            longitude = record.longitude,
            altitude = record.altitude,
            speed = record.speed,
            heading = record.heading,
            accuracy = record.accuracy,
            isMock = record.isMock,
            activity = record.activity,
            routeContext = record.routeContext,
            isMoving = record.isMoving,
            odometer = odometer,
            eventType = record.eventType,
            eventPayload = record.eventPayload,
        )
    }

    fun getCount(query: Map<String, Any?>?): Int {
        if (!isReady) return 0
        val db = rustDatabase ?: return 0
        return try {
            val startTimeMs = (query?.get("start") as? Number)?.toLong()
                ?: (query?.get("from") as? Number)?.toLong()
            val endTimeMs = (query?.get("end") as? Number)?.toLong()
                ?: (query?.get("to") as? Number)?.toLong()
            if (startTimeMs == null && endTimeMs == null) {
                // No time filter — use the efficient native COUNT(*).
                db.getLocationsCount()
            } else {
                // The native get_locations_count ignores time bounds (#152), so a
                // filtered getCount() would otherwise return the whole-DB total.
                // Honor the query by counting the query-aware batch instead.
                db.getLocationsBatch(
                    uniffi.tracelet_core.LocationQuery(
                        startTimeMs = startTimeMs,
                        endTimeMs = endTimeMs,
                        limit = null,
                        offset = null,
                        orderDescending = null,
                    )
                ).size
            }
        } catch (e: Exception) {
            logger.error("getCount failed: ${e.message}")
            0
        }
    }

    fun destroyLocations(): Boolean {
        if (!isReady) return false
        val db = rustDatabase ?: return false
        return try {
            db.destroyLocations()
            true
        } catch (e: Exception) {
            logger.error("destroyLocations failed: ${e.message}")
            false
        }
    }

    /**
     * Destroys (clears) locations that have already been synced to the backend,
     * returning the number removed (#154).
     *
     * The Rust Core prunes each location from the local store the moment it is
     * confirmed synced (see [sync] / `clearLocationsUpTo`), so there is never a
     * "synced but still persisted" row to delete on demand. This method therefore
     * reports and resets the running total of locations that have been
     * synced-and-pruned since it was last called — a real, DB-backed figure
     * rather than the previous hardcoded `0` stub. Callers that have not synced
     * anything since the last call correctly receive `0`.
     */
    fun destroySyncedLocations(): Int {
        if (!isReady) return 0
        return syncedLocationsRemoved.getAndSet(0L).toInt()
    }

    fun destroyLocation(uuid: String): Boolean {
        if (!isReady) return false
        val db = rustDatabase ?: return false
        val id = uuid.toLongOrNull() ?: return false
        return try {
            db.destroyLocation(id)
            true
        } catch (e: Exception) {
            logger.error("destroyLocation failed: ${e.message}")
            false
        }
    }

    /**
     * Caches the timestamp of the last inserted location to prevent duplicate 
     * DB writes from the same GPS fix (e.g. from PeriodicLocationWorker).
     */
    private var lastInsertedTimestamp: String? = null

    /**
     * Inserts a location record into the Rust database and notifies registered sync sinks.
     * Prevents duplicate insertions of the exact same GPS fix based on the timestamp.
     */
    fun insertLocation(params: Map<String, Any?>): String {
        // Persist whenever the Rust DB is initialized — NOT only when isReady.
        // The headless boot/background path (bootstrapForBackground) wires the
        // DB and sync provider but never calls ready() (no Dart UI), so isReady
        // stays false. Gating on isReady here silently dropped every location
        // captured after a reboot, so the DB stayed empty and auto-sync (which
        // reads from the DB) had nothing to send. The db null-check below is the
        // correct readiness signal for persistence.
        val db = rustDatabase ?: return ""
        val coords = (params["coords"] as? Map<*, *>) ?: params
        val lat = (coords["latitude"] as? Number)?.toDouble() ?: 0.0
        val lng = (coords["longitude"] as? Number)?.toDouble() ?: 0.0
        val acc = (coords["accuracy"] as? Number)?.toDouble() ?: 0.0
        val speed = (coords["speed"] as? Number)?.toDouble() ?: 0.0
        val heading = (coords["heading"] as? Number)?.toDouble() ?: 0.0
        val altitude = (coords["altitude"] as? Number)?.toDouble() ?: 0.0
        val isMock = params["mock"] == true || params["is_mock"] == true
        val isMoving = params["is_moving"] == true
        val activityMap = params["activity"] as? Map<*, *>
        val activity = (activityMap?.get("type") as? String) ?: "unknown"
        val timestamp = params["timestamp"] as? String
        val uuid = params["uuid"] as? String
        val eventType = (params["event"] as? String) ?: "location"
        val eventPayload: String? = (params["event_payload"] as? String)
            ?: (params["geofence"] as? Map<*, *>)?.let { org.json.JSONObject(it as Map<String, Any?>).toString() }
        
        // Prevent duplicate insertions of the exact same GPS fix (e.g. from PeriodicLocationWorker)
        if (eventType == "location" && timestamp != null && timestamp == lastInsertedTimestamp) {
            return ""
        }
        if (eventType == "location") { lastInsertedTimestamp = timestamp }
        
        var routeContext = rustEngineState?.getRouteContext()
        val auditHash = params["audit_hash"] as? String
        if (auditHash != null) {
            try {
                val jsonMap = if (routeContext != null) {
                    org.json.JSONObject(routeContext)
                } else {
                    org.json.JSONObject()
                }
                jsonMap.put("audit_hash", auditHash)
                if (params["audit_previous_hash"] != null) jsonMap.put("audit_previous_hash", params["audit_previous_hash"])
                if (params["audit_chain_index"] != null) jsonMap.put("audit_chain_index", params["audit_chain_index"])
                routeContext = jsonMap.toString()
            } catch (e: Exception) {
                // Ignore and use base route context
            }
        }
        
        return try {
            val newRowId = db.insertLocation(uuid, lat, lng, acc, speed, heading, altitude, isMock, isMoving, activity, routeContext, timestamp, eventType, eventPayload)
            // Notify the sync plugin so it can trigger auto-sync
            (syncProvider as? com.ikolvi.tracelet.sdk.location.LocationDataSink)?.insertLocation(params)
            newRowId.toString()
        } catch (e: Exception) {
            logger.error("insertLocation failed: ${e.message}")
            ""
        }
    }

    // =========================================================================
    // HTTP Sync
    // =========================================================================

    fun sync(callback: (List<Map<String, Any?>>) -> Unit) {
        val db = rustDatabase
        val state = rustEngineState
        val provider = syncProvider
        if (!isReady || db == null || state == null) {
            callback(emptyList())
            return
        }
        
        if (provider == null) {
            logger.error("Sync failed: No SyncProvider registered (is tracelet_sync installed?)")
            callback(emptyList())
            return
        }

        Thread {
            try {
                val config = state.getConfig()
                val batchSize = if (config.http.maxBatchSize > 0) config.http.maxBatchSize else 250
                val records = db.getLocationsBatch(uniffi.tracelet_core.LocationQuery(
                    startTimeMs = null,
                    endTimeMs = null,
                    limit = batchSize.toInt(),
                    offset = null,
                    orderDescending = null
                ))
                var configHttp = config.http
                val syncTelematics = configManager.getConfig().let { cfg ->
                    val http = cfg["http"] as? Map<*,*>
                    http?.get("syncTelematics") as? Boolean ?: false
                }
                
                var telematicsCleared = false
                if (syncTelematics) {
                    val telematics = db.getTelematicsEvents(250)
                    if (telematics.isNotEmpty()) {
                        val jsonArray = org.json.JSONArray()
                        telematics.forEach { event ->
                            val obj = org.json.JSONObject()
                            obj.put("id", event.id)
                            obj.put("event_type", event.eventType)
                            obj.put("severity", event.severity)
                            obj.put("latitude", event.latitude)
                            obj.put("longitude", event.longitude)
                            obj.put("timestamp", event.timestamp)
                            obj.put("synced", event.synced)
                            jsonArray.put(obj)
                        }
                        val newExtras = (configHttp.extras ?: emptyMap()).toMutableMap()
                        newExtras["__telematics"] = jsonArray.toString()
                        configHttp = configHttp.copy(extras = newExtras)
                        telematicsCleared = true
                    }
                }
                
                val hasTelematics = telematicsCleared
                if (records.isEmpty() && !hasTelematics) {
                    mainHandler.post { callback(emptyList()) }
                    return@Thread
                }
                
                val count = provider.syncBatchBlocking(configHttp, records)
                if (count > 0L || hasTelematics) {
                    if (count > 0L) {
                        val syncedCount = count.toInt()
                        val successfullySynced = records.take(syncedCount)
                        successfullySynced.lastOrNull()?.let { lastRecord ->
                            db.clearLocationsUpTo(lastRecord.id)
                            syncedLocationsRemoved.addAndGet(count)
                        }
                    }
                    if (telematicsCleared) {
                        db.clearTelematicsEvents()
                    }
                    logger.info("TraceletSdk: Synced locations ($count) and telematics ($hasTelematics)")
                }
                
                mainHandler.post {
                    callback(emptyList()) // Return empty to indicate native handled it
                }
            } catch (e: Exception) {
                logger.error("TraceletSdk: sync failed: ${e.message}")
                mainHandler.post {
                    callback(emptyList())
                }
            }
        }.start()
    }

    fun setDynamicHeaders(headers: Map<String, String>) {
        if (!isReady) return
        configManager.setDynamicHeaders(headers)
        rustEngineState?.setDynamicHeaders(HashMap(headers))
    }

    fun setRouteContext(ctx: Map<String, Any?>) {
        if (!isReady) return
        configManager.setRouteContext(ctx)
        try {
            val json = org.json.JSONObject(ctx).toString()
            rustEngineState?.setRouteContext(json)
        } catch (e: Exception) {
            logger.error("Failed to serialize routeContext: ${e.message}")
        }
    }

    fun clearRouteContext() {
        if (!isReady) return
        configManager.clearRouteContext()
        rustEngineState?.setRouteContext(null)
    }

    // =========================================================================
    // Permissions
    // =========================================================================

    fun getPermissionStatus(): AuthorizationStatus {
        return permissionManager.getAuthorizationStatus(activity)
    }

    fun getNotificationPermissionStatus(): AuthorizationStatus {
        return permissionManager.getNotificationPermissionStatus(activity)
    }

    fun getMotionPermissionStatus(): AuthorizationStatus {
        return permissionManager.getMotionPermissionStatus(activity)
    }

    /**
     * Requests location permission. Callback receives the resulting status.
     */
    fun requestPermission(callback: (AuthorizationStatus) -> Unit) {
        val act = activity
        if (act == null || pendingPermissionCallback != null) {
            callback(permissionManager.getAuthorizationStatus(activity))
            return
        }

        val status = permissionManager.getAuthorizationStatus(act)
        when (status) {
            AuthorizationStatus.NOT_DETERMINED,
            AuthorizationStatus.DENIED -> {
                pendingPermissionCallback = callback
                permissionManager.requestForegroundPermission(act)
            }
            AuthorizationStatus.WHEN_IN_USE -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    pendingPermissionCallback = callback
                    permissionManager.requestBackgroundPermission(act)
                } else {
                    callback(AuthorizationStatus.ALWAYS)
                }
            }
            else -> callback(status)
        }
    }

    /**
     * Requests notification permission (Android 13+). Callback receives status.
     */
    fun requestNotificationPermission(callback: (AuthorizationStatus) -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            callback(AuthorizationStatus.ALWAYS)
            return
        }

        val act = activity
        if (act == null || pendingPermissionCallback != null) {
            callback(permissionManager.getNotificationPermissionStatus(activity))
            return
        }

        val status = permissionManager.getNotificationPermissionStatus(act)

        if (status == AuthorizationStatus.DENIED_FOREVER || status == AuthorizationStatus.ALWAYS) {
            callback(status)
            return
        }

        pendingPermissionCallback = callback
        permissionManager.requestNotificationPermission(act)
    }

    /**
     * Requests activity recognition permission (API 29+). Callback receives status.
     */
    fun requestMotionPermission(callback: (AuthorizationStatus) -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            callback(AuthorizationStatus.ALWAYS)
            return
        }

        val act = activity
        if (act == null || pendingPermissionCallback != null) {
            callback(permissionManager.getMotionPermissionStatus(activity))
            return
        }

        val status = permissionManager.getMotionPermissionStatus(act)

        if (status == AuthorizationStatus.DENIED_FOREVER || status == AuthorizationStatus.ALWAYS) {
            callback(status)
            return
        }

        pendingPermissionCallback = callback
        permissionManager.requestActivityRecognition(act)
    }

    /**
     * Called by the host framework after the OS permission dialog closes.
     *
     * @return true if this request code belongs to Tracelet.
     */
    fun handlePermissionResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != TraceletPermissionManager.REQUEST_CODE_LOCATION &&
            requestCode != TraceletPermissionManager.REQUEST_CODE_BACKGROUND_LOCATION &&
            requestCode != TraceletPermissionManager.REQUEST_CODE_ACTIVITY_RECOGNITION &&
            requestCode != TraceletPermissionManager.REQUEST_CODE_NOTIFICATION
        ) {
            return false
        }

        val callback = pendingPermissionCallback
        
        // Always handle ACTIVITY_RECOGNITION side-effects even without a
        // Dart callback — start() auto-requests this permission and never
        // sets pendingPermissionCallback.
        if (requestCode == TraceletPermissionManager.REQUEST_CODE_ACTIVITY_RECOGNITION) {
            val act = activity
            val motionStatus = permissionManager.getMotionPermissionStatus(act)
            if (motionStatus == AuthorizationStatus.ALWAYS &&
                stateManager.enabled
            ) {
                motionDetector.start()
            }
            callback?.invoke(motionStatus)
            pendingPermissionCallback = null
            return true
        }

        if (callback == null) return false

        val act = activity
        when (requestCode) {
            TraceletPermissionManager.REQUEST_CODE_NOTIFICATION -> {
                callback(permissionManager.getNotificationPermissionStatus(act))
                pendingPermissionCallback = null
            }
            TraceletPermissionManager.REQUEST_CODE_BACKGROUND_LOCATION -> {
                if (act != null) {
                    val status = permissionManager.getStatusAfterRequest(act)
                    callback(status)
                } else {
                    callback(permissionManager.getAuthorizationStatus(null))
                }
                pendingPermissionCallback = null
            }
            else -> {
                if (act != null) {
                    callback(permissionManager.getStatusAfterRequest(act))
                } else {
                    callback(permissionManager.getAuthorizationStatus(null))
                }
                pendingPermissionCallback = null
            }
        }
        return true
    }

    fun openExactAlarmSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return false
        return try {
            val intent = Intent(
                android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                android.net.Uri.parse("package:" + context.packageName)
            )
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            logger.warning("Failed to open exact alarm settings: " + e.message)
            false
        }
    }

    fun canScheduleExactAlarms(): Boolean {
        return PeriodicLocationWorker.canScheduleExactAlarms(context)
    }

    fun isPowerSaveMode(): Boolean = permissionManager.isPowerSaveMode()

    fun isIgnoringBatteryOptimizations(): Boolean {
        return permissionManager.isIgnoringBatteryOptimizations()
    }

    fun requestSettings(action: String): Boolean {
        return when (action) {
            "ignoreOptimizations" ->
                permissionManager.requestIgnoreBatteryOptimizations(activity)
            "location" -> permissionManager.showLocationSettings(activity)
            else -> false
        }
    }

    fun showSettings(action: String): Boolean {
        return when (action) {
            "location" -> permissionManager.showLocationSettings(activity)
            "app" -> permissionManager.showAppSettings(activity)
            else -> false
        }
    }

    // =========================================================================
    // Provider & Sensors
    // =========================================================================

    fun getProviderState(): Map<String, Any?> {
        if (!isReady) return emptyMap()
        return locationEngine.buildProviderState()
    }

    fun getSensors(): Map<String, Any?> {
        if (!isReady) return emptyMap()
        return motionDetector.getSensors()
    }

    // =========================================================================
    // Logging
    // =========================================================================

    fun getLog(query: Map<String, Any?>?): String {
        if (!isReady) return ""
        return logger.getLog(query)
    }

    fun destroyLog(): Boolean {
        if (!isReady) return false
        return logger.destroyLog()
    }

    fun log(level: String, message: String): Boolean {
        if (!isReady) return false
        return logger.log(level, message)
    }

    // =========================================================================
    // Telematics
    // =========================================================================

    fun getTelematicsEvents(limit: Int): List<uniffi.tracelet_core.DbTelematicsRecord> {
        if (!isReady) return emptyList()
        return try {
            rustDatabase?.getTelematicsEvents(limit) ?: emptyList()
        } catch (e: Exception) {
            logger.error("Failed to get telematics events: ${e.message}")
            emptyList()
        }
    }

    fun getLogs(limit: Int): List<uniffi.tracelet_core.LogEntry> {
        val db = rustDatabase ?: return emptyList()
        return try {
            db.getLogs(limit)
        } catch (e: Exception) {
            logger.error("Failed to get logs: ${e.message}")
            emptyList()
        }
    }
    
    fun clearLogs() {
        val db = rustDatabase ?: return
        try {
            db.clearLogs()
        } catch (e: Exception) {
            logger.error("Failed to clear logs: ${e.message}")
        }
    }

    fun destroyTelematicsEvents(): Boolean {
        if (!isReady) return false
        return try {
            rustDatabase?.clearTelematicsEvents()
            true
        } catch (e: Exception) {
            logger.error("Failed to clear telematics events: ${e.message}")
            false
        }
    }

    fun simulateTelematicsEvent(eventType: String, severity: Double, latitude: Double, longitude: Double): Boolean {
        if (!isReady) return false
        return try {
            rustDatabase?.insertTelematicsEvent(eventType, severity, latitude, longitude)
            true
        } catch (e: Exception) {
            logger.error("Failed to simulate telematics event: ${e.message}")
            false
        }
    }

    // =========================================================================
    // Scheduling
    // =========================================================================

    fun startSchedule() {
        if (!isReady) return
        scheduleManager.start()
    }

    fun stopSchedule() {
        if (!isReady) return
        scheduleManager.stop()
    }

    // =========================================================================
    // Sound
    // =========================================================================

    fun playSound(name: String): Boolean {
        if (!::soundManager.isInitialized) return false
        return soundManager.playSound(name)
    }

    // =========================================================================
    // OEM Compatibility
    // =========================================================================

    fun getSettingsHealth(): Map<String, Any?> = OemCompat.getSettingsHealth(context)

    fun openOemSettings(label: String): Boolean {
        return OemCompat.openOemSettingsScreen(context, label)
    }

    fun showPowerManager(): Boolean {
        return OemCompat.showPowerManager(context)
    }

    // =========================================================================
    // Enterprise: Audit Trail
    // =========================================================================

    fun verifyAuditChain(): Map<String, Any?> {
        if (!::auditTrailManager.isInitialized) return emptyMap()
        return auditTrailManager.verifyChain()
    }

    fun getAuditProof(uuid: String): Map<String, Any?>? {
        if (!::auditTrailManager.isInitialized) return null
        return auditTrailManager.getProof(uuid)
    }

    // =========================================================================
    // Enterprise: Privacy Zones
    // =========================================================================

    fun addPrivacyZone(zone: Map<String, Any?>): Boolean {
        if (!::privacyZoneManager.isInitialized) return false
        return privacyZoneManager.addZone(zone)
    }

    /** Add a privacy zone using a typed [TraceletPrivacyZone] model. */
    fun addPrivacyZone(zone: com.ikolvi.tracelet.sdk.model.TraceletPrivacyZone): Boolean {
        return addPrivacyZone(zone.toMap())
    }

    fun addPrivacyZones(zones: List<Map<String, Any?>>): Boolean {
        if (!::privacyZoneManager.isInitialized) return false
        return privacyZoneManager.addZones(zones)
    }

    /** Add multiple privacy zones using typed [TraceletPrivacyZone] models. */
    fun addTypedPrivacyZones(zones: List<com.ikolvi.tracelet.sdk.model.TraceletPrivacyZone>): Boolean {
        return addPrivacyZones(zones.map { it.toMap() })
    }

    fun removePrivacyZone(id: String): Boolean {
        if (!::privacyZoneManager.isInitialized) return false
        return privacyZoneManager.removeZone(id)
    }

    fun removePrivacyZones(): Boolean {
        if (!::privacyZoneManager.isInitialized) return false
        return privacyZoneManager.removeAllZones()
    }

    fun getPrivacyZones(): List<Map<String, Any?>> {
        if (!::privacyZoneManager.isInitialized) return emptyList()
        return privacyZoneManager.getZones()
    }

    // =========================================================================
    // Enterprise: Database Encryption
    // =========================================================================

    fun isDatabaseEncrypted(): Boolean {
        if (!isReady) return false
        val state = rustEngineState ?: return false
        return state.getConfig().security.encryptDatabase
    }

    /**
     * Encrypts the database. Returns true on success.
     *
     * @throws Exception on encryption failure.
     */
    fun encryptDatabase(): Boolean {
        if (!isReady) return false
        val customKey = configManager.getEncryptionKey()
        val state = rustEngineState ?: return false
        return try {
            val currentConfig = state.getConfig()
            val newSecurity = uniffi.tracelet_core.SecurityConfig(encryptDatabase = true)
            val newConfig = uniffi.tracelet_core.EngineConfig(
                geo = currentConfig.geo,
                motion = currentConfig.motion,
                http = currentConfig.http,
                geofence = currentConfig.geofence,
                persistence = currentConfig.persistence,
                audit = currentConfig.audit,
                security = newSecurity,
                attestation = currentConfig.attestation
            )
            state.updateConfig(newConfig)
            true
        } catch (e: Exception) {
            logger.error("encryptDatabase failed: ${e.message}")
            false
        }
    }

    // =========================================================================
    // Enterprise: Device Attestation
    // =========================================================================

    fun attestDevice(callback: (Map<String, Any?>?) -> Unit) {
        if (!isReady) { callback(null); return }
        deviceAttestor.requestToken(callback)
    }

    // =========================================================================
    // Enterprise: Dead Reckoning
    // =========================================================================

    fun getDeadReckoningState(): Map<String, Any?>? {
        if (!isReady) return null
        return locationEngine.getDeadReckoningState()
    }

    // =========================================================================
    // Enterprise: Carbon Report
    // =========================================================================

    fun getCarbonReport(query: Map<String, Any?>?): Map<String, Any?> {
        if (!isReady) return mapOf(
            "totalCarbonGrams" to 0.0,
            "carbonByMode" to emptyMap<String, Double>(),
            "distanceByMode" to emptyMap<String, Double>(),
            "totalTrips" to 0,
        )
        val from = (query?.get("from") as? Number)?.toLong()
        val to = (query?.get("to") as? Number)?.toLong()
        val locations = getLocations(query)

        var totalGrams = 0.0
        val carbonByMode = mutableMapOf<String, Double>()
        val distanceByMode = mutableMapOf<String, Double>()
        var prevLat = 0.0
        var prevLng = 0.0
        var tripCount = 0
        var wasMoving = false

        for (location in locations) {
            val coords = location["coords"] as? Map<*, *>
            val lat = (coords?.get("latitude") as? Number)?.toDouble() ?: continue
            val lng = (coords?.get("longitude") as? Number)?.toDouble() ?: continue
            val act = location["activity"] as? Map<*, *>
            val actType = act?.get("type") as? String ?: "unknown"
            val isMoving = location["is_moving"] == 1 || location["is_moving"] == true

            if (!wasMoving && isMoving) tripCount++
            wasMoving = isMoving

            if (prevLat != 0.0 && prevLng != 0.0) {
                val dist = haversineDistance(prevLat, prevLng, lat, lng)
                distanceByMode[actType] = (distanceByMode[actType] ?: 0.0) + dist
                val factor = carbonFactorForMode(actType)
                val grams = dist / 1000.0 * factor
                carbonByMode[actType] = (carbonByMode[actType] ?: 0.0) + grams
                totalGrams += grams
            }
            prevLat = lat
            prevLng = lng
        }

        return mapOf(
            "totalCarbonGrams" to totalGrams,
            "carbonByMode" to carbonByMode,
            "distanceByMode" to distanceByMode,
            "totalTrips" to tripCount,
        )
    }

    // =========================================================================
    // Private — motion / schedule / heartbeat / timers
    // =========================================================================

    private fun handleMotionStateChange(isMoving: Boolean) {
        if (configManager.getMotionDetectionMode() == com.ikolvi.tracelet.sdk.model.MotionDetectionMode.SMART) {
            // In SMART mode, route the accel event through the coordinator first.
            // Only reset the speed state machine when the coordinator actually
            // decides to SWITCH_TO_CONTINUOUS (a genuine wake-up from stationary).
            // This prevents micro-vibrations from the significant motion sensor
            // from force-resetting the speed SM on every fire (infinite loop),
            // while still allowing the system to wake from stationary when the
            // coordinator determines real movement has begun.
            val action = smartMotionCoordinator.onAccelStateChange(isMoving)
            
            if (configManager.isForegroundServiceEnabled()) {
                if (isMoving) {
                    // Re-assert the wakelock on the moving transition (idempotent
                    // if already held) so CPU stays awake during active tracking.
                    LocationService.acquireWakelock(context)
                } else if (configManager.getReleaseWakelockWhenStationary() &&
                    motionDetector.getSensors()["significantMotion"] == true
                ) {
                    // Drop the wakelock when stationary to save battery — but only
                    // when the hardware TYPE_SIGNIFICANT_MOTION wake-up sensor is
                    // present, so the device can still wake from Doze on real
                    // movement. Without it we keep the wakelock (safe default) to
                    // avoid stranding the detector in the stationary state (#162).
                    LocationService.releaseWakelock(context)
                }
            }
            
            if (action == uniffi.tracelet_core.CoordinatorAction.SWITCH_TO_CONTINUOUS
                && ::speedMotionManager.isInitialized) {
                speedMotionManager.onManualPaceChange(true)
            }
            return
        }

        logger.debug("Motion state changed: isMoving=$isMoving")
        stateManager.isMoving = isMoving

        if (isMoving) {
            locationEngine.start()
            if (::soundManager.isInitialized) soundManager.playMotionChange(true)
        } else {
            locationEngine.stop()
            if (::soundManager.isInitialized) soundManager.playMotionChange(false)
        }

        val locationMap =
            locationEngine.getLastLocation()?.let { loc ->
                val map = locationEngine.enrichLocation(
                    loc, "motionchange", locationEngine.lastEffectiveSpeed
                ).toMutableMap()
                map["isMoving"] = isMoving
                map
            } ?: mapOf("isMoving" to isMoving)

        // Feed TripManager with motion state change
        val lat = (locationMap["latitude"] as? Number)?.toDouble()
            ?: ((locationMap["coords"] as? Map<*, *>)?.get("latitude") as? Number)?.toDouble()
        val lng = (locationMap["longitude"] as? Number)?.toDouble()
            ?: ((locationMap["coords"] as? Map<*, *>)?.get("longitude") as? Number)?.toDouble()
        tripManager.onMotionStateChanged(
            isMoving = isMoving,
            latitude = lat,
            longitude = lng,
            timestamp = locationMap["timestamp"],
        )

        eventSender.sendMotionChange(locationMap)
    }

    private fun handleScheduleStart() {
        stateManager.enabled = true
        if (configManager.isForegroundServiceEnabled()) {
            LocationService.start(context)
        }
        locationEngine.start()
        motionDetector.start()
        startHeartbeat()
        eventSender.sendEnabledChange(true)
    }

    private fun handleScheduleStop() {
        stateManager.enabled = false
        locationEngine.stop()
        motionDetector.stop()
        stopHeartbeat()
        if (configManager.isForegroundServiceEnabled()) {
            LocationService.stop(context)
        }
        eventSender.sendEnabledChange(false)
    }

    /** Last location persisted by a heartbeat — used to deduplicate DB writes. */
    private var lastHeartbeatLocationTime: Long = 0L

    internal fun startHeartbeat() {
        stopHeartbeat()
        val intervalSeconds = configManager.getHeartbeatInterval()
        if (intervalSeconds <= 0) return

        heartbeatRunnable = object : Runnable {
            override fun run() {
                if (!stateManager.enabled) return
                logger.debug("Heartbeat fired")
                val cached = locationEngine.getLastGpsLocation()
                if (cached != null) {
                    // Build enriched location map with UUID, battery, etc.
                    val locationData = locationEngine.enrichLocation(cached, "heartbeat").toMutableMap()

                    // Only persist to DB if this is a genuinely new GPS fix
                    // (different timestamp from the last heartbeat write).
                    // This avoids hundreds of redundant DB inserts per hour
                    // when the user is stationary and the cached location
                    // hasn't changed.
                    val fixTime = cached.time
                    if (fixTime != lastHeartbeatLocationTime) {
                        lastHeartbeatLocationTime = fixTime
                        // TODO: Port to Rust
                        locationEngine.onLocationPersisted?.invoke()
                    }

                    // Always send the event so Dart/Flutter UI stays alive
                    eventSender.sendHeartbeat(mapOf("location" to locationData))
                    logger.debug(
                        "Heartbeat: lat=${cached.latitude}, lon=${cached.longitude}, accuracy=${cached.accuracy}m")
                } else {
                    if (configManager.isDebug()) {
                        logger.debug("Heartbeat: no cached location, skipping")
                    }
                }
                mainHandler.postDelayed(this, intervalSeconds * 1000L)
            }
        }
        mainHandler.postDelayed(heartbeatRunnable!!, intervalSeconds * 1000L)
    }

    internal fun stopHeartbeat() {
        heartbeatRunnable?.let { mainHandler.removeCallbacks(it) }
        heartbeatRunnable = null
    }

    /**
     * Starts the interval-based sync timer (issue #149).
     *
     * When `HttpConfig.syncInterval` (seconds) is greater than 0 and auto-sync is
     * enabled, the SDK periodically flushes any pending locations to the configured
     * endpoint on this cadence — independent of the `autoSyncDelay` debounce that
     * fires on new inserts. A value of 0 (the default) leaves the timer disabled.
     */
    internal fun startSyncIntervalTimer() {
        stopSyncIntervalTimer()
        val intervalSeconds = configManager.getSyncInterval()
        if (intervalSeconds <= 0 || !configManager.getAutoSync()) return
        if (configManager.getHttpUrl().isNullOrEmpty()) return

        val periodMs = intervalSeconds * 1000L
        syncIntervalRunnable = object : Runnable {
            override fun run() {
                if (isReady) {
                    try {
                        sync { /* native handles upload + prune */ }
                    } catch (e: Exception) {
                        logger.error("syncInterval flush failed: ${e.message}")
                    }
                }
                mainHandler.postDelayed(this, periodMs)
            }
        }
        mainHandler.postDelayed(syncIntervalRunnable!!, periodMs)
        logger.info("syncInterval timer started (${intervalSeconds}s)")
    }

    internal fun stopSyncIntervalTimer() {
        syncIntervalRunnable?.let { mainHandler.removeCallbacks(it) }
        syncIntervalRunnable = null
    }

    // =========================================================================
    // 3.3.0 behavior engines: telematics, transport-mode classifier, impact
    // =========================================================================

    /** Instantiates the opt-in behavior engines from config. */
    private fun initBehaviorEngines() {
        telematicsEngine = if (configManager.getEnableDrivingEvents()) {
            uniffi.tracelet_core.TelematicsEngine(
                uniffi.tracelet_core.TelematicsConfig(
                    harshBrakingG = configManager.getHarshBrakingG(),
                    harshAccelerationG = configManager.getHarshAccelerationG(),
                    harshCorneringG = configManager.getHarshCorneringG(),
                    speedLimitKmh = configManager.getSpeedLimitKmh(),
                    speedingToleranceKmh = configManager.getSpeedingToleranceKmh(),
                    speedingMinDurationMs = configManager.getSpeedingMinDurationMs(),
                    minSpeedForEventsKmh = configManager.getMinSpeedForEventsKmh(),
                    eventDebounceMs = configManager.getEventDebounceMs(),
                ),
            )
        } else {
            null
        }

        transportClassifier = if (configManager.getEnableFusedClassifier()) {
            uniffi.tracelet_core.TransportModeClassifier(
                uniffi.tracelet_core.ClassifierConfig(
                    modeSwitchDwellMs = configManager.getModeSwitchDwellMs(),
                    minConfidence = configManager.getMinModeConfidence(),
                ),
            )
        } else {
            null
        }

        impactDetector = if (configManager.getEnableCrashDetection() ||
            configManager.getEnableFallDetection()
        ) {
            uniffi.tracelet_core.ImpactDetector(
                uniffi.tracelet_core.ImpactConfig(
                    enableCrash = configManager.getEnableCrashDetection(),
                    enableFall = configManager.getEnableFallDetection(),
                    crashGThreshold = configManager.getCrashGThreshold(),
                    crashMinSpeedKmh = configManager.getCrashMinSpeedKmh(),
                    fallGThreshold = configManager.getFallGThreshold(),
                    confirmWindowMs = configManager.getConfirmWindowMs(),
                    minConfidence = configManager.getMinImpactConfidence(),
                ),
            )
        } else {
            null
        }
    }

    /** Feeds an accepted location fix to the telematics engine and emits events. */
    private fun processTelematics(location: Map<String, Any?>) {
        val engine = telematicsEngine ?: return
        @Suppress("UNCHECKED_CAST")
        val coords = location["coords"] as? Map<String, Any?> ?: return
        val speed = (coords["speed"] as? Number)?.toDouble() ?: 0.0
        val heading = (coords["heading"] as? Number)?.toDouble() ?: -1.0
        val lat = (coords["latitude"] as? Number)?.toDouble() ?: 0.0
        val lng = (coords["longitude"] as? Number)?.toDouble() ?: 0.0
        lastSpeedMps = speed
        lastLat = lat
        lastLng = lng
        val events = try {
            engine.processFix(speed, heading, lat, lng, System.currentTimeMillis())
        } catch (e: Exception) {
            logger.error("telematics processFix failed: ${e.message}")
            return
        }
        for (e in events) {
            eventSender.sendDrivingEvent(
                mapOf(
                    "kind" to e.kind,
                    "severity" to e.severity,
                    "speed" to e.speed,
                    "value" to e.value,
                    "latitude" to e.latitude,
                    "longitude" to e.longitude,
                    "timestampMs" to e.timestampMs,
                ),
            )
            // Persist to the telematics DB so getTelematicsEvents() returns the
            // real history (not just Doctor-simulated events).
            try {
                rustDatabase?.insertTelematicsEvent(e.kind, e.severity, e.latitude, e.longitude)
            } catch (ex: Exception) {
                logger.error("Failed to persist driving event: ${ex.message}")
            }
        }
    }

    /** Starts the ~1 Hz accel-window loop (classifier + impact) if a consumer is active. */
    private fun startBehaviorSampling() {
        stopBehaviorSampling()
        if (transportClassifier == null && impactDetector == null) return

        accelBuffer.clear()
        accelWindowRunnable = object : Runnable {
            override fun run() {
                if (!stateManager.enabled) return
                processAccelWindow()
                mainHandler.postDelayed(this, accelWindowMs)
            }
        }
        mainHandler.postDelayed(accelWindowRunnable!!, accelWindowMs)

        if (impactDetector != null) {
            impactConfirmRunnable = object : Runnable {
                override fun run() {
                    if (!stateManager.enabled) return
                    impactDetector?.checkConfirmations(System.currentTimeMillis())?.forEach(::emitImpact)
                    mainHandler.postDelayed(this, impactConfirmPollMs)
                }
            }
            mainHandler.postDelayed(impactConfirmRunnable!!, impactConfirmPollMs)
        }
    }

    private fun stopBehaviorSampling() {
        accelWindowRunnable?.let { mainHandler.removeCallbacks(it) }
        accelWindowRunnable = null
        impactConfirmRunnable?.let { mainHandler.removeCallbacks(it) }
        impactConfirmRunnable = null
        accelBuffer.clear()
    }

    /** Snapshots the accel buffer into one window and feeds classifier + impact. */
    private fun processAccelWindow() {
        val samples: List<Double>
        synchronized(accelBuffer) {
            if (accelBuffer.isEmpty()) return
            samples = ArrayList(accelBuffer)
            accelBuffer.clear()
        }
        val now = System.currentTimeMillis()
        val window = try {
            uniffi.tracelet_core.computeAccelWindow(samples, accelWindowMs)
        } catch (e: Exception) {
            logger.error("computeAccelWindow failed: ${e.message}")
            return
        }

        transportClassifier?.let { classifier ->
            val result = classifier.classify(window, lastSpeedMps, now)
            if (result.changed) {
                eventSender.sendModeChange(
                    mapOf(
                        "mode" to result.mode.name.lowercase(),
                        "confidence" to result.confidence,
                    ),
                )
            }
        }

        impactDetector?.let { detector ->
            val onFoot = lastSpeedMps * 3.6 < configManager.getCrashMinSpeedKmh()
            val candidate = detector.onImpactWindow(
                window.peakG,
                lastSpeedMps,
                onFoot,
                lastLat,
                lastLng,
                now,
            )
            if (candidate != null) emitImpact(candidate)
        }
    }

    private fun emitImpact(e: uniffi.tracelet_core.ImpactEvent) {
        eventSender.sendImpact(
            mapOf(
                "kind" to e.kind,
                "id" to e.id,
                "confidence" to e.confidence,
                "peakG" to e.peakG,
                "speedBefore" to e.speedBefore,
                "latitude" to e.latitude,
                "longitude" to e.longitude,
                "timestampMs" to e.timestampMs,
                "confirmDeadlineMs" to e.confirmDeadlineMs,
            ),
        )
        // Persist confirmed impacts (not transient potential_* candidates, which
        // may still be cancelled) to the telematics DB for history/retrieval.
        if (e.kind == "crash" || e.kind == "fall") {
            try {
                rustDatabase?.insertTelematicsEvent(e.kind, e.confidence, e.latitude, e.longitude)
            } catch (ex: Exception) {
                logger.error("Failed to persist impact event: ${ex.message}")
            }
        }
    }

    /** Confirms a pending impact candidate (called from the Pigeon host API). */
    fun confirmImpact(id: Long): Boolean {
        val confirmed = impactDetector?.confirm(id, System.currentTimeMillis()) ?: return false
        emitImpact(confirmed)
        return true
    }

    /** Cancels a pending impact candidate (called from the Pigeon host API). */
    fun cancelImpact(id: Long): Boolean = impactDetector?.cancel(id) ?: false

    private fun startBatteryBudgetSampling() {
        stopBatteryBudgetSampling()
        val engine = batteryBudgetEngine ?: return

        batteryBudgetRunnable = object : Runnable {
            override fun run() {
                if (!stateManager.enabled) return

                // Skip sampling while charging — drain will be negative and
                // there's no reason to throttle accuracy on external power.
                if (BatteryUtils.isCharging(context)) {
                    mainHandler.postDelayed(this, BATTERY_SAMPLE_INTERVAL_MS)
                    return
                }

                val level = BatteryUtils.getBatteryLevel(context)
                val event = engine.processSample(level)
                if (event != null) {
                    // ── Apply the computed adjustments to the live config ──
                    // Without this, the engine calculates new values but the
                    // LocationEngine keeps running with the original settings.
                    configManager.setConfig(
                        mapOf(
                            "distanceFilter" to event.newDistanceFilter,
                            "desiredAccuracy" to event.newDesiredAccuracy,
                        )
                    )
                    event.newPeriodicInterval?.let { interval ->
                        configManager.setConfig(
                            mapOf("periodicLocationInterval" to interval)
                        )
                    }

                    // Restart the location engine so it picks up the new
                    // distanceFilter and accuracy from ConfigManager.
                    if (stateManager.enabled) {
                        locationEngine.stop()
                        locationEngine.start()
                    }

                    eventSender.sendBudgetAdjustment(
                        mapOf(
                            "currentBatteryDrain" to event.currentBatteryDrain,
                            "targetBudget" to event.targetBudget,
                            "newDistanceFilter" to event.newDistanceFilter,
                            "newDesiredAccuracy" to event.newDesiredAccuracy,
                            "newPeriodicInterval" to event.newPeriodicInterval,
                        )
                    )
                    logger.info(
                        "BatteryBudget adjusted: df=${event.newDistanceFilter}, " +
                        "acc=${event.newDesiredAccuracy}, drain=${event.currentBatteryDrain}%/hr"
                    )
                }
                mainHandler.postDelayed(this, BATTERY_SAMPLE_INTERVAL_MS)
            }
        }
        mainHandler.postDelayed(batteryBudgetRunnable!!, BATTERY_SAMPLE_INTERVAL_MS)
    }

    private fun stopBatteryBudgetSampling() {
        batteryBudgetRunnable?.let { mainHandler.removeCallbacks(it) }
        batteryBudgetRunnable = null
    }

    private fun startStopAfterElapsedTimer() {
        cancelStopAfterElapsedTimer()
        val minutes = configManager.getStopAfterElapsedMinutes()
        if (minutes <= 0) return

        stopAfterElapsedRunnable = Runnable {
            logger.info("stopAfterElapsedMinutes ($minutes min) — auto-stopping")
            stateManager.enabled = false
            stateManager.isMoving = false
            locationEngine.stop()
            motionDetector.stop()
            stopHeartbeat()
            if (configManager.isForegroundServiceEnabled()) {
                LocationService.stop(context)
            }
            eventSender.sendEnabledChange(false)
        }
        mainHandler.postDelayed(stopAfterElapsedRunnable!!, minutes * 60 * 1000L)
    }

    private fun cancelStopAfterElapsedTimer() {
        stopAfterElapsedRunnable?.let { mainHandler.removeCallbacks(it) }
        stopAfterElapsedRunnable = null
    }

    private fun updateBootReceiverState() {
        val enabled = configManager.getStartOnBoot() && !configManager.getStopOnTerminate()
        val componentName = ComponentName(context, BootReceiver::class.java)
        val newState = if (enabled) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        } else {
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        }
        try {
            context.packageManager.setComponentEnabledSetting(
                componentName, newState, PackageManager.DONT_KILL_APP
            )
        } catch (e: Exception) {
            logger.warning("Failed to update BootReceiver state: ${e.message}")
        }
    }

    private fun carbonFactorForMode(mode: String): Double {
        return when (mode) {
            "in_vehicle" -> 192.0
            "on_bicycle", "walking", "running", "on_foot" -> 0.0
            else -> 96.0
        }
    }

    private fun haversineDistance(
        lat1: Double, lng1: Double,
        lat2: Double, lng2: Double,
    ): Double {
        val r = 6371000.0
        val dLat = Math.toRadians(lat2 - lat1)
        val dLng = Math.toRadians(lng2 - lng1)
        val a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
            Math.sin(dLng / 2) * Math.sin(dLng / 2)
        val c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
        return r * c
    }

    // =========================================================================
    // Cleanup
    // =========================================================================

    fun destroyAll() {
        // When stopOnTerminate=false and tracking is active,
        // LocationService.onTaskRemoved() bootstraps native tracking
        // independently. Tearing down subsystems here races against that
        // bootstrap and kills background tracking — the bug reported in
        // issues #63 and #65.
        //
        // Only tear down when stopOnTerminate=true OR tracking is not active.
        val keepAlive = !configManager.getStopOnTerminate() && stateManager.enabled

        // LocationEngine — keep alive for continuous (0) and geofence (1) modes.
        // Periodic mode (2) has its own WorkManager/AlarmManager lifecycle.
        if (!(keepAlive && stateManager.trackingMode != TrackingMode.PERIODIC)) {
            locationEngine.destroy()
        }
        motionDetector.stop()

        // GeofenceManager — keep alive only in geofence mode (1).
        val keepGeofencesAlive = keepAlive && stateManager.trackingMode == TrackingMode.GEOFENCES
        if (!keepGeofencesAlive) {
            geofenceManager.destroy()
        }

        // HttpSyncManager — MUST survive for location uploads after task
        // removal. LocationService.onTaskRemoved() creates a boot-mode
        // HttpSyncManager, but the plugin's instance must not be torn down
        // before that bootstrap completes (#65).
        if (!keepAlive) {
            // TODO: Port to Rust
        // httpSyncManager.stop()
        }

        // ScheduleManager & heartbeat — keep alive for continuity.
        if (!keepAlive) {
            scheduleManager.stop()
            stopHeartbeat()
        }

        // Sound is safe to stop unconditionally — no background impact.
        if (::soundManager.isInitialized) soundManager.stop()

        // PeriodicLocationWorker — keep alive only in periodic mode (2).
        val keepPeriodicAlive = keepAlive && stateManager.trackingMode == TrackingMode.PERIODIC
        if (!keepPeriodicAlive) {
            PeriodicLocationWorker.cancel(context)
        }
        if (!keepPeriodicAlive) {
            PeriodicLocationWorker.eventSender = null
            // TODO: Port to Rust
        // PeriodicLocationWorker.httpSyncManager = null
        }
        if (!keepGeofencesAlive) {
            GeofenceBroadcastReceiver.geofenceManager = null
        }
    }

    /**
     * Synchronizes the active platform configuration stored in [configManager] 
     * to the underlying Rust Core [rustEngineState] instance.
     * 
     * This method maps every individual geolocation, motion, network, geofencing,
     * persistence, audit, database encryption, and device attestation property 
     * from the native Android ConfigManager directly into a UniFFI-exported 
     * [uniffi.tracelet_core.EngineConfig] record, ensuring the Rust core 
     * engine maintains perfect configuration parity with the platform layer.
     */
    private fun syncConfigToRustFlat() {
        val state = rustEngineState ?: return
        try {
            val newConfig = uniffi.tracelet_core.EngineConfig(
                geo = uniffi.tracelet_core.GeoConfig(
                    desiredAccuracy = configManager.getDesiredAccuracy(),
                    distanceFilter = configManager.getDistanceFilter(),
                    stationaryRadius = configManager.getStationaryRadius(),
                    locationTimeout = configManager.getLocationTimeout(),
                    disableElasticity = configManager.getDisableElasticity(),
                    elasticityMultiplier = configManager.getElasticityMultiplier(),
                    enableAdaptiveMode = configManager.getEnableAdaptiveMode(),
                    enableTimestampMeta = configManager.getEnableTimestampMeta(),
                    enableSparseUpdates = configManager.getEnableSparseUpdates(),
                    sparseDistanceThreshold = configManager.getSparseDistanceThreshold(),
                    stopAfterElapsedMinutes = configManager.getStopAfterElapsedMinutes(),
                    maxMonitoredGeofences = configManager.getMaxMonitoredGeofences(),
                    periodicLocationInterval = configManager.getPeriodicLocationInterval(),
                    periodicDesiredAccuracy = configManager.getPeriodicDesiredAccuracy(),
                    sparseMaxIdleSeconds = configManager.getSparseMaxIdleSeconds(),
                    batteryBudgetPerHour = configManager.getBatteryBudgetPerHour(),
                    enableDeadReckoning = configManager.getEnableDeadReckoning(),
                    deadReckoningActivationDelay = configManager.getDeadReckoningActivationDelay(),
                    deadReckoningMaxDuration = configManager.getDeadReckoningMaxDuration(),
                    resolveAddress = configManager.getResolveAddress()
                ),
                motion = uniffi.tracelet_core.MotionConfig(
                    stopTimeout = configManager.getStopTimeout(),
                    motionTriggerDelay = configManager.getMotionTriggerDelay(),
                    disableMotionActivityUpdates = configManager.isMotionActivityUpdatesDisabled(),
                    disableStopDetection = configManager.getDisableStopDetection(),
                    shakeThreshold = configManager.getShakeThreshold(),
                    isMoving = configManager.getIsMoving(),
                    activityRecognitionInterval = configManager.getActivityRecognitionInterval(),
                    minimumActivityRecognitionConfidence = configManager.getMinimumActivityRecognitionConfidence(),
                    stopDetectionDelay = configManager.getStopDetectionDelay(),
                    stopOnStationary = configManager.getStopOnStationary(),
                    stationaryRadius = configManager.getStationaryRadius(),
                    useSignificantChangesOnly = false,
                    stillThreshold = configManager.getStillThreshold(),
                    stillSampleCount = configManager.getStillSampleCount(),
                    motionDetectionMode = configManager.getMotionDetectionMode().value,
                    speedMovingThreshold = configManager.getSpeedMovingThreshold(),
                    speedStationaryDelay = configManager.getSpeedStationaryDelay(),
                    stationaryTrackingMode = configManager.getStationaryTrackingMode().value,
                    stationaryPeriodicInterval = configManager.getStationaryPeriodicInterval(),
                    stationaryPeriodicAccuracy = configManager.getStationaryPeriodicAccuracy(),
                    speedWakeConfirmCount = configManager.getSpeedWakeConfirmCount()
                ),
                http = uniffi.tracelet_core.HttpConfig(
                    url = configManager.getHttpUrl(),
                    method = configManager.getHttpMethod(),
                    headers = HashMap(configManager.getMergedHttpHeaders()),
                    batchSync = configManager.getBatchSync(),
                    maxBatchSize = configManager.getMaxBatchSize(),
                    autoSync = configManager.getAutoSync(),
                    maxRetries = configManager.getMaxRetries(),
                    retryBackoffBase = configManager.getRetryBackoffBase(),
                    retryBackoffCap = configManager.getRetryBackoffCap(),
                    autoSyncDelay = configManager.getAutoSyncDelay(),
                    sslPinningCertificates = configManager.getSslPinningCertificates().takeIf { it.isNotEmpty() },
                    sslPinningFingerprints = configManager.getSslPinningFingerprints().takeIf { it.isNotEmpty() },
                    httpRootProperty = configManager.getHttpRootProperty(),
                    params = HashMap(configManager.getHttpParams().filterValues { it != null }.mapValues { it.value.toString() }),
                    extras = HashMap(configManager.getHttpExtras().filterValues { it != null }.mapValues { it.value.toString() }),
                    disableAutoSyncOnCellular = configManager.getDisableAutoSyncOnCellular(),
                    enableDeltaCompression = configManager.getEnableDeltaCompression(),
                    deltaCoordinatePrecision = configManager.getDeltaCoordinatePrecision(),
                    locationsOrderDirection = configManager.getLocationsOrderDirection()
                ),
                geofence = uniffi.tracelet_core.GeofenceConfig(
                    geofenceInitialTrigger = configManager.getGeofenceInitialTrigger(),
                    geofenceInitialTriggerEntry = configManager.getGeofenceInitialTriggerEntry(),
                    geofenceProximityRadius = configManager.getGeofenceProximityRadius()
                ),
                persistence = uniffi.tracelet_core.PersistenceConfig(
                    maxDaysToPersist = configManager.getMaxDaysToPersist(),
                    maxRecordsToPersist = configManager.getMaxRecordsToPersist()
                ),
                audit = uniffi.tracelet_core.AuditConfig(
                    enabled = configManager.getAuditEnabled()
                ),
                security = uniffi.tracelet_core.SecurityConfig(
                    encryptDatabase = configManager.getEncryptDatabase()
                ),
                attestation = uniffi.tracelet_core.AttestationConfig(
                    enabled = configManager.getAttestationEnabled()
                )
            )
            state.updateConfig(newConfig)
            logger.info("Successfully synchronized ConfigManager state to Rust Core.")
        } catch (e: Exception) {
            logger.error("Failed to sync config to Rust Core: ${e.message}")
        }
    }
}
