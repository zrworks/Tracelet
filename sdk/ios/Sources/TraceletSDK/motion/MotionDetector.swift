import CoreMotion
import Foundation

/// Motion detection engine with two operating modes:
///
/// ## Full mode (default)
/// Uses `CMMotionActivityManager` for rich activity classification (walking,
/// running, cycling, automotive, stationary) plus `CMPedometer` as a backup
/// moving-detector. Requires the Motion & Fitness permission
/// (`NSMotionUsageDescription`).
///
/// ## Accelerometer-only mode (`disableMotionActivityUpdates = true`)
/// Uses `CMMotionManager` raw accelerometer data for basic stationary↔moving
/// detection. **No permissions required.** Does not provide activity
/// classification — only fires `onMotionStateChanged(isMoving)`.
///
/// Transition flow (both modes):
/// 1. MOVING → sensor detects stillness → start stopTimeout countdown
/// 2. After stopTimeout elapses → declare STATIONARY → fire onMotionChange(false)
/// 3. In stationary: listen for shake → declare MOVING → fire onMotionChange(true)
public final class MotionDetector {
    private let configManager: ConfigManager
    private let stateManager: StateManager
    private let eventDispatcher: TraceletEventSending

    // Full mode (permission-required) — lazily initialized so they are
    // never allocated in accelerometer-only mode (I-L1).
    private lazy var activityManager = CMMotionActivityManager()
    private lazy var pedometer = CMPedometer()

    private let motionManager = CMMotionManager()
    
    private lazy var accelQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.tracelet.accelerometer.fallback"
        queue.qualityOfService = .utility
        return queue
    }()

    private var isRunning = false
    private var isFullModeStarted = false
    private var stopTimerWorkItem: DispatchWorkItem?
    private var currentActivity: String = "unknown"
    private var currentConfidence: Int = -1

    /// Consecutive low-acceleration samples before triggering stillness.
    /// At 10Hz (accelerometer update interval), 50 samples ≈ 5 seconds.
    ///
    /// Android uses 25 samples at ~5 Hz (SENSOR_DELAY_NORMAL) ≈ 5 seconds.
    /// Both platforms target a ~5 second dwell window to balance fast
    /// stationary detection with avoiding false positives from brief stops.
    ///
    /// - SeeAlso: Android `MotionDetector.STILL_SAMPLE_COUNT` (25 at ~5 Hz ≈ 5s)
    private static let stillSampleCount = 50

    /// Acceleration magnitude (gravity-subtracted) below which a sample is "still".
    ///
    /// Lower than the Android equivalent (0.4) because iOS `CMMotionManager`
    /// reports gravity-subtracted user-acceleration directly with higher
    /// precision. Android uses raw accelerometer with gravity included,
    /// producing noisier residuals after gravity subtraction.
    ///
    /// - SeeAlso: Android `MotionDetector.STILL_THRESHOLD` (0.4)
    private static let stillThreshold: Double = 0.15

    /// Acceleration magnitude (gravity-subtracted) above which a sample is "shake".
    ///
    /// Lower than the Android equivalent (2.5) for the same reason:
    /// CoreMotion provides clean gravity-subtracted values, so a smaller
    /// threshold reliably detects movement without false positives.
    ///
    /// - SeeAlso: Android `MotionDetector.SHAKE_THRESHOLD` (2.5)
    private static let shakeThreshold: Double = 0.35

    private var consecutiveStillSamples = 0

    /// Called when motion state changes (isMoving).
    public var onMotionStateChanged: ((Bool) -> Void)?

    /// Called when stopOnStationary fires — requests full tracking stop.
    public var onStopRequested: (() -> Void)?

    /// Called when the stopTimeout countdown begins.
    public var onStopTimeoutStarted: (() -> Void)?

    /// Called when the stopTimeout countdown is cancelled or finishes.
    public var onStopTimeoutCancelled: (() -> Void)?

    /// Whether operating in accelerometer-only (permission-free) mode.
    private var isAccelerometerOnlyMode: Bool {
        configManager.getDisableMotionActivityUpdates()
    }

    public init(configManager: ConfigManager,
         stateManager: StateManager,
         eventDispatcher: TraceletEventSending) {
        self.configManager = configManager
        self.stateManager = stateManager
        self.eventDispatcher = eventDispatcher
    }

    // MARK: - Start / Stop

    public func start() {
        guard !isRunning else { return }
        isRunning = true

        if isAccelerometerOnlyMode {
            startAccelerometerOnlyMode()
        } else {
            startFullMode()
        }
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false

        if isFullModeStarted {
            // Full mode cleanup
            activityManager.stopActivityUpdates()
            pedometer.stopUpdates()
            isFullModeStarted = false
        }

        // Accelerometer-only mode cleanup
        motionManager.stopAccelerometerUpdates()

        // Shared cleanup
        if stopTimerWorkItem != nil {
            stopTimerWorkItem?.cancel()
            stopTimerWorkItem = nil
            onStopTimeoutCancelled?()
        }
        consecutiveStillSamples = 0
    }

    // MARK: - Full mode (CMMotionActivityManager + CMPedometer)

    private func startFullMode() {
        guard CMMotionActivityManager.isActivityAvailable() else {
            NSLog("[Tracelet] Motion activity not available — falling back to accelerometer-only")
            startAccelerometerOnlyMode()
            return
        }

        isFullModeStarted = true

        activityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self = self, let activity = activity else { return }
            self.handleActivityUpdate(activity)
        }

        // Pedometer backup: step data means the user is walking
        if CMPedometer.isStepCountingAvailable() {
            pedometer.startUpdates(from: Date()) { [weak self] data, _ in
                guard let self = self, data != nil else { return }
                if !self.stateManager.isMoving {
                    self.triggerMotionChange(isMoving: true)
                }
            }
        }

        // Accelerometer fallback for stillness and shake detection
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 1.0 / 10.0
            consecutiveStillSamples = 0
            motionManager.startAccelerometerUpdates(to: self.accelQueue) { [weak self] data, error in
                guard let self = self, let data = data, error == nil else { return }
                self.handleAccelerometerData(data)
            }
            NSLog("[Tracelet] Accelerometer fallback started (threshold=%.3f, samples=%d)",
                  configManager.getStillThreshold(), configManager.getStillSampleCount())
        }
    }

    // MARK: - Accelerometer-only mode (no permission required)

    /// Start permission-free motion detection using raw accelerometer data.
    ///
    /// - Moving state: monitors for sustained stillness to trigger stop-timeout.
    /// - Stationary state: monitors for shake to re-declare moving.
    ///
    /// Uses `CMMotionManager.startAccelerometerUpdates()` which does NOT require
    /// `NSMotionUsageDescription` — it accesses raw hardware sensor data only.
    private func startAccelerometerOnlyMode() {
        NSLog("[Tracelet] Starting accelerometer-only mode (no Motion & Fitness permission)")

        guard motionManager.isAccelerometerAvailable else {
            NSLog("[Tracelet] Accelerometer not available on this device")
            return
        }

        // 10Hz is sufficient for motion detection and far more battery-
        // efficient than 50Hz. At 50Hz the CPU wakes 50×/sec for negligible
        // detection improvement (I-H1).
        motionManager.accelerometerUpdateInterval = 1.0 / 10.0
        consecutiveStillSamples = 0

        // Deliver to a background queue to avoid blocking the main thread.
        motionManager.startAccelerometerUpdates(to: self.accelQueue) { [weak self] data, error in
            guard let self = self, let data = data, error == nil else { return }
            self.handleAccelerometerData(data)
        }
    }

    private func handleAccelerometerData(_ data: CMAccelerometerData) {
        handleAcceleration(data.acceleration)
    }

    // Internal for testing
    internal func handleAcceleration(_ acc: CMAcceleration) {
        // Compute magnitude and subtract gravity (~1g)
        let magnitude = sqrt(acc.x * acc.x + acc.y * acc.y + acc.z * acc.z) - 1.0

        if stateManager.isMoving {
            // Currently moving — detect sustained stillness
            if configManager.getDisableStopDetection() { return }

            if abs(magnitude) < configManager.getStillThreshold() {
                consecutiveStillSamples += 1
                if consecutiveStillSamples == configManager.getStillSampleCount() {
                    // Sustained stillness — start stop-timeout countdown
                    NSLog("[Tracelet-Motion] Accelerometer detected sustained stillness (%d samples), starting stop-timeout",
                          consecutiveStillSamples)
                    // Do NOT stop accelerometer updates so we can abort if motion resumes!
                    startStopTimeoutCountdown()
                }
            } else {
                if consecutiveStillSamples >= configManager.getStillSampleCount() {
                    NSLog("[Tracelet-Motion] Accelerometer broke stillness — aborting stop-timeout countdown")
                    handleMovingDetected()
                }
                consecutiveStillSamples = 0
            }
        } else {
            // Currently stationary — detect shake/movement
            if abs(magnitude) > configManager.getShakeThreshold() {
                NSLog("[Tracelet-Motion] Accelerometer detected SHAKE (magnitude: %.2f), triggering moving", abs(magnitude))
                motionManager.stopAccelerometerUpdates()
                handleMovingDetected()
            }
        }
    }

    // MARK: - Motion permission

    /// Returns the current motion authorization status without triggering any dialog.
    ///
    /// Status codes match the Dart `AuthorizationStatus` enum:
    /// - `0` notDetermined — never asked
    /// - `3` always (authorized)
    /// - `4` deniedForever — permanently denied / restricted
    ///
    /// When `disableMotionActivityUpdates` is `true`, always returns `3` (granted)
    /// because the accelerometer-only mode requires no permission.
    public func getMotionAuthorizationStatus() -> Int {
        // Accelerometer-only mode doesn't need any permission
        if configManager.getDisableMotionActivityUpdates() {
            return 3
        }

        guard CMMotionActivityManager.isActivityAvailable() else {
            return 3 // Not available — treat as "no permission needed"
        }
        let status = CMMotionActivityManager.authorizationStatus()
        switch status {
        case .notDetermined: return 0
        case .restricted:    return 4
        case .denied:        return 4
        case .authorized:    return 3
        @unknown default:    return 0
        }
    }

    /// Triggers the OS Motion & Fitness permission dialog (if notDetermined)
    /// and returns the actual status after the user responds.
    ///
    /// When `disableMotionActivityUpdates` is `true`, returns `3` immediately
    /// without showing any dialog (accelerometer-only mode needs no permission).
    public func requestMotionPermission(callback: @escaping (Int) -> Void) {
        // Accelerometer-only mode doesn't need any permission
        if configManager.getDisableMotionActivityUpdates() {
            callback(3)
            return
        }

        let current = getMotionAuthorizationStatus()
        guard current == 0 else {
            callback(current)
            return
        }

        // Query a tiny time range to trigger the OS dialog
        let now = Date()
        let past = now.addingTimeInterval(-1)
        activityManager.queryActivityStarting(from: past, to: now, to: .main) { [weak self] _, _ in
            let newStatus = self?.getMotionAuthorizationStatus() ?? 3
            callback(newStatus)
        }
    }

    // MARK: - Sensors info

    public func getSensors() -> [String: Any] {
        return [
            "motionActivity": CMMotionActivityManager.isActivityAvailable(),
            "accelerometer": motionManager.isAccelerometerAvailable,
            "gyroscope": motionManager.isGyroAvailable,
            "magnetometer": motionManager.isMagnetometerAvailable,
            "pedometer": CMPedometer.isStepCountingAvailable(),
            "significantMotion": true,
            "platform": "ios",
        ]
    }

    // MARK: - Activity handling (full mode only)

    private func handleActivityUpdate(_ activity: CMMotionActivity) {
        // Motion state detection
        if activity.stationary {
            NSLog("[Tracelet-Motion] handleActivityUpdate: detected STATIONARY activity")
            handleStationaryDetected()
        } else if activity.walking || activity.running || activity.cycling || activity.automotive {
            NSLog("[Tracelet-Motion] handleActivityUpdate: detected MOVING activity (walking:\(activity.walking) running:\(activity.running) cycling:\(activity.cycling) automotive:\(activity.automotive))")
            handleMovingDetected()
        }

        let (type, confidence) = classifyActivity(activity)

        // Apply confidence filter (for the Dart event stream)
        let minConfidence = configManager.getMinimumActivityRecognitionConfidence()
        if confidence < minConfidence { return }

        // Apply activity type filter
        let triggerActivities = configManager.getTriggerActivities()
        if !triggerActivities.isEmpty {
            let allowed = triggerActivities
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            if !allowed.contains(type.lowercased()) && type != "still" { return }
        }

        let prevActivity = currentActivity
        currentActivity = type
        currentConfidence = confidence

        // Dispatch activity change event to Dart
        if type != prevActivity {
            eventDispatcher.sendActivityChange([
                "activity": type,
                "confidence": confidence,
            ])
        }
    }

    private func classifyActivity(_ activity: CMMotionActivity) -> (String, Int) {
        let confidence: Int
        switch activity.confidence {
        case .low: confidence = 25
        case .medium: confidence = 50
        case .high: confidence = 75
        @unknown default: confidence = -1
        }

        if activity.stationary { return ("still", confidence) }
        if activity.walking { return ("walking", confidence) }
        if activity.running { return ("running", confidence) }
        if activity.cycling { return ("on_bicycle", confidence) }
        if activity.automotive { return ("in_vehicle", confidence) }
        return ("unknown", confidence)
    }

    private func handleMovingDetected() {
        if stopTimerWorkItem != nil {
            NSLog("[Tracelet-Motion] handleMovingDetected: Cancelling stopTimerWorkItem due to movement")
            stopTimerWorkItem?.cancel()
            stopTimerWorkItem = nil
            onStopTimeoutCancelled?()
        }

        if !stateManager.isMoving {
            let delay = configManager.getMotionTriggerDelay()
            if delay > 0 {
                NSLog("[Tracelet-Motion] handleMovingDetected: starting moving delay of \(delay)s")
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay)) { [weak self] in
                    self?.triggerMotionChange(isMoving: true)
                }
            } else {
                NSLog("[Tracelet-Motion] handleMovingDetected: triggering isMoving=true immediately")
                triggerMotionChange(isMoving: true)
            }
        } else {
            // Already moving. If the accelerometer was stopped because it previously
            // detected stillness (but the timer was just invalidated by this moving blip),
            // we must restart the accelerometer to continue monitoring for stillness.
            if isRunning {
                motionManager.accelerometerUpdateInterval = 1.0 / 10.0
                consecutiveStillSamples = 0
                if motionManager.isAccelerometerAvailable {
                    motionManager.startAccelerometerUpdates(to: self.accelQueue) { [weak self] data, error in
                        guard let self = self, let data = data, error == nil else { return }
                        self.handleAccelerometerData(data)
                    }
                }
            }
        }
    }

    private func handleStationaryDetected() {
        guard stateManager.isMoving else { return }
        guard !configManager.getDisableStopDetection() else {
            NSLog("[Tracelet-Motion] handleStationaryDetected: stop detection disabled in config")
            return
        }
        NSLog("[Tracelet-Motion] handleStationaryDetected: stationary detected, starting countdown")
        startStopTimeoutCountdown()
    }

    // MARK: - Stop timeout (shared by both modes)

    private func startStopTimeoutCountdown() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.stopTimerWorkItem != nil {
                NSLog("[Tracelet-Motion] startStopTimeoutCountdown: Timer is already running")
                return
            }

            let stopTimeout = self.configManager.getStopTimeout()
            let stopDetectionDelay = self.configManager.getStopDetectionDelay()
            let totalDelay = TimeInterval(stopTimeout * 60 + stopDetectionDelay)
            guard totalDelay > 0 else {
                NSLog("[Tracelet-Motion] startStopTimeoutCountdown: totalDelay <= 0, stopping immediately")
                self.triggerMotionChange(isMoving: false)
                return
            }

            NSLog("[Tracelet-Motion] startStopTimeoutCountdown: Starting timer for \(totalDelay) seconds")
            self.onStopTimeoutStarted?()

            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                NSLog("[Tracelet-Motion] startStopTimeoutCountdown: Timer FIRED! Transitioning to STATIONARY")
                self.onStopTimeoutCancelled?()
                self.triggerMotionChange(isMoving: false)
            }
            self.stopTimerWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay, execute: workItem)
        }
    }

    // MARK: - State transitions

    private func triggerMotionChange(isMoving: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard self.stateManager.isMoving != isMoving else { return }
            self.stateManager.isMoving = isMoving
            self.onMotionStateChanged?(isMoving)

            if !isMoving && self.configManager.getStopOnStationary() {
                self.onStopRequested?()
                return // Full stop — no further monitoring
            }

        if self.isRunning {
            self.motionManager.accelerometerUpdateInterval = 1.0 / 10.0
            self.consecutiveStillSamples = 0
            if self.motionManager.isAccelerometerAvailable {
                // Use a background queue for stillness/shake detection
                self.motionManager.startAccelerometerUpdates(to: self.accelQueue) { [weak self] data, error in
                    guard let self = self, let data = data, error == nil else { return }
                    self.handleAccelerometerData(data)
                }
            }
        }
        }
    }

    /// Re-syncs MotionDetector's sensor state when the tracking mode is manually
    /// changed (e.g. from changePace or SmartMotionCoordinator).
    public func onManualPaceChange(_ isMoving: Bool) {
        if isMoving {
            if stopTimerWorkItem != nil {
                NSLog("[Tracelet-Motion] onManualPaceChange(true): Cancelling stopTimerWorkItem")
                stopTimerWorkItem?.cancel()
                stopTimerWorkItem = nil
                onStopTimeoutCancelled?()
            }
            consecutiveStillSamples = 0
        }
        
        if isRunning {
            motionManager.accelerometerUpdateInterval = 1.0 / 10.0
            consecutiveStillSamples = 0
            if motionManager.isAccelerometerAvailable {
                motionManager.startAccelerometerUpdates(to: self.accelQueue) { [weak self] data, error in
                    guard let self = self, let data = data, error == nil else { return }
                    self.handleAccelerometerData(data)
                }
            }
        }
    }
}
