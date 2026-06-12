import Foundation
import CoreLocation
#if canImport(UIKit)
import UIKit
#endif

/// Main entry point for the Tracelet Background Geolocation SDK.
///
/// Usage (Swift):
/// ```swift
/// let sdk = TraceletSdk.shared
/// sdk.delegate = self
/// sdk.ready(config: ["geo": ["distanceFilter": 10]])
/// sdk.start()
/// ```
///
/// Usage (Objective-C):
/// ```objc
/// TraceletSdk *sdk = [TraceletSdk shared];
/// sdk.delegate = self;
/// [sdk readyWithConfig:@{@"geo": @{@"distanceFilter": @10}}];
/// [sdk start];
/// ```
///
/// This class orchestrates all subsystems: location engine, motion detector,
/// geofence manager, HTTP sync, database, and scheduling. It is
/// framework-agnostic and can be used from Flutter, React Native, Capacitor,
/// or native iOS apps.
///
/// The API surface mirrors the Dart `Tracelet` class so developers switching
/// between Flutter and native iOS have a familiar interface.
public protocol SyncProvider {
    func syncBatchBlocking(config: HttpConfig, records: [DbLocationRecord]) throws -> UInt32
}

public final class TraceletSdk {

    // MARK: - Singleton

    /// The shared singleton instance.
    public static let shared = TraceletSdk()

    public var syncProvider: SyncProvider? = nil {
        didSet {
            if let sink = syncProvider as? LocationDataSink {
                locationEngine?.registerSink(sink)
            }
        }
    }

    public var dartSyncInterceptor: DartSyncInterceptor? = nil

    // MARK: - Delegate

    /// Delegate that receives all tracking events (location, motion, geofence, etc.).
    ///
    /// Set this before calling ``ready(config:)`` to receive all events.
    public weak var delegate: TraceletDelegate? {
        didSet { delegateEventSender.delegate = delegate }
    }

    // MARK: - Subsystems

    public private(set) var configManager: ConfigManager!
    public private(set) var stateManager: StateManager!
    
    public private(set) var locationEngine: LocationEngine!
    public private(set) var motionDetector: MotionDetector!
    public private(set) var speedMotionManager: SpeedMotionManager?
    public private(set) var geofenceManager: GeofenceManager!
    public private(set) var smartMotionCoordinator: TraceletSmartMotionCoordinator!
    public private(set) var scheduleManager: ScheduleManager!
    public private(set) var logger: TraceletLogger!
    public private(set) var soundManager: SoundManager!
    public private(set) var permissionManager: TraceletPermissionManager = TraceletPermissionManager()
    public private(set) var auditTrailManager: AuditTrailManager!
    public private(set) var privacyZoneManager: PrivacyZoneManager!
    public private(set) var deviceAttestor: DeviceAttestor!
    public private(set) var preventSuspendManager: PreventSuspendManager!
    public private(set) var backgroundActivitySessionManager: BackgroundActivitySessionManager!
    public private(set) var serviceSessionManager: ServiceSessionManager!
    public private(set) var periodicRefreshScheduler: PeriodicRefreshScheduler!

    // MARK: - Rust Core subsystems
    public private(set) var rustDatabase: DatabaseManager?
    public private(set) var rustEngineState: EngineState?
    public private(set) var rustPluginEventDispatcher: EventDispatcher?

    private let delegateEventSender = DelegateEventSender()
    private var eventSender: TraceletEventSending
    private var heartbeatTimer: Timer?
    private var stopAfterElapsedTimer: Timer?
    private var isReady = false

    // Algorithms
    public private(set) var tripManager: TraceletTripManager!
    private var batteryBudgetEngine: TraceletBatteryBudgetEngine?
    private var batteryBudgetTimer: Timer?

    /// Battery budget sampling interval: 5 minutes.
    private static let batterySampleInterval: TimeInterval = 5 * 60

    /// Whether ``ready(config:)`` has been called.
    public var isReadyState: Bool { isReady }

    private init() {
        eventSender = delegateEventSender
        delegateEventSender.sdk = self
    }

    // MARK: - Event Sender (for framework bridges)

    /// Returns the internal ``TraceletEventSending`` for use by framework bridges.
    ///
    /// Flutter, React Native, and other bridges provide their own event sender
    /// implementation via this accessor, bypassing the delegate pattern.
    public func getEventSender() -> TraceletEventSending {
        return eventSender
    }

    /// Replace the default delegate-based event sender with a custom one.
    ///
    /// Framework bridges (Flutter, React Native) call this **before** ``ready(config:)``
    /// to inject their own event-channel implementation.
    ///
    /// - Parameter sender: A ``TraceletEventSending`` implementation.
    public func setEventSender(_ sender: TraceletEventSending) {
        precondition(!isReady, "setEventSender() must be called before ready()")
        self.eventSender = sender
    }

    /// Sets a headless dispatcher for background event delivery.
    ///
    /// Used by framework bridges (Flutter, React Native) to forward events
    /// to their respective background runtimes.
    public func setHeadlessDispatcher(_ dispatcher: HeadlessDispatching?) {
        delegateEventSender.headlessDispatcher = dispatcher
    }

    public var isTracking: Bool {
        return locationEngine.isTracking || stateManager.enabled
    }

    // =========================================================================
    // MARK: - Lifecycle
    // =========================================================================

    /// Initialize all subsystems with a typed configuration.
    ///
    /// Type-safe overload matching the Dart API:
    ///
    /// ```swift
    /// sdk.ready(config: TraceletConfig(
    ///     geo: .init(desiredAccuracy: .high, distanceFilter: 10.0),
    ///     app: .init(stopOnTerminate: false, startOnBoot: true)
    /// ))
    /// ```
    ///
    /// - Parameter config: Typed configuration.
    /// - Returns: Current state as a dictionary.
    @discardableResult
    public func ready(config: TraceletConfig) -> [String: Any] {
        return ready(config: config.toMap())
    }

    /// Initialize the SDK using an Objective-C compatible config wrapper.
    ///
    /// - Parameter objcConfig: ``TraceletConfigObjC`` instance.
    /// - Returns: Current state as a dictionary.
    @objc(readyWithObjCConfig:)
    @discardableResult
    public func ready(objcConfig: TraceletConfigObjC) -> [String: Any] {
        return ready(config: objcConfig.toMap())
    }

    /// Initialize all subsystems with the given configuration.
    ///
    /// **Must be called before any other method.** Returns the current state.
    ///
    /// - Parameter config: Configuration dictionary matching Dart `Config.toMap()` format.
    /// - Returns: Current state as a dictionary.
    public func requestStateFlush() {
        var providerState = locationEngine.buildProviderState()
        providerState["event"] = "providerchange"
        eventSender.sendProviderChange(providerState)
        
        let isMoving = stateManager.isMoving
        let locationMap = locationEngine.getLastGpsLocation().map { locationEngine.buildLocationMap($0) }
        var motionMap = locationMap ?? [:]
        motionMap["isMoving"] = isMoving
        eventSender.sendMotionChange(motionMap)
    }

    @objc private func handleWillEnterForeground() {
        NSLog("Tracelet: App moving to FOREGROUND — requesting state flush to Dart")
        requestStateFlush()
    }

    @discardableResult
    public func ready(config: [String: Any]) -> [String: Any] {
        initialize()  // no-op if already initialized

        let merged = configManager.setConfig(config)

        if config["encryptDatabase"] as? Bool == true {
            let key = config["encryptionKey"] as? String ?? ""
            rustDatabase?.setEncryptionKey(key: key)
        } else {
            rustDatabase?.setEncryptionKey(key: "")
        }

        if configManager.isDebug() { soundManager.start() }
        logger.pruneOldLogs()

        // [Enterprise] Auto-encrypt database if configured.
        if configManager.getEncryptDatabase(), let state = rustEngineState {
            do {
                let currentConfig = state.getConfig()
                let newSecurity = SecurityConfig(encryptDatabase: true)
                let newConfig = EngineConfig(
                    geo: currentConfig.geo,
                    motion: currentConfig.motion,
                    http: currentConfig.http,
                    geofence: currentConfig.geofence,
                    persistence: currentConfig.persistence,
                    audit: currentConfig.audit,
                    security: newSecurity,
                    attestation: currentConfig.attestation
                )
                try state.updateConfig(newConfig: newConfig)
                // DB encryption is now entirely managed by rustDatabase directly.
            } catch {
                NSLog("Auto-encrypt database failed: \(error)")
            }
        }

        // [Enterprise] Start attestation refresh if configured.
        if configManager.getAttestationEnabled() {
            deviceAttestor.startRefresh(intervalSeconds: configManager.getAttestationRefreshInterval())
        }

        // [Enterprise] Fetch remote config if configured.
        // TODO: Port fetchRemoteConfig to Rust Core or standalone networking
        if let remoteUrl = configManager.getRemoteConfigUrl() {
            // Port to Rust Networking
        }

        // Initialize battery budget engine from config
        let budgetPerHour = configManager.getBatteryBudgetPerHour()
        if budgetPerHour > 0 {
            batteryBudgetEngine = TraceletBatteryBudgetEngine(
                targetBudgetPerHour: budgetPerHour,
                initialDistanceFilter: configManager.getDistanceFilter(),
                initialAccuracyIndex: configManager.getDesiredAccuracy()
            )
        } else {
            batteryBudgetEngine = nil
        }

        isReady = true
        syncConfigToRustFlat()
        checkSyncProvider()

        if stateManager.enabled {
            switch stateManager.trackingMode {
            case .continuous:
                NSLog("[Tracelet] ready: Resuming continuous tracking")
                start(isResume: true)
            case .periodic:
                NSLog("[Tracelet] ready: Resuming periodic tracking")
                startPeriodic()
            case .geofences:
                NSLog("[Tracelet] ready: Resuming geofence tracking")
                startGeofences()
            }
        }

        logger.info("ready() called")
        return stateManager.toMap(merged)
    }

    /// Start continuous location tracking.
    ///
    /// - Returns: Updated state as a dictionary.
    @discardableResult
    public func start(isResume: Bool = false) -> [String: Any] {
        precondition(isReady, "TraceletSdk.ready() must be called before start()")

        let wasTracking = locationEngine.isTracking

        // A manual start() while tracking is ALREADY active is a no-op. Previously
        // it reset isMoving to the configured default (isMoving=false) and forced
        // changePace(false), so a second start() slammed the device into the
        // STATIONARY state even while moving (and iOS could get stuck there).
        // Calling start() again must not disturb the live motion state — use
        // changePace() to change pace.
        if !isResume && wasTracking {
            stateManager.enabled = true
            stateManager.trackingMode = .continuous
            return stateManager.toMap(configManager.getConfig())
        }

        stateManager.enabled = true
        stateManager.trackingMode = .continuous
        if !isResume {
            stateManager.isMoving = configManager.getIsMoving()
        }

        smartMotionCoordinator.syncCurrentMode()

        let shouldForceMoving = stateManager.isMoving

        // Stop any periodic tracking before switching to continuous mode.
        locationEngine.stopPeriodic()
        periodicRefreshScheduler.stop()

        // Wire proximity-based geofence monitoring + trip waypoints.
        locationEngine.onLocationUpdate = { [weak self] lat, lng in
            self?.geofenceManager.updateProximity(latitude: lat, longitude: lng)
            if self?.configManager.getGeofenceModeHighAccuracy() == true {
                self?.geofenceManager.evaluateHighAccuracyProximity(latitude: lat, longitude: lng)
            }
            self?.tripManager.onLocationReceived(
                latitude: lat,
                longitude: lng,
                timestamp: ISO8601DateFormatter().string(from: Date())
            )
        }

        let motionMode = configManager.getMotionDetectionMode()
        
        if motionMode == .speed {
            startSpeedMotionManager(forceMoving: shouldForceMoving)
        } else if motionMode == .smart {
            startSpeedMotionManager(forceMoving: shouldForceMoving)
            motionDetector.start()
        } else {
            motionDetector.start()
        }

        if stateManager.isMoving {
            locationEngine.start()
            backgroundActivitySessionManager.start()
        } else {
            _ = changePace(false)
        }

        startHeartbeat()
        startStopAfterElapsedTimer()
        startBatteryBudgetSampling()
        preventSuspendManager.start()
        serviceSessionManager.start()

        eventSender.sendEnabledChange(true)
        logger.info("start() — tracking started")

        return stateManager.toMap(configManager.getConfig())
    }

    /// Stop all tracking.
    ///
    /// - Returns: Updated state as a dictionary.
    @discardableResult
    public func stop() -> [String: Any] {
        BackgroundTaskHelper.shared.run("stop") { [self] in
            stateManager.enabled = false
            stateManager.isMoving = false

            locationEngine.stop()
            locationEngine.speedSink = nil
            motionDetector.stop()
            speedMotionManager?.stop()
            speedMotionManager = nil
            geofenceManager.destroy()
            stopHeartbeat()
            cancelStopAfterElapsedTimer()
            locationEngine.stopPeriodic()
            periodicRefreshScheduler.stop()
            preventSuspendManager.stop()
            backgroundActivitySessionManager.stop()
            serviceSessionManager.stop()

            scheduleManager.stop()
            tripManager.reset()
            stopBatteryBudgetSampling()
            batteryBudgetEngine?.reset()
            eventSender.sendEnabledChange(false)
            logger.info("stop() — tracking stopped")
        }

        return stateManager.toMap(configManager.getConfig())
    }

    /// Start geofence-only tracking mode.
    ///
    /// The SDK will only monitor geofences without continuous location
    /// tracking, saving significant battery.
    ///
    /// - Returns: Updated state as a dictionary.
    @discardableResult
    public func startGeofences() -> [String: Any] {
        precondition(isReady, "TraceletSdk.ready() must be called before startGeofences()")

        stateManager.enabled = true
        stateManager.trackingMode = .geofences

        locationEngine.speedSink = nil
        locationEngine.stop()
        motionDetector.stop()
        speedMotionManager?.stop()
        speedMotionManager = nil

        geofenceManager.reRegisterAll()

        // Wire proximity-based geofence monitoring.
        locationEngine.onLocationUpdate = { [weak self] lat, lng in
            self?.geofenceManager.updateProximity(latitude: lat, longitude: lng)
            if self?.configManager.getGeofenceModeHighAccuracy() == true {
                self?.geofenceManager.evaluateHighAccuracyProximity(latitude: lat, longitude: lng)
            }
        }

        // geofenceModeHighAccuracy: start GPS for in-app transition detection.
        if configManager.getGeofenceModeHighAccuracy() {
            geofenceManager.clearHighAccuracyState()
            locationEngine.start()

            preventSuspendManager.start()
            backgroundActivitySessionManager.start()
            serviceSessionManager.start()
        } else {
            locationEngine.start()

            if configManager.getPreventSuspend() {
                preventSuspendManager.start()
            } else {
                preventSuspendManager.stop()
            }

            // Explicitly stop CLBackgroundActivitySession if switching from High to Low
            backgroundActivitySessionManager.stop()

            // Do NOT start CLBackgroundActivitySession for standard geofence mode.
            // It causes a persistent blue location indicator in the status bar.
            // iOS 18+: Preserve authorization across suspension/termination.
            startServiceSessionForCurrentAuth()
        }

        eventSender.sendEnabledChange(true)
        logger.info("startGeofences() — geofence-only mode")

        return stateManager.toMap(configManager.getConfig())
    }

    /// Start periodic one-shot location tracking mode.
    ///
    /// Instead of continuous GPS updates, this mode wakes at the configured
    /// interval, performs a single location fix, dispatches the result, and
    /// immediately turns the location provider off.
    ///
    /// - Returns: Updated state as a dictionary.
    @discardableResult
    public func startPeriodic() -> [String: Any] {
        precondition(isReady, "TraceletSdk.ready() must be called before startPeriodic()")

        // Stop continuous tracking before switching to periodic mode.
        locationEngine.speedSink = nil
        locationEngine.stop()
        motionDetector.stop()
        speedMotionManager?.stop()
        speedMotionManager = nil

        stateManager.enabled = true
        stateManager.trackingMode = .periodic
        stateManager.isMoving = false

        locationEngine.startPeriodic()

        // Wire proximity-based geofence monitoring.
        locationEngine.onLocationUpdate = { [weak self] lat, lng in
            self?.geofenceManager.updateProximity(latitude: lat, longitude: lng)
            if self?.configManager.getGeofenceModeHighAccuracy() == true {
                self?.geofenceManager.evaluateHighAccuracyProximity(latitude: lat, longitude: lng)
            }
        }

        startStopAfterElapsedTimer()

        // Schedule BGAppRefreshTask as a supplementary wake-up mechanism.
        let interval = TimeInterval(configManager.getPeriodicLocationInterval())
        periodicRefreshScheduler.start(interval: interval)

        // Only start preventSuspend in periodic mode when explicitly enabled.
        if configManager.getPreventSuspend() {
            preventSuspendManager.start()
        }

        // Do NOT start CLBackgroundActivitySession for periodic mode.
        // It causes a persistent blue location indicator in the status bar,
        // which is misleading — periodic mode only uses GPS briefly during
        // each fix. Background execution is already handled by:
        //   - BackgroundTaskHelper around each periodic fix
        //   - Temporarily enabling allowsBackgroundLocationUpdates per fix
        //   - significantLocationChanges as a wake-up mechanism
        //   - BGAppRefreshTask via PeriodicRefreshScheduler

        // iOS 18+: Preserve authorization across suspension/termination.
        // This does NOT show the location indicator.
        startServiceSessionForCurrentAuth()

        eventSender.sendEnabledChange(true)
        logger.info("startPeriodic() — periodic tracking started")

        return stateManager.toMap(configManager.getConfig())
    }

    /// Get the current SDK state.
    ///
    /// - Returns: State as a dictionary. Returns a default disabled state if
    ///   ``ready(config:)`` has not been called yet.
    public func getState() -> [String: Any] {
        return stateManager.toMap(configManager.getConfig())
    }

    /// Update the SDK configuration.
    ///
    /// - Parameter config: Configuration dictionary.
    /// - Returns: Updated state as a dictionary.
    /// Update the SDK configuration using a typed ``TraceletConfig``.
    ///
    /// - Parameter config: Typed configuration struct.
    /// - Returns: Updated state as a dictionary.
    @discardableResult
    public func setConfig(_ config: TraceletConfig) -> [String: Any] {
        return setConfig(config.toMap())
    }

    /// Update the SDK configuration using an Objective-C compatible config wrapper.
    ///
    /// - Parameter objcConfig: ``TraceletConfigObjC`` instance.
    /// - Returns: Updated state as a dictionary.
    @objc(setConfigWithObjC:)
    @discardableResult
    public func setConfig(objcConfig: TraceletConfigObjC) -> [String: Any] {
        return setConfig(objcConfig.toMap())
    }

    @discardableResult
    public func setConfig(_ config: [String: Any]) -> [String: Any] {
        guard isReady else { return getState() }
        let wasPreventing = configManager.getPreventSuspend()
        configManager.setConfig(config)
        
        if config["encryptDatabase"] as? Bool == true {
            let key = config["encryptionKey"] as? String ?? ""
            rustDatabase?.setEncryptionKey(key: key)
        } else {
            rustDatabase?.setEncryptionKey(key: "")
        }

        if stateManager.enabled {
            if stateManager.trackingMode == .periodic {
                // Periodic mode — restart periodic tracking.
                locationEngine.stopPeriodic()
                locationEngine.startPeriodic()
                periodicRefreshScheduler.stop()
                periodicRefreshScheduler.start(
                    interval: TimeInterval(configManager.getPeriodicLocationInterval())
                )
            } else {
                locationEngine.stop()
                locationEngine.start()
            }

            // Toggle preventSuspend if it changed mid-session.
            let nowPreventing = configManager.getPreventSuspend()
            if nowPreventing && !wasPreventing {
                preventSuspendManager.start()
            } else if !nowPreventing && wasPreventing {
                preventSuspendManager.stop()
            }
        }

        syncConfigToRustFlat()
        checkSyncProvider()
        return stateManager.toMap(configManager.getConfig())
    }

    private func checkSyncProvider() {
        let url = configManager.getUrl()
        if !url.isEmpty, syncProvider == nil {
            NSLog("⚠️ WARNING [Tracelet]: HTTP sync URL is configured (\"\(url)\"), but no SyncProvider is registered. Location synchronization will NOT work without the tracelet_sync package. Please ensure tracelet_sync is installed and initialized.")
        }
    }

    /// Reset all state and optionally apply new configuration.
    ///
    /// - Parameter config: Optional new configuration to apply after reset.
    /// - Returns: Updated state as a dictionary.
    @discardableResult
    public func reset(_ config: [String: Any]? = nil) -> [String: Any] {
        guard isReady else { return getState() }
        BackgroundTaskHelper.shared.run("reset") { [self] in
            locationEngine.destroy()
            locationEngine.onLocationUpdate = nil
            locationEngine.speedSink = nil
            motionDetector.stop()
            speedMotionManager?.stop()
            speedMotionManager = nil
            stopHeartbeat()
            cancelStopAfterElapsedTimer()
            periodicRefreshScheduler.stop()

            let keepGeofencesAlive = !configManager.getStopOnTerminate()
                && stateManager.enabled
                && stateManager.trackingMode == .geofences
            if !keepGeofencesAlive {
                geofenceManager.destroy()
            }

            preventSuspendManager.stop()
            backgroundActivitySessionManager.stop()
            serviceSessionManager.stop()

            stateManager.reset()
            configManager.reset(config)
            tripManager.reset()
            batteryBudgetEngine?.reset()
            auditTrailManager?.reset()
            isReady = false
            logger.info("reset() — all subsystems reset")
        }

        return stateManager.toMap(configManager.getConfig())
    }

    // =========================================================================
    // MARK: - Location
    // =========================================================================

    /// Get the current position as a one-shot request.
    ///
    /// - Parameters:
    ///   - options: Options dictionary (desiredAccuracy, timeout, maximumAge, persist, samples, extras).
    ///   - completion: Called with the location dictionary, or nil on failure.
    public func getCurrentPosition(options: [String: Any] = [:],
                                   completion: @escaping ([String: Any]?) -> Void) {
        guard isReady else { completion(nil); return }
        locationEngine.getCurrentPosition(options: options, callback: completion)
    }

    /// Get the last known location without requesting a new fix.
    ///
    /// - Parameter options: Options dictionary (persist, extras).
    /// - Returns: Location dictionary, or nil if no cached location is available.
    public func getLastKnownLocation(options: [String: Any] = [:]) -> [String: Any]? {
        guard isReady else { return nil }
        var result: [String: Any]?
        locationEngine.getLastKnownLocation(options: options) { result = $0 }
        return result
    }

    /// Start watching position at a high-frequency interval.
    ///
    /// - Parameter options: Options dictionary (interval, desiredAccuracy, extras).
    /// - Returns: Watch ID that can be used to stop the watch via ``stopWatchPosition(_:)``.
    public func watchPosition(options: [String: Any] = [:]) -> Int {
        guard isReady else { return -1 }
        return locationEngine.watchPosition(options: options)
    }

    /// Stop a watch started by ``watchPosition(options:)``.
    ///
    /// - Parameter watchId: The watch ID returned by ``watchPosition(options:)``.
    /// - Returns: `true` if the watcher was found and stopped.
    @discardableResult
    public func stopWatchPosition(_ watchId: Int) -> Bool {
        guard isReady else { return false }
        return locationEngine.stopWatchPosition(watchId)
    }

    /// Toggle the motion state.
    ///
    /// `isMoving: true` forces moving mode (high-frequency updates).
    /// `isMoving: false` forces stationary mode.
    ///
    /// - Parameter isMoving: The desired motion state.
    /// - Returns: `true` if the pace was changed.
    @discardableResult
    public func changePace(_ isMoving: Bool) -> Bool {
        guard isReady else { return false }
        
        let motionMode = configManager.getMotionDetectionMode()
        if motionMode == .speed {
            speedMotionManager?.onManualPaceChange(isMoving: isMoving)
            return true
        } else if motionMode == .smart {
            speedMotionManager?.onManualPaceChange(isMoving: isMoving)
            motionDetector.onManualPaceChange(isMoving)
            smartMotionCoordinator.onManualPaceChange(isMoving: isMoving)
            return true
        } else {
            let result = locationEngine.changePace(isMoving)
            motionDetector.onManualPaceChange(isMoving)
            return result
        }
    }

    /// Get the current odometer value in meters.
    public func getOdometer() -> Double {
        guard isReady else { return 0.0 }
        return locationEngine.getOdometer()
    }

    /// Set the odometer value.
    ///
    /// - Parameter value: New odometer value in meters.
    /// - Returns: Location dictionary at the reset point.
    @discardableResult
    public func setOdometer(_ value: Double) -> [String: Any] {
        guard isReady else { return [:] }
        return locationEngine.setOdometer(value)
    }

    // =========================================================================
    // MARK: - Geofencing
    // =========================================================================

    /// Add a single geofence to the monitoring list.
    ///
    /// - Parameter geofence: Geofence dictionary (identifier, latitude, longitude, radius, etc.).
    /// - Returns: `true` if the geofence was added.
    @discardableResult
    public func addGeofence(_ geofence: [String: Any]) -> Bool {
        guard isReady else { return false }
        return geofenceManager.addGeofence(geofence)
    }

    /// Add a single geofence using a typed ``TraceletGeofence`` model.
    ///
    /// - Parameter geofence: Typed geofence model.
    /// - Returns: `true` if the geofence was added.
    @discardableResult
    public func addGeofence(_ geofence: TraceletGeofence) -> Bool {
        return addGeofence(geofence.toMap() as [String: Any])
    }

    /// Add multiple geofences at once.
    ///
    /// - Parameter geofences: Array of geofence dictionaries.
    /// - Returns: `true` if all geofences were added.
    @discardableResult
    public func addGeofences(_ geofences: [[String: Any]]) -> Bool {
        guard isReady else { return false }
        return geofenceManager.addGeofences(geofences)
    }

    /// Add multiple geofences using typed ``TraceletGeofence`` models.
    ///
    /// - Parameter geofences: Array of typed geofence models.
    /// - Returns: `true` if all geofences were added.
    @discardableResult
    public func addGeofences(_ geofences: [TraceletGeofence]) -> Bool {
        return addGeofences(geofences.map { $0.toMap() as [String: Any] })
    }

    /// Remove a geofence by its identifier.
    ///
    /// - Parameter identifier: The geofence identifier.
    /// - Returns: `true` if the geofence was removed.
    @discardableResult
    public func removeGeofence(_ identifier: String) -> Bool {
        guard isReady else { return false }
        return geofenceManager.removeGeofence(identifier)
    }

    /// Remove all geofences.
    ///
    /// - Returns: `true` if geofences were removed.
    @discardableResult
    public func removeGeofences() -> Bool {
        guard isReady else { return false }
        return geofenceManager.removeGeofences()
    }

    /// Get all registered geofences.
    ///
    /// - Returns: Array of geofence dictionaries.
    public func getGeofences() -> [[String: Any]] {
        return geofenceManager.getGeofences()
    }

    /// Get a single geofence by identifier.
    ///
    /// - Parameter identifier: The geofence identifier.
    /// - Returns: Geofence dictionary, or nil if not found.
    public func getGeofence(_ identifier: String) -> [String: Any]? {
        return geofenceManager.getGeofence(identifier)
    }

    /// Check whether a geofence with the given identifier exists.
    ///
    /// - Parameter identifier: The geofence identifier.
    /// - Returns: `true` if the geofence exists.
    public func geofenceExists(_ identifier: String) -> Bool {
        return geofenceManager.geofenceExists(identifier)
    }

    // =========================================================================
    // MARK: - Persistence
    // =========================================================================

    /// Get stored locations from the local database.
    ///
    /// - Parameter query: Optional query parameters (limit, offset, order, start, end).
    /// - Returns: Array of location dictionaries.
    public func getLocations(query: [String: Any]? = nil) -> [[String: Any]] {
        guard isReady else { return [] }
        guard let db = rustDatabase else { return [] }
        
        let startTimeMs = (query?["start"] as? NSNumber)?.int64Value ?? (query?["from"] as? NSNumber)?.int64Value
        let endTimeMs = (query?["end"] as? NSNumber)?.int64Value ?? (query?["to"] as? NSNumber)?.int64Value
        let limit = (query?["limit"] as? NSNumber)?.int32Value
        let offset = (query?["offset"] as? NSNumber)?.int32Value
        
        var orderDescending: Bool? = nil
        if let order = (query?["order"] as? NSNumber)?.intValue {
            orderDescending = (order == 1)
        }
        
        let rustQuery = LocationQuery(
            startTimeMs: startTimeMs,
            endTimeMs: endTimeMs,
            limit: limit,
            offset: offset,
            orderDescending: orderDescending
        )
        
        do {
            let records = try db.getLocationsBatch(query: rustQuery)
            return records.map { mapRecordToLocation($0) }
        } catch {
            NSLog("getLocations failed: \(error)")
            return []
        }
    }

    /// Canonical mapping of a persisted `DbLocationRecord` into the nested
    /// location schema used by `onLocation` and `getLocations`.
    ///
    /// Single source of truth so every consumer (getLocations + the sync
    /// interceptor sink) emits an identical shape and restores
    /// `route_context` / audit-hash metadata (Issue #126). See `LocationMapper`.
    public func mapRecordToLocation(_ record: DbLocationRecord) -> [String: Any] {
        return LocationMapper.buildLocationMap(
            id: record.id,
            uuid: record.uuid,
            timestamp: record.timestamp,
            latitude: record.latitude,
            longitude: record.longitude,
            altitude: record.altitude,
            speed: record.speed,
            heading: record.heading,
            accuracy: record.accuracy,
            isMock: record.isMock,
            activity: record.activity,
            routeContext: record.routeContext,
            isMoving: record.isMoving,
            odometer: locationEngine.getOdometer(),
            eventType: record.eventType,
            eventPayload: record.eventPayload
        )
    }

    /// Get the count of stored locations.
    ///
    /// - Parameter query: Optional query parameters (start, end).
    /// - Returns: Number of locations.
    public func getCount(query: [String: Any]? = nil) -> Int {
        guard isReady else { return 0 }
        guard let db = rustDatabase else { return 0 }
        do {
            let count = try db.getLocationsCount()
            return Int(count)
        } catch {
            NSLog("getCount failed: \(error)")
            return 0
        }
    }

    /// Destroy all stored locations.
    ///
    /// - Returns: `true` if locations were destroyed.
    @discardableResult
    public func destroyLocations() -> Bool {
        guard isReady else { return false }
        guard let db = rustDatabase else { return false }
        do {
            try db.destroyLocations()
            return true
        } catch {
            NSLog("destroyLocations failed: \(error)")
            return false
        }
    }

    /// Destroy only locations that have been successfully synced.
    ///
    /// - Returns: Number of synced locations deleted.
    @discardableResult
    public func destroySyncedLocations() -> Int {
        // Centralized Rust Core auto-sync immediately prunes synced locations.
        return 0
    }

    /// Destroy a single location by UUID.
    ///
    /// - Parameter uuid: The location UUID.
    /// - Returns: `true` if the location was destroyed.
    @discardableResult
    public func destroyLocation(_ uuid: String) -> Bool {
        guard isReady else { return false }
        guard let db = rustDatabase else { return false }
        guard let id = Int64(uuid) else { return false }
        do {
            try db.destroyLocation(id: id)
            return true
        } catch {
            NSLog("destroyLocation failed: \(error)")
            return false
        }
    }

    /// Caches the timestamp of the last inserted location to prevent duplicate 
    /// DB writes from the same GPS fix.
    private var lastInsertedTimestamp: String? = nil

    /// Insert a custom location into the store.
    ///
    /// - Parameter params: Location data dictionary.
    /// - Returns: The UUID of the inserted location.
    public func insertLocation(_ params: [String: Any]) -> String {
        // Persist whenever the Rust DB is initialized — NOT only when isReady.
        // The killed-state relaunch path (autoResumeTracking) wires the DB and
        // sync provider but never calls ready(), so isReady stays false. Gating
        // on isReady here silently dropped every location captured after a
        // background relaunch, leaving the DB empty so auto-sync had nothing to
        // send. The db check below is the correct readiness signal.
        guard let db = rustDatabase else { return "" }
        let coords = params["coords"] as? [String: Any] ?? params
        let lat = coords["latitude"] as? Double ?? 0.0
        let lng = coords["longitude"] as? Double ?? 0.0
        let acc = coords["accuracy"] as? Double ?? 0.0
        let speed = coords["speed"] as? Double ?? 0.0
        let heading = coords["heading"] as? Double ?? 0.0
        let altitude = coords["altitude"] as? Double ?? 0.0
        let isMock = (params["mock"] as? Bool) ?? (params["is_mock"] as? Bool) ?? false
        let isMoving = params["is_moving"] as? Bool ?? false
        let activityMap = params["activity"] as? [String: Any]
        let activity = activityMap?["type"] as? String ?? "unknown"
        let timestamp = params["timestamp"] as? String
        let uuid = params["uuid"] as? String
        
        let eventType = params["event"] as? String ?? "location"
        var eventPayload: String? = params["event_payload"] as? String
        if eventPayload == nil, let geofenceData = params["geofence"] as? [String: Any] {
            if let jsonData = try? JSONSerialization.data(withJSONObject: geofenceData, options: []),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                eventPayload = jsonString
            }
        }
        
        // Prevent duplicate insertions of the exact same GPS fix
        if eventType == "location", let ts = timestamp, ts == lastInsertedTimestamp {
            return ""
        }
        if eventType == "location" { lastInsertedTimestamp = timestamp }
        
        var routeContext = rustEngineState?.getRouteContext()
        if let auditHash = params["audit_hash"] as? String {
            var contextDict: [String: Any] = [:]
            if let rc = routeContext, let data = rc.data(using: .utf8) {
                if let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    contextDict = dict
                }
            }
            contextDict["audit_hash"] = auditHash
            if let prevHash = params["audit_previous_hash"] { contextDict["audit_previous_hash"] = prevHash }
            if let chainIndex = params["audit_chain_index"] { contextDict["audit_chain_index"] = chainIndex }
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: contextDict, options: []),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                routeContext = jsonString
            }
        }
        
        do {
            let newRowId = try db.insertLocation(
                uuid: uuid,
                lat: lat,
                lng: lng,
                acc: acc,
                speed: speed,
                heading: heading,
                altitude: altitude,
                isMock: isMock,
                isMoving: isMoving,
                activity: activity,
                routeContext: routeContext,
                timestampOverride: timestamp,
                eventType: eventType,
                eventPayload: eventPayload
            )
            // Notify the sync plugin so it can trigger auto-sync
            if let sink = syncProvider as? LocationDataSink {
                sink.insertLocation(params)
            }
            return newRowId.description
        } catch {
            NSLog("insertLocation failed: \(error)")
            return ""
        }
    }

    // =========================================================================
    // MARK: - HTTP Sync
    // =========================================================================

    /// Manually trigger HTTP synchronization of pending locations.
    ///
    /// - Parameter completion: Called with the list of synced location dictionaries.
    public func sync(completion: (([[String: Any]]) -> Void)? = nil) {
        guard isReady else { completion?([]); return }
        guard let db = rustDatabase,
              let state = rustEngineState else {
            completion?([])
            return
        }
        
        DispatchQueue.global(qos: .utility).async { [self] in
            do {
                let config = state.getConfig()
                let batchSize = config.http.maxBatchSize
                let records = try db.getLocationsBatch(query: LocationQuery(
                    startTimeMs: nil,
                    endTimeMs: nil,
                    limit: batchSize,
                    offset: nil,
                    // Honor the configured sort order (0=ascending, 1=descending)
                    // instead of always defaulting to ascending (Issue #138).
                    orderDescending: config.http.locationsOrderDirection == 1
                ))
                if records.isEmpty {
                    DispatchQueue.main.async { completion?([]) }
                    return
                }
                
                guard let syncProvider = syncProvider else {
                    NSLog("Sync failed: No SyncProvider registered (is tracelet_sync installed?)")
                    DispatchQueue.main.async { completion?([]) }
                    return
                }
                
                let syncedCount = try syncProvider.syncBatchBlocking(config: config.http, records: records)
                if syncedCount > 0 {
                    let successfullySynced = Array(records.prefix(Int(syncedCount)))
                    if let lastRecord = successfullySynced.last {
                        try db.clearLocationsUpTo(maxId: lastRecord.id)
                    }
                    DispatchQueue.main.async { completion?([]) }
                } else {
                    DispatchQueue.main.async { completion?([]) }
                }
            } catch {
                NSLog("Sync failed: \(error)")
                DispatchQueue.main.async { completion?([]) }
            }
        }
    }

    /// Update dynamic HTTP headers on the native side.
    ///
    /// Dynamic headers are merged with the static headers at sync time.
    /// Dynamic headers take precedence when keys overlap.
    ///
    /// - Parameter headers: Header key-value pairs.
    public func setDynamicHeaders(_ headers: [String: String]) {
        guard isReady else { return }
        configManager.setDynamicHeaders(headers)
        rustEngineState?.setDynamicHeaders(headers: headers)
    }

    // =========================================================================
    // MARK: - Route Context
    // =========================================================================

    /// Set the route context that will be persisted with every subsequent location.
    ///
    /// - Parameter context: Route context dictionary (taskId, driverId, etc.).
    public func setRouteContext(_ context: [String: Any]) {
        guard isReady else { return }
        configManager.setRouteContext(context)
        do {
            let data = try JSONSerialization.data(withJSONObject: context, options: [])
            if let jsonString = String(data: data, encoding: .utf8) {
                rustEngineState?.setRouteContext(json: jsonString)
            }
        } catch {
            NSLog("Failed to serialize routeContext: \(error)")
        }
    }

    /// Clear the current route context.
    public func clearRouteContext() {
        guard isReady else { return }
        configManager.clearRouteContext()
        rustEngineState?.setRouteContext(json: nil)
    }

    // =========================================================================
    // MARK: - Utility
    // =========================================================================

    /// Whether the device is currently in power-save (battery saver) mode.
    public var isPowerSaveMode: Bool {
        return ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    /// Get the current location permission status.
    ///
    /// - Returns: Authorization status code (0=notDetermined, 2=whenInUse, 3=always, 4=denied).
    public func getPermissionStatus() -> Int {
        return permissionManager.getAuthorizationStatus()
    }

    /// Whether the app has background ("Always") location permission.
    public var hasBackgroundPermission: Bool {
        return getPermissionStatus() == 3
    }

    /// Get the current location provider state.
    ///
    /// - Returns: Provider state dictionary.
    public func getProviderState() -> [String: Any] {
        let status = permissionManager.getAuthorizationStatus()
        let enabled = CLLocationManager.locationServicesEnabled()
        return [
            "enabled": enabled,
            "status": status,
            "gps": enabled,
            "network": enabled,
        ]
    }

    /// Get information about available device sensors.
    ///
    /// - Returns: Sensors dictionary.
    public func getSensors() -> [String: Any] {
        return [
            "accelerometer": true,
            "gyroscope": true,
            "magnetometer": true,
            "significantMotion": true,
            "motionActivity": isReady ? !configManager.getDisableMotionActivityUpdates() : true,
        ]
    }

    /// Get information about the device.
    ///
    /// - Returns: Device info dictionary.
    public func getDeviceInfo() -> [String: Any] {
        #if canImport(UIKit)
        let device = UIDevice.current
        return [
            "manufacturer": "Apple",
            "model": device.model,
            "platform": "ios",
            "version": device.systemVersion,
            "framework": "native",
        ]
        #else
        return [
            "manufacturer": "Apple",
            "model": "unknown",
            "platform": "ios",
            "version": ProcessInfo.processInfo.operatingSystemVersionString,
            "framework": "native",
        ]
        #endif
    }

    /// Play a debug sound effect.
    ///
    /// - Parameter name: Sound identifier.
    /// - Returns: `true` if the sound was played.
    @discardableResult
    public func playSound(_ name: String) -> Bool {
        guard isReady else { return false }
        let _ = soundManager.playSound(name)
        return true
    }

    // =========================================================================
    // MARK: - Logging
    // =========================================================================

    /// Get the plugin log as a string.
    ///
    /// - Parameter query: Optional query parameters.
    /// - Returns: Formatted log string.
    public func getLog(query: [String: Any]? = nil) -> String {
        guard isReady else { return "" }
        return logger.getLog(query: query)
    }

    /// Destroy all log entries.
    ///
    /// - Returns: `true` if logs were destroyed.
    @discardableResult
    public func destroyLog() -> Bool {
        guard isReady else { return false }
        return logger.destroyLog()
    }

    /// Write a custom log entry.
    ///
    /// - Parameters:
    ///   - level: Log level ("error", "warn", "info", "debug", "verbose").
    ///   - message: Log message.
    public func log(_ level: String, _ message: String) {
        guard isReady else { return }
        logger.log(levelString: level, message: message)
    }

    // =========================================================================
    // MARK: - Scheduling
    // =========================================================================

    /// Start the scheduler (uses the `schedule` array in config).
    ///
    /// - Returns: Updated state as a dictionary.
    @discardableResult
    public func startSchedule() -> [String: Any] {
        guard isReady else { return getState() }
        scheduleManager.start()
        return stateManager.toMap(configManager.getConfig())
    }

    /// Stop the scheduler.
    ///
    /// - Returns: Updated state as a dictionary.
    @discardableResult
    public func stopSchedule() -> [String: Any] {
        guard isReady else { return getState() }
        scheduleManager.stop()
        return stateManager.toMap(configManager.getConfig())
    }

    // =========================================================================
    // MARK: - Enterprise: Audit Trail
    // =========================================================================

    /// Verify the integrity of the tamper-proof audit trail.
    ///
    /// - Returns: Verification result dictionary.
    public func verifyAuditTrail() -> [String: Any] {
        guard auditTrailManager != nil else { return [:] }
        return auditTrailManager.verifyChain()
    }

    /// Get the audit proof for a specific location record.
    ///
    /// - Parameter uuid: The location UUID.
    /// - Returns: Audit proof dictionary, or nil if not found.
    public func getAuditProof(_ uuid: String) -> [String: Any]? {
        guard auditTrailManager != nil else { return nil }
        return auditTrailManager.getProof(uuid: uuid)
    }

    // =========================================================================
    // MARK: - Enterprise: Privacy Zones
    // =========================================================================

    /// Add a single privacy zone.
    ///
    /// - Parameter zone: Privacy zone dictionary (identifier, latitude, longitude, radius, action).
    /// - Returns: `true` if the zone was added.
    @discardableResult
    public func addPrivacyZone(_ zone: [String: Any]) -> Bool {
        guard privacyZoneManager != nil else { return false }
        return privacyZoneManager.addZone(zone)
    }

    /// Add a single privacy zone using a typed ``TraceletPrivacyZone`` model.
    ///
    /// - Parameter zone: Typed privacy zone model.
    /// - Returns: `true` if the zone was added.
    @discardableResult
    public func addPrivacyZone(_ zone: TraceletPrivacyZone) -> Bool {
        return addPrivacyZone(zone.toMap())
    }

    /// Add multiple privacy zones at once.
    ///
    /// - Parameter zones: Array of privacy zone dictionaries.
    /// - Returns: `true` if all zones were added.
    @discardableResult
    public func addPrivacyZones(_ zones: [[String: Any]]) -> Bool {
        guard privacyZoneManager != nil else { return false }
        return privacyZoneManager.addZones(zones)
    }

    /// Add multiple privacy zones using typed ``TraceletPrivacyZone`` models.
    ///
    /// - Parameter zones: Array of typed privacy zone models.
    /// - Returns: `true` if all zones were added.
    @discardableResult
    public func addPrivacyZones(_ zones: [TraceletPrivacyZone]) -> Bool {
        return addPrivacyZones(zones.map { $0.toMap() })
    }

    /// Remove a privacy zone by its identifier.
    ///
    /// - Parameter identifier: The zone identifier.
    /// - Returns: `true` if the zone was removed.
    @discardableResult
    public func removePrivacyZone(_ identifier: String) -> Bool {
        guard privacyZoneManager != nil else { return false }
        return privacyZoneManager.removeZone(identifier)
    }

    /// Remove all privacy zones.
    ///
    /// - Returns: `true` if zones were removed.
    @discardableResult
    public func removePrivacyZones() -> Bool {
        guard privacyZoneManager != nil else { return false }
        return privacyZoneManager.removeAllZones()
    }

    /// Get all registered privacy zones.
    ///
    /// - Returns: Array of privacy zone dictionaries.
    public func getPrivacyZones() -> [[String: Any]] {
        guard privacyZoneManager != nil else { return [] }
        return privacyZoneManager.getZones()
    }

    // =========================================================================
    // MARK: - Enterprise: Device Attestation
    // =========================================================================

    /// Request a fresh device attestation token.
    ///
    /// - Parameter completion: Called with the attestation token dictionary, or nil.
    public func getAttestationToken(completion: @escaping ([String: Any]?) -> Void) {
        guard isReady else { completion(nil); return }
        deviceAttestor.requestToken(completion: completion)
    }

    // =========================================================================
    // MARK: - Enterprise: Dead Reckoning
    // =========================================================================

    /// Get the current dead reckoning state.
    ///
    /// - Returns: DR state dictionary, or nil if DR is disabled or GPS is available.

    // MARK: - Encryption

    public func isDatabaseEncrypted() -> Bool {
        return true
    }

    public func encryptDatabase() -> Bool {
        return true
    }


    public func getDeadReckoningState() -> [String: Any]? {
        // DR state is managed internally by LocationEngine — expose if active.
        return nil // TODO: Wire up when DeadReckoningEngine exposes state
    }

    // =========================================================================
    // MARK: - Initialization
    // =========================================================================

    /// Create all subsystems. Call ``setEventSender(_:)`` first.
    ///
    /// Safe to call multiple times — returns immediately if already initialized.
    /// Called automatically by ``ready(config:)`` if not already invoked.
    /// Framework bridges (Flutter, React Native) should call this during plugin
    /// registration so that callback properties (e.g. ``httpSyncManager``'s
    /// ``onRequestFreshHeaders``) can be wired before ``ready()`` is called.
    public func initialize() {
        guard configManager == nil else { return }
        // Register bootstrap factory for headless/background restarts
        TraceletBootstrapIOS.eventSenderFactory = { [weak self] in
            self?.getEventSender() ?? DelegateEventSender()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        // Persistence
        // Note: iOS does not need a separate DatabaseEncryptionManager.
        // Android uses SQLCipher (application-level AES-256 encryption)
        // managed by DatabaseEncryptionManager, whereas iOS uses
        // NSFileProtectionComplete (hardware-level, OS-managed encryption).
        // Auto-encryption is triggered in ready() if encryptDatabase=true.
        configManager = ConfigManager()
        stateManager = StateManager()

        // ── Rust Core bootstrap ──
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = paths[0]
        let dbDir = documentsDirectory + "/tracelet"
        if !FileManager.default.fileExists(atPath: dbDir) {
            try? FileManager.default.createDirectory(atPath: dbDir, withIntermediateDirectories: true, attributes: nil)
        }
        let dbPath = dbDir + "/tracelet.db"
        do {
            let db = try DatabaseManager(dbPath: dbPath)
            
            let savedConfig = configManager.getConfig()
            if savedConfig["encryptDatabase"] as? Bool == true {
                let key = savedConfig["encryptionKey"] as? String ?? ""
                db.setEncryptionKey(key: key)
            } else {
                db.setEncryptionKey(key: "")
            }
            
            let state = EngineState()
            let dispatcher = EventDispatcher(db: db, state: state)
            self.rustDatabase = db
            
            self.rustEngineState = state
            self.rustPluginEventDispatcher = dispatcher
            syncConfigToRustFlat()
            NSLog("Tracelet: Rust Core initialized at \(dbPath)")
        } catch {
            NSLog("Tracelet: Failed to initialize Rust Core: \(error)")
        }

        // Logger
        logger = TraceletLogger(configManager: configManager)
        logger.rustDatabase = rustDatabase

        // Enterprise features
        auditTrailManager = AuditTrailManager(configManager: configManager, rustDatabase: rustDatabase)
        privacyZoneManager = PrivacyZoneManager(configManager: configManager, rustDatabase: rustDatabase)
        deviceAttestor = DeviceAttestor()

        // Location engine
        locationEngine = LocationEngine(
            configManager: configManager,
            stateManager: stateManager,
            eventDispatcher: eventSender
        )
        locationEngine.registerSink(RustDatabaseSinkWrapper(sdk: self))
        if let syncSink = syncProvider as? LocationDataSink {
            locationEngine.registerSink(syncSink)
        }
        locationEngine.rustPluginEventDispatcher = rustPluginEventDispatcher
        locationEngine.auditTrailManager = auditTrailManager
        locationEngine.privacyZoneManager = privacyZoneManager
        locationEngine.onLocationPersisted = { [weak self] in
            // Location persistence handled by Rust
        }

        // Trip manager
        tripManager = TraceletTripManager()
        tripManager.onTripEnd = { [weak self] data in
            self?.eventSender.sendTrip(data)
        }

        // Motion detector
        motionDetector = MotionDetector(
            configManager: configManager,
            stateManager: stateManager,
            eventDispatcher: eventSender,
            logger: logger
        )
        motionDetector.onMotionStateChanged = { [weak self] isMoving in
            self?.handleMotionStateChange(isMoving)
        }
        motionDetector.onStopTimeoutStarted = { [weak self] in
            self?.locationEngine.overrideDistanceFilter(forStopTimeout: true, source: "MotionDetector")
        }
        motionDetector.onStopTimeoutCancelled = { [weak self] in
            self?.locationEngine.overrideDistanceFilter(forStopTimeout: false, source: "MotionDetector")
        }
        motionDetector.onStopRequested = { [weak self] in
            self?.stop()
        }

        // Geofencing
        geofenceManager = GeofenceManager(
            configManager: configManager,
            eventSender: eventSender,
            rustDatabase: rustDatabase
        )
        geofenceManager.onGeofenceEvent = { [weak self] eventData in
            let _ = self?.insertLocation(eventData)
        }
        
        // Smart motion coordinator
        smartMotionCoordinator = TraceletSmartMotionCoordinator(sdk: self)

        // HTTP sync is handled natively by Rust Core via PluginEventDispatcher


        // Scheduling
        scheduleManager = ScheduleManager(
            configManager: configManager,
            stateManager: stateManager,
            eventDispatcher: eventSender
        )
        scheduleManager.onScheduleStart = { [weak self] in self?.handleScheduleStart() }
        scheduleManager.onScheduleStop = { [weak self] in self?.handleScheduleStop() }

        // Utilities
        soundManager = SoundManager(configManager: configManager)

        // Battery monitoring
        BatteryUtils.initialize()

        // Background keep-alive managers
        preventSuspendManager = PreventSuspendManager(configManager: configManager)
        backgroundActivitySessionManager = BackgroundActivitySessionManager()
        serviceSessionManager = ServiceSessionManager()
        periodicRefreshScheduler = PeriodicRefreshScheduler()
        periodicRefreshScheduler.registerTask()
        periodicRefreshScheduler.onWakeUp = { [weak self] in
            guard let self = self,
                  self.stateManager.enabled,
                  self.stateManager.trackingMode == .periodic else { return }
            self.locationEngine.performPeriodicFix()
            self.locationEngine.restartPeriodicTimerIfNeeded()
        }
    }

    // MARK: - Private: Motion State

    private func handleMotionStateChange(_ isMoving: Bool) {
        // A CMMotionActivity callback can land after stop() — never let it
        // restart tracking (changePace/coordinator can start GPS again).
        guard stateManager.enabled else {
            logger.debug("handleMotionStateChange ignored — tracking is stopped")
            return
        }
        if configManager.getMotionDetectionMode() == .smart {
            // In SMART mode, route the accel event through the coordinator first.
            // Only reset the speed state machine when the coordinator actually
            // decides to SWITCH_TO_CONTINUOUS (a genuine wake-up from stationary).
            // This prevents micro-vibrations from the significant motion sensor
            // from force-resetting the speed SM on every fire (infinite loop),
            // while still allowing the system to wake from stationary when the
            // coordinator determines real movement has begun.
            let action = smartMotionCoordinator.onAccelStateChange(isMoving: isMoving)
            if action == .switchToContinuous {
                speedMotionManager?.onManualPaceChange(isMoving: true)
            }
            return
        }

        NSLog("[Tracelet] Motion state changed: isMoving=\(isMoving)")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.stateManager.isMoving = isMoving
            self.locationEngine.changePace(isMoving)

            if isMoving {
                self.backgroundActivitySessionManager.start()
            } else {
                self.backgroundActivitySessionManager.stop()
            }

            // Feed TripManager with motion state change
            let lastLoc = self.locationEngine.getLastLocation()
            self.tripManager.onMotionStateChanged(
                isMoving: isMoving,
                latitude: lastLoc?.coordinate.latitude,
                longitude: lastLoc?.coordinate.longitude,
                timestamp: lastLoc.map { ISO8601DateFormatter().string(from: $0.timestamp) }
            )
        }
    }

    // MARK: - Private: Schedule

    private func handleScheduleStart() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.stateManager.enabled else { return }
            self.start()
        }
    }

    private func handleScheduleStop() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.stateManager.enabled else { return }
            self.stop()
        }
    }

    // MARK: - Private: Heartbeat

    /// Last location timestamp persisted by a heartbeat — used to deduplicate DB writes.
    private var lastHeartbeatLocationTime: TimeInterval = 0

    private func startHeartbeat() {
        stopHeartbeat()
        let interval = configManager.getHeartbeatInterval()
        guard interval > 0 else { return }

        DispatchQueue.main.async { [weak self] in
            self?.heartbeatTimer = Timer.scheduledTimer(
                withTimeInterval: TimeInterval(interval),
                repeats: true
            ) { [weak self] _ in
                guard let self = self else { return }
                NSLog("[Tracelet] Heartbeat fired")
                guard let location = self.locationEngine.getLastGpsLocation() else {
                    if self.configManager.isDebug() {
                        NSLog("[Tracelet] Heartbeat: no cached location, skipping")
                    }
                    return
                }
                // Build a fully enriched location map with UUID, battery, etc.
                var locationMap = self.locationEngine.buildLocationMap(location)
                locationMap["event"] = "heartbeat"

                // Only persist to DB if this is a genuinely new GPS fix
                // (different timestamp from the last heartbeat write).
                // This avoids hundreds of redundant DB inserts per hour
                // when the user is stationary and the cached location
                // hasn't changed.
                let fixTime = location.timestamp.timeIntervalSince1970
                if fixTime != self.lastHeartbeatLocationTime {
                    self.lastHeartbeatLocationTime = fixTime
                    let _ = self.insertLocation(locationMap)
                    self.locationEngine.onLocationPersisted?()
                }

                // Always send the event so Flutter UI stays alive
                let data: [String: Any] = ["location": locationMap]
                self.eventSender.sendHeartbeat(data)
                NSLog("[Tracelet] Heartbeat: lat=%.6f, lon=%.6f, accuracy=%.1fm",
                      location.coordinate.latitude, location.coordinate.longitude,
                      location.horizontalAccuracy)
            }
        }
    }

    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    // MARK: - Private: Battery Budget Sampling

    private func startBatteryBudgetSampling() {
        stopBatteryBudgetSampling()
        guard let engine = batteryBudgetEngine else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.batteryBudgetTimer = Timer.scheduledTimer(
                withTimeInterval: Self.batterySampleInterval,
                repeats: true
            ) { [weak self] _ in
                guard let self = self, self.stateManager.enabled else { return }

                // Skip sampling while charging — drain will be negative and
                // there's no reason to throttle accuracy on external power.
                if BatteryUtils.isCharging() {
                    return
                }

                let level = Double(BatteryUtils.getBatteryLevel())
                if let event = engine.processSample(level) {
                    // ── Apply the computed adjustments to the live config ──
                    // Without this, the engine calculates new values but the
                    // LocationEngine keeps running with the original settings.
                    self.configManager.setConfig([
                        "distanceFilter": event.newDistanceFilter,
                        "desiredAccuracy": event.newDesiredAccuracy,
                    ])
                    if let interval = event.newPeriodicInterval {
                        self.configManager.setConfig([
                            "periodicLocationInterval": interval,
                        ])
                    }

                    // Restart the location engine so it picks up the new
                    // distanceFilter and accuracy from ConfigManager.
                    if self.stateManager.enabled {
                        self.locationEngine.stop()
                        self.locationEngine.start()
                    }

                    self.eventSender.sendBudgetAdjustment([
                        "currentBatteryDrain": event.currentBatteryDrain,
                        "targetBudget": event.targetBudget,
                        "newDistanceFilter": event.newDistanceFilter,
                        "newDesiredAccuracy": event.newDesiredAccuracy,
                        "newPeriodicInterval": event.newPeriodicInterval as Any,
                    ])
                    self.logger.info(
                        "BatteryBudget adjusted: df=\(event.newDistanceFilter), " +
                        "acc=\(event.newDesiredAccuracy), drain=\(event.currentBatteryDrain)%/hr"
                    )
                }
            }
        }
    }

    private func stopBatteryBudgetSampling() {
        batteryBudgetTimer?.invalidate()
        batteryBudgetTimer = nil
    }

    // MARK: - Private: stopAfterElapsedMinutes

    private func startStopAfterElapsedTimer() {
        cancelStopAfterElapsedTimer()
        let minutes = configManager.getStopAfterElapsedMinutes()
        guard minutes > 0 else { return }

        DispatchQueue.main.async { [weak self] in
            self?.stopAfterElapsedTimer = Timer.scheduledTimer(
                withTimeInterval: TimeInterval(minutes * 60),
                repeats: false
            ) { [weak self] _ in
                guard let self = self else { return }
                BackgroundTaskHelper.shared.run("stopAfterElapsed") {
                    self.stateManager.enabled = false
                    self.stateManager.isMoving = false
                    self.locationEngine.stop()
                    self.motionDetector.stop()
                    self.stopHeartbeat()
                    self.periodicRefreshScheduler.stop()
                    self.preventSuspendManager.stop()
                    self.backgroundActivitySessionManager.stop()
                    self.serviceSessionManager.stop()
                    self.eventSender.sendEnabledChange(false)
                }
            }
        }
    }

    private func cancelStopAfterElapsedTimer() {
        stopAfterElapsedTimer?.invalidate()
        stopAfterElapsedTimer = nil
    }

    // MARK: - Private: Service Session

    /// Starts a `CLServiceSession` (iOS 18+) matching the user's permission.
    private func startServiceSessionForCurrentAuth() {
        let status = locationEngine.getAuthorizationStatus()
        switch status {
        case 3: // authorizedAlways
            serviceSessionManager.start()
        case 2: // authorizedWhenInUse
            serviceSessionManager.startWhenInUse()
        default:
            break
        }
    }

    // MARK: - Public: App Termination

    /// Called when the app is about to be terminated.
    ///
    /// Ensures significant location monitoring is registered so iOS will
    /// relaunch the app on the next cell-tower change. Also creates a
    /// fresh `CLLocationManager` to survive the teardown and explicitly
    /// starts significant location monitoring on it.
    ///
    /// **Important:** This does NOT survive user force-quit on iOS (swipe
    /// up from app switcher). Apple explicitly kills all location services
    /// in that scenario. This handles system-initiated termination only
    /// (memory pressure, OS updates, etc.).
    public func onAppWillTerminate() {
        guard stateManager != nil, stateManager.enabled else { return }
        guard configManager != nil, !configManager.getStopOnTerminate() else { return }

        NSLog("[Tracelet] onAppWillTerminate: stopOnTerminate=false, ensuring significant location monitoring")

        // Create a standalone CLLocationManager that outlives the current
        // singleton teardown. By starting significant location monitoring
        // on a fresh manager, we guarantee iOS has an active registration
        // that will trigger a relaunch.
        let terminationManager = CLLocationManager()
        terminationManager.startMonitoringSignificantLocationChanges()
        // Store in a static to prevent deallocation before the process ends.
        TraceletSdk._terminationLocationManager = terminationManager

        NSLog("[Tracelet] onAppWillTerminate: significant location monitoring registered on termination manager")
    }

    /// Holds a reference to the CLLocationManager created at termination
    /// time so it isn't deallocated before the process exits.
    private static var _terminationLocationManager: CLLocationManager?

    // MARK: - Public: Auto-Resume from killed state

    /// Automatically resumes tracking after the app is relaunched from a
    /// killed state by a significant location change.
    ///
    /// Call this from `application(_:didFinishLaunchingWithOptions:)` when
    /// `LaunchOptionsKey.location` is present.
    public func autoResumeTracking() {
        NSLog("[Tracelet] autoResumeTracking: starting")
        if configManager == nil {
            NSLog("[Tracelet] autoResumeTracking: configManager nil, calling initialize()")
            initialize()
        }

        // Guard: stopOnTerminate means we should NOT resume after kill.
        if configManager.getStopOnTerminate() {
            NSLog("[Tracelet] autoResumeTracking: stopOnTerminate=true, aborting")
            stateManager.enabled = false
            return
        }

        guard stateManager.enabled else {
            NSLog("[Tracelet] autoResumeTracking: stateManager.enabled=false, aborting")
            return
        }

        let authStatus = locationEngine.getAuthorizationStatus()
        guard authStatus == 3 else { // authorizedAlways
            NSLog("[Tracelet] autoResumeTracking: authStatus=\(authStatus), need 3 (Always), disabling")
            stateManager.enabled = false
            return
        }

        stateManager.didLaunchInBackground = true
        let trackingMode = stateManager.trackingMode
        NSLog("[Tracelet] autoResumeTracking: trackingMode=\(trackingMode), resuming")

        // HTTP Sync is auto-started by Rust Core Config
        NSLog("[Tracelet] autoResumeTracking: Rust SyncManager active")

        // Wire onLocationPersisted so persisted locations trigger HTTP auto-sync.
        // Without this, locations accumulate in SQLite but never sync.
        locationEngine.onLocationPersisted = {
            // Location persistence handled by Rust
        }

        switch trackingMode {
        case .continuous:
            locationEngine.start()
            locationEngine.onLocationUpdate = { [weak self] lat, lng in
                self?.geofenceManager.updateProximity(latitude: lat, longitude: lng)
                if self?.configManager.getGeofenceModeHighAccuracy() == true {
                    self?.geofenceManager.evaluateHighAccuracyProximity(latitude: lat, longitude: lng)
                }
                self?.tripManager.onLocationReceived(
                    latitude: lat,
                    longitude: lng,
                    timestamp: ISO8601DateFormatter().string(from: Date())
                )
            }
            let motionMode = configManager.getMotionDetectionMode()
            if motionMode == .speed {
                startSpeedMotionManager(forceMoving: stateManager.isMoving)
            } else if motionMode == .smart {
                startSpeedMotionManager(forceMoving: stateManager.isMoving)
                motionDetector.start()
            } else {
                motionDetector.start()
            }
            startHeartbeat()
            preventSuspendManager.start()
            backgroundActivitySessionManager.start()
            serviceSessionManager.start()

        case .geofences:
            geofenceManager.reRegisterAll()
            locationEngine.onLocationUpdate = { [weak self] lat, lng in
                self?.geofenceManager.updateProximity(latitude: lat, longitude: lng)
                if self?.configManager.getGeofenceModeHighAccuracy() == true {
                    self?.geofenceManager.evaluateHighAccuracyProximity(latitude: lat, longitude: lng)
                }
            }
            locationEngine.start()
            preventSuspendManager.start()
            backgroundActivitySessionManager.start()
            serviceSessionManager.start()

        case .periodic:
            locationEngine.startPeriodic()
            locationEngine.onLocationUpdate = { [weak self] lat, lng in
                self?.geofenceManager.updateProximity(latitude: lat, longitude: lng)
                if self?.configManager.getGeofenceModeHighAccuracy() == true {
                    self?.geofenceManager.evaluateHighAccuracyProximity(latitude: lat, longitude: lng)
                }
            }
            let interval = TimeInterval(configManager.getPeriodicLocationInterval())
            periodicRefreshScheduler.start(interval: interval)
            if configManager.getPreventSuspend() {
                preventSuspendManager.start()
            }
            // Do NOT start CLBackgroundActivitySession for periodic mode —
            // it causes a persistent location indicator in the status bar.
            startServiceSessionForCurrentAuth()

        @unknown default:
            break
        }
    }

    // MARK: - Enterprise: Carbon Report

    /// Generate a carbon emissions report for a time range.
    ///
    /// - Parameter query: Query parameters (startTime, endTime, transportMode).
    /// - Returns: Carbon report dictionary.
    public func getCarbonReport(query: [String: Any]? = nil) -> [String: Any] {
        guard isReady else {
            return [
                "totalCarbonGrams": 0.0,
                "carbonByMode": [String: Double](),
                "distanceByMode": [String: Double](),
                "totalTrips": 0
            ]
        }
        
        let locations = self.getLocations(query: query)
        
        var totalGrams = 0.0
        var carbonByMode = [String: Double]()
        var distanceByMode = [String: Double]()
        var prevLat = 0.0
        var prevLng = 0.0
        var tripCount = 0
        var wasMoving = false
        
        for location in locations {
            let coords = location["coords"] as? [String: Any]
            guard let lat = (coords?["latitude"] as? NSNumber)?.doubleValue ?? (location["latitude"] as? NSNumber)?.doubleValue,
                  let lng = (coords?["longitude"] as? NSNumber)?.doubleValue ?? (location["longitude"] as? NSNumber)?.doubleValue else {
                continue
            }
            
            let act = location["activity"] as? [String: Any]
            let actType = act?["type"] as? String ?? "unknown"
            
            let isMovingInt = location["is_moving"] as? Int
            let isMovingBool = location["is_moving"] as? Bool
            let isMoving = isMovingInt == 1 || isMovingBool == true
            
            if !wasMoving && isMoving {
                tripCount += 1
            }
            wasMoving = isMoving
            
            if prevLat != 0.0 && prevLng != 0.0 {
                let dist = GeoUtils.haversine(prevLat, prevLng, lat, lng)
                distanceByMode[actType] = (distanceByMode[actType] ?? 0.0) + dist
                let factor = carbonFactorForMode(actType)
                let grams = (dist / 1000.0) * factor
                carbonByMode[actType] = (carbonByMode[actType] ?? 0.0) + grams
                totalGrams += grams
            }
            prevLat = lat
            prevLng = lng
        }
        
        return [
            "totalCarbonGrams": totalGrams,
            "carbonByMode": carbonByMode,
            "distanceByMode": distanceByMode,
            "totalTrips": tripCount
        ]
    }

    private func carbonFactorForMode(_ mode: String) -> Double {
        switch mode {
        case "car": return 192.0
        case "bus": return 89.0
        case "train": return 41.0
        case "bicycle", "bike": return 0.0
        case "walking", "walk", "on_foot": return 0.0
        case "e-scooter", "scooter": return 35.0
        case "motorcycle": return 113.0
        case "plane", "flight": return 255.0
        default: return 192.0
        }
    }
    // =========================================================================
    // MARK: - Cleanup
    // =========================================================================

    /// Comprehensive teardown of all subsystems.
    ///
    /// Called when the host application (or its bridge) is being destroyed.
    /// Respects `stopOnTerminate: false` by skipping teardown for critical
    /// background tracking components when enabled.
    public func destroyAll() {
        // When stopOnTerminate=false and tracking is active, the SDK should
        // continue running in the background. Tearing down subsystems here
        // would kill that background continuity.
        let keepAlive = !configManager.getStopOnTerminate() && stateManager.enabled

        // LocationEngine — keep alive for continuous and geofence modes.
        // Periodic mode has its own scheduler lifecycle.
        if !(keepAlive && stateManager.trackingMode != .periodic) {
            locationEngine.stop()
        }
        motionDetector.stop()

        // GeofenceManager — keep alive only in geofence mode.
        let keepGeofencesAlive = keepAlive && stateManager.trackingMode == .geofences
        if !keepGeofencesAlive {
            geofenceManager.destroy()
        }

        // Subsystems that should only survive if we are in a background-active mode.
        if !keepAlive {
            // TODO: Stop Rust SyncManager if necessary
            scheduleManager.stop()
            stopHeartbeat()
            preventSuspendManager.stop()
            backgroundActivitySessionManager.stop()
            serviceSessionManager.stop()
        }

        // Sound and budget sampling are safe to stop unconditionally.
        soundManager.stop()
        stopBatteryBudgetSampling()

        // Periodic scheduler — keep alive only in periodic mode.
        let keepPeriodicAlive = keepAlive && stateManager.trackingMode == .periodic
        if !keepPeriodicAlive {
            periodicRefreshScheduler.stop()
        }
    }

    private func startSpeedMotionManager(forceMoving: Bool = false) {
        let smm = SpeedMotionManager(stateManager: stateManager)
        smm.speedMovingThreshold = configManager.getSpeedMovingThreshold()
        smm.speedStationaryDelay = configManager.getSpeedStationaryDelay()
        smm.stationaryTrackingMode = configManager.getStationaryTrackingMode()
        smm.stationaryPeriodicInterval = configManager.getStationaryPeriodicInterval()
        smm.speedWakeConfirmCount = configManager.getSpeedWakeConfirmCount()
        smm.delegate = self
        smm.start(forceMoving: forceMoving)
        speedMotionManager = smm

        // Feed CLLocation.speed to the state machine on every fix
        locationEngine.speedSink = { [weak smm] speed in
            smm?.onLocation(speed: speed)
        }

        // Feed the last known GPS speed immediately on startup to prevent deadlocks when physically stationary
        smm.onLocation(speed: locationEngine.lastEffectiveSpeed)

        NSLog("[Tracelet] Speed motion mode started (threshold=%.1f, delay=%ds, stationary=%@)",
              smm.speedMovingThreshold, smm.speedStationaryDelay, smm.stationaryTrackingMode == .geofences ? "geofences" : "periodic")

        // Sync stateManager.isMoving with restored speed motion state if not forcing
        if !forceMoving {
            if smm.state == .stationary {
                smartMotionCoordinator.onSpeedStateChange(isMoving: false)
                stateManager.isMoving = false
            } else {
                smartMotionCoordinator.onSpeedStateChange(isMoving: true)
                stateManager.isMoving = true
            }
        }

        // If we're resuming in stationary state, switch immediately
        if smm.state == .stationary {
            if smm.stationaryTrackingMode == .geofences {
                locationEngine.switchToStationaryGeofences()
            } else {
                locationEngine.switchToStationaryPeriodic()
            }
        }
    }
}

// MARK: - SpeedMotionDelegate

extension TraceletSdk: SpeedMotionDelegate {

    public func switchToContinuous() {
        if configManager.getMotionDetectionMode() == .smart {
            smartMotionCoordinator.onSpeedStateChange(isMoving: true)
            return
        }
        switchToContinuousForce()
    }

    public func switchToContinuousForce() {
        BackgroundTaskHelper.shared.run("speedSwitchContinuous") { [self] in
            // A queued speed/smart callback can execute after stop() — never
            // restart continuous GPS once the user has stopped tracking.
            guard stateManager.enabled else {
                logger.debug("switchToContinuousForce ignored — tracking is stopped")
                return
            }
            stateManager.isMoving = true
            stateManager.trackingMode = .continuous
            locationEngine.switchToContinuous()
            backgroundActivitySessionManager.start()

            // Emit motionchange event for backward compatibility
            let lastLoc = locationEngine.getLastLocation()
            tripManager.onMotionStateChanged(
                isMoving: true,
                latitude: lastLoc?.coordinate.latitude,
                longitude: lastLoc?.coordinate.longitude,
                timestamp: lastLoc.map { ISO8601DateFormatter().string(from: $0.timestamp) }
            )

            if let loc = lastLoc {
                var map = locationEngine.buildLocationMap(loc, speed: locationEngine.lastEffectiveSpeed)
                map["isMoving"] = true
                map["event"] = "motionchange"
                eventSender.sendMotionChange(map)
            } else {
                eventSender.sendMotionChange(["isMoving": true])
            }
        }
    }

    public func switchToStationaryPeriodic() {
        if configManager.getMotionDetectionMode() == .smart {
            smartMotionCoordinator.onSpeedStateChange(isMoving: false)
            return
        }
        switchToStationaryPeriodicForce()
    }

    public func switchToStationaryPeriodicForce() {
        BackgroundTaskHelper.shared.run("speedSwitchStationary") { [self] in
            // A queued speed/smart callback can execute after stop() — never
            // restart the stationary periodic timer once tracking is stopped.
            guard stateManager.enabled else {
                logger.debug("switchToStationaryPeriodicForce ignored — tracking is stopped")
                return
            }
            stateManager.isMoving = false
            locationEngine.switchToStationaryPeriodic()
            backgroundActivitySessionManager.stop()

            // Emit motionchange event for backward compatibility
            let lastLoc = locationEngine.getLastLocation()
            tripManager.onMotionStateChanged(
                isMoving: false,
                latitude: lastLoc?.coordinate.latitude,
                longitude: lastLoc?.coordinate.longitude,
                timestamp: lastLoc.map { ISO8601DateFormatter().string(from: $0.timestamp) }
            )

            if let loc = lastLoc {
                var map = locationEngine.buildLocationMap(loc, speed: locationEngine.lastEffectiveSpeed)
                map["isMoving"] = false
                map["event"] = "motionchange"
                eventSender.sendMotionChange(map)
            } else {
                eventSender.sendMotionChange(["isMoving": false])
            }

            // Handle stopOnStationary
            if configManager.getStopOnStationary() {
                stop()
            }
        }
    }

    public func switchToStationaryGeofences() {
        if configManager.getMotionDetectionMode() == .smart {
            smartMotionCoordinator.onSpeedStateChange(isMoving: false)
        } else {
            switchToStationaryGeofencesForce()
        }
    }

    public func switchToStationaryGeofencesForce() {
        BackgroundTaskHelper.shared.run("speedSwitchGeofences") { [self] in
            // A queued speed/smart callback can execute after stop() — never
            // re-register geofence monitoring once tracking is stopped.
            guard stateManager.enabled else {
                logger.debug("switchToStationaryGeofencesForce ignored — tracking is stopped")
                return
            }
            stateManager.isMoving = false
            stateManager.trackingMode = .geofences
            locationEngine.switchToStationaryGeofences()
            backgroundActivitySessionManager.stop()
            geofenceManager.reRegisterAll()

            // Emit motionchange event for backward compatibility
            let lastLoc = locationEngine.getLastLocation()
            tripManager.onMotionStateChanged(
                isMoving: false,
                latitude: lastLoc?.coordinate.latitude,
                longitude: lastLoc?.coordinate.longitude,
                timestamp: lastLoc.map { ISO8601DateFormatter().string(from: $0.timestamp) }
            )

            if let loc = lastLoc {
                var map = locationEngine.buildLocationMap(loc, speed: locationEngine.lastEffectiveSpeed)
                map["isMoving"] = false
                map["event"] = "motionchange"
                eventSender.sendMotionChange(map)
            } else {
                eventSender.sendMotionChange(["isMoving": false])
            }

            // Handle stopOnStationary
            if configManager.getStopOnStationary() {
                stop()
            }
        }
    }

    public func speedMotionDidStartSlowing() {
        locationEngine.overrideDistanceFilter(forStopTimeout: true, source: "SpeedMotionManager")
    }

    public func speedMotionDidCancelSlowing() {
        locationEngine.overrideDistanceFilter(forStopTimeout: false, source: "SpeedMotionManager")
    }

    public func emitSpeedMotionEvent(state: Int, previousState: Int, trackingMode: Int) {
        eventSender.sendSpeedMotionEvent([
            "state": state,
            "previousState": previousState,
            "trackingMode": trackingMode
        ])
    }

    /// Synchronizes the active platform configuration stored in ``configManager`` 
    /// to the underlying Rust Core ``rustEngineState`` instance.
    ///
    /// This method maps every individual geolocation, motion, network, geofencing,
    /// persistence, audit, database encryption, and device attestation property 
    /// from the native iOS ConfigManager directly into a UniFFI-exported 
    /// ``EngineConfig`` record, ensuring the Rust core engine maintains perfect 
    /// configuration parity with the platform layer.
    private func syncConfigToRustFlat() {
        guard let state = rustEngineState else { return }
        do {
            let newConfig = EngineConfig(
                geo: GeoConfig(
                    desiredAccuracy: Int32(configManager.getDesiredAccuracy()),
                    distanceFilter: configManager.getDistanceFilter(),
                    stationaryRadius: configManager.getStationaryRadius(),
                    locationTimeout: Int32(configManager.getLocationTimeout()),
                    disableElasticity: configManager.getDisableElasticity(),
                    elasticityMultiplier: configManager.getElasticityMultiplier(),
                    enableAdaptiveMode: configManager.getEnableAdaptiveMode(),
                    enableTimestampMeta: configManager.getEnableTimestampMeta(),
                    enableSparseUpdates: configManager.getEnableSparseUpdates(),
                    sparseDistanceThreshold: configManager.getSparseDistanceThreshold(),
                    stopAfterElapsedMinutes: Int32(configManager.getStopAfterElapsedMinutes()),
                    maxMonitoredGeofences: Int32(configManager.getMaxMonitoredGeofences()),
                    periodicLocationInterval: Int32(configManager.getPeriodicLocationInterval()),
                    periodicDesiredAccuracy: Int32(configManager.getPeriodicDesiredAccuracy()),
                    sparseMaxIdleSeconds: Int32(configManager.getSparseMaxIdleSeconds()),
                    batteryBudgetPerHour: configManager.getBatteryBudgetPerHour(),
                    enableDeadReckoning: configManager.getEnableDeadReckoning(),
                    deadReckoningActivationDelay: Int32(configManager.getDeadReckoningActivationDelay()),
                    deadReckoningMaxDuration: Int32(configManager.getDeadReckoningMaxDuration()),
                    resolveAddress: configManager.getResolveAddress()
                ),
                motion: MotionConfig(
                    stopTimeout: Int32(configManager.getStopTimeout()),
                    motionTriggerDelay: Int32(configManager.getMotionTriggerDelay()),
                    disableMotionActivityUpdates: configManager.getDisableMotionActivityUpdates(),
                    disableStopDetection: configManager.getDisableStopDetection(),
                    shakeThreshold: configManager.getShakeThreshold(),
                    isMoving: configManager.getIsMoving(),
                    activityRecognitionInterval: Int32(configManager.getActivityRecognitionInterval()),
                    minimumActivityRecognitionConfidence: Int32(configManager.getMinimumActivityRecognitionConfidence()),
                    stopDetectionDelay: Int32(configManager.getStopDetectionDelay()),
                    stopOnStationary: configManager.getStopOnStationary(),
                    stationaryRadius: configManager.getStationaryRadius(),
                    useSignificantChangesOnly: configManager.getUseSignificantChangesOnly(),
                    stillThreshold: configManager.getStillThreshold(),
                    stillSampleCount: Int32(configManager.getStillSampleCount()),
                    motionDetectionMode: Int32(configManager.getMotionDetectionMode().rawValue),
                    speedMovingThreshold: configManager.getSpeedMovingThreshold(),
                    speedStationaryDelay: Int32(configManager.getSpeedStationaryDelay()),
                    stationaryTrackingMode: Int32(configManager.getStationaryTrackingMode().rawValue),
                    stationaryPeriodicInterval: Int32(configManager.getStationaryPeriodicInterval()),
                    stationaryPeriodicAccuracy: Int32(configManager.getStationaryPeriodicAccuracy()),
                    speedWakeConfirmCount: Int32(configManager.getSpeedWakeConfirmCount())
                ),
                http: HttpConfig(
                    url: configManager.getUrl().isEmpty ? nil : configManager.getUrl(),
                    method: configManager.getHttpMethod().uppercased() == "PUT" ? 1 : 0,
                    headers: configManager.getMergedHttpHeaders(),
                    batchSync: configManager.getBatchSync(),
                    maxBatchSize: Int32(configManager.getMaxBatchSize()),
                    autoSync: configManager.getAutoSync(),
                    maxRetries: Int32(configManager.getMaxRetries()),
                    retryBackoffBase: Int32(configManager.getRetryBackoffBase()),
                    retryBackoffCap: Int32(configManager.getRetryBackoffCap()),
                    autoSyncDelay: Int32(configManager.getAutoSyncDelay()),
                    sslPinningCertificates: configManager.getSslPinningCertificates().isEmpty ? nil : configManager.getSslPinningCertificates(),
                    sslPinningFingerprints: configManager.getSslPinningFingerprints().isEmpty ? nil : configManager.getSslPinningFingerprints(),
                    httpRootProperty: configManager.getHttpRootProperty(),
                    params: configManager.getHttpParams().mapValues { "\($0)" },
                    extras: configManager.getHttpExtras().mapValues { "\($0)" },
                    disableAutoSyncOnCellular: configManager.getDisableAutoSyncOnCellular(),
                    enableDeltaCompression: configManager.getEnableDeltaCompression(),
                    deltaCoordinatePrecision: Int32(configManager.getDeltaCoordinatePrecision()),
                    locationsOrderDirection: Int32(configManager.getLocationsOrderDirection())
                ),
                geofence: GeofenceConfig(
                    geofenceInitialTrigger: configManager.getGeofenceInitialTrigger(),
                    geofenceInitialTriggerEntry: configManager.getGeofenceInitialTriggerEntry(),
                    geofenceProximityRadius: Int32(configManager.getGeofenceProximityRadius())
                ),
                persistence: PersistenceConfig(
                    maxDaysToPersist: Int32(configManager.getMaxDaysToPersist()),
                    maxRecordsToPersist: Int32(configManager.getMaxRecordsToPersist())
                ),
                audit: AuditConfig(
                    enabled: configManager.getAuditEnabled()
                ),
                security: SecurityConfig(
                    encryptDatabase: configManager.getEncryptDatabase()
                ),
                attestation: AttestationConfig(
                    enabled: configManager.getAttestationEnabled()
                )
            )
            try state.updateConfig(newConfig: newConfig)
            NSLog("Tracelet: Successfully synchronized ConfigManager state to Rust Core.")
        } catch {
            NSLog("Tracelet: Failed to sync config to Rust Core: \(error)")
        }
    }
}

private struct RustDatabaseSinkWrapper: LocationDataSink {
    weak var sdk: TraceletSdk?

    func insertLocation(_ location: [String: Any]) -> String {
        return sdk?.insertLocation(location) ?? ""
    }
}

