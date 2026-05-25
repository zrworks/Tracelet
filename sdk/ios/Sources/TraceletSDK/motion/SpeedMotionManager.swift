import Foundation

/// Delegate that the `SpeedMotionManager` calls to switch the location engine
/// between continuous and stationary modes and to emit Pigeon events.
public protocol SpeedMotionDelegate: AnyObject {
    func switchToContinuous()
    func switchToStationaryPeriodic()
    func switchToStationaryGeofences()
    /// Emit a speed-motion state change event to Dart.
    func emitSpeedMotionEvent(state: Int, previousState: Int, trackingMode: Int)
}

/// GPS-speed-based motion detection state machine.
///
/// Drives MOVING -> SLOWING -> STATIONARY transitions based on
/// `CLLocation.speed` from each location fix. Designed for vehicle tracking
/// where accelerometer-based stop detection is unreliable (phone on a smooth
/// dashboard reads near-zero even at highway speed).
///
/// This class is a peer to `MotionDetector` (not a branch inside it).
/// Inputs are location fixes, not sensor streams.
///
/// ## State Machine
///
/// ```
/// MOVING (continuous) --speed<threshold--> SLOWING (continuous)
///    ^                                          |
///    |                                   delay elapsed
///    |                                          v
///    +--wakeConfirmCount fixes>=threshold-- STATIONARY (periodic or geofences)
/// ```
public final class SpeedMotionManager {

    // MARK: - State

    public enum SpeedMotionState: Int {
        case moving = 0
        case slowing = 1
        case stationary = 2
    }

    public private(set) var state: SpeedMotionState = .moving

    /// Consecutive low-speed samples while SLOWING.
    public private(set) var lowSpeedCount: Int = 0

    /// Consecutive wake-speed samples while STATIONARY.
    public private(set) var wakeCount: Int = 0

    /// Timestamp of the first low-speed sample that initiated the current
    /// SLOWING phase. Used for elapsed-time calculation.
    private var slowingStartTime: TimeInterval = 0

    /// Timestamp of the last `onLocation` call, for approximate inter-fix interval.
    private var lastFixTime: TimeInterval = 0

    private var isRunning = false

    // MARK: - Config

    /// Speed (m/s) below which the device is considered not moving.
    public var speedMovingThreshold: Double = 1.5

    /// Seconds of sustained low speed before transitioning to STATIONARY.
    public var speedStationaryDelay: Int = 180

    /// Stationary tracking mode: periodic or geofences.
    public var stationaryTrackingMode: StationaryTrackingMode = .periodic

    /// Interval for periodic one-shot fixes in stationary mode (seconds).
    public var stationaryPeriodicInterval: Int = 120

    /// Number of consecutive high-speed fixes required to wake from STATIONARY.
    public var speedWakeConfirmCount: Int = 1

    // MARK: - Dependencies

    public weak var delegate: SpeedMotionDelegate?

    private let stateManager: StateManager

    // MARK: - Init

    public init(stateManager: StateManager) {
        self.stateManager = stateManager
    }

    // MARK: - Lifecycle

    /// Start the speed motion manager. Loads persisted state from StateManager.
    public func start(forceMoving: Bool = false) {
        guard !isRunning else { return }
        isRunning = true

        // Validate config bounds
        if speedStationaryDelay < 0 {
            NSLog("[SpeedMotion] WARNING: speedStationaryDelay was %d, clamping to 0", speedStationaryDelay)
            speedStationaryDelay = 0
        } else if speedStationaryDelay == 0 {
            NSLog("[SpeedMotion] WARNING: speedStationaryDelay is 0 — device will transition to STATIONARY immediately after a single low-speed fix")
        }
        if speedWakeConfirmCount < 1 {
            NSLog("[SpeedMotion] WARNING: speedWakeConfirmCount was %d, clamping to 1", speedWakeConfirmCount)
            speedWakeConfirmCount = 1
        }

        // Restore persisted state
        if let persisted = stateManager.speedMotionState,
           let restored = SpeedMotionState(rawValue: persisted) {
            state = restored
        } else {
            state = .moving
        }
        lowSpeedCount = stateManager.speedLowCount
        wakeCount = stateManager.speedWakeCount
        slowingStartTime = stateManager.speedLastTransition

        if forceMoving {
            state = .moving
            lowSpeedCount = 0
            wakeCount = 0
            stateManager.speedMotionState = state.rawValue
            stateManager.speedLowCount = 0
            stateManager.speedWakeCount = 0
            stateManager.isMoving = true
            NSLog("[SpeedMotion] start() — forced to MOVING state")
        } else {
            NSLog("[SpeedMotion] start: restored state=%d, lowSpeedCount=%d, wakeCount=%d",
                  state.rawValue, lowSpeedCount, wakeCount)
            
            if state == .stationary {
                switchToStationary()
            }
        }
    }

    /// Stop the speed motion manager and reset runtime counters.
    public func stop() {
        guard isRunning else { return }
        isRunning = false
        NSLog("[SpeedMotion] stop")
    }

    /// Handle manual pace changes triggered by the caller.
    public func onManualPaceChange(isMoving: Bool) {
        guard isRunning else { return }
        NSLog("[SpeedMotion] onManualPaceChange(isMoving=\(isMoving))")
        if isMoving {
            lowSpeedCount = 0
            wakeCount = 0
            stopSlowingTimer()
            let previousState = state
            state = .moving
            
            if state != previousState {
                persistState()
                emitEvent(previous: previousState, current: state)
            }
            delegate?.switchToContinuous()
        } else {
            lowSpeedCount = 0
            wakeCount = 0
            stopSlowingTimer()
            let previousState = state
            state = .stationary
            
            if state != previousState {
                persistState()
                emitEvent(previous: previousState, current: state)
            }
            switchToStationary()
        }
    }

    // MARK: - Location Feed

    /// Drive state machine transitions from a location fix speed.
    ///
    /// - Parameter speed: `CLLocation.speed` in m/s. Negative values (invalid)
    ///   are treated as 0 (stationary).
    public func onLocation(speed: Double) {
        guard isRunning else { return }

        let now = ProcessInfo.processInfo.systemUptime
        let effectiveSpeed = max(speed, 0)
        let previousState = state

        switch state {
        case .moving:
            handleMoving(speed: effectiveSpeed, now: now)
        case .slowing:
            handleSlowing(speed: effectiveSpeed, now: now)
        case .stationary:
            handleStationary(speed: effectiveSpeed, now: now)
        }

        lastFixTime = now

        // Persist and emit if state changed
        if state != previousState {
            persistState()
            emitEvent(previous: previousState, current: state)
        }
    }

    // MARK: - State Handlers

    private var slowingTimerWorkItem: DispatchWorkItem?

    private func handleMoving(speed: Double, now: TimeInterval) {
        if speed < speedMovingThreshold {
            let previousState = state
            state = .slowing
            lowSpeedCount = 1
            wakeCount = 0
            slowingStartTime = now
            NSLog("[SpeedMotion] MOVING -> SLOWING (speed=%.2f < threshold=%.2f)",
                  speed, speedMovingThreshold)
            startSlowingTimer()
            
            if state != previousState {
                persistState()
                emitEvent(previous: previousState, current: state)
            }
        }
    }

    private func startSlowingTimer() {
        stopSlowingTimer()
        let delay = TimeInterval(speedStationaryDelay)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                if self.state == .slowing {
                    NSLog("[SpeedMotion] SLOWING timer expired -> STATIONARY")
                    let previousState = self.state
                    self.state = .stationary
                    self.wakeCount = 0
                    self.lowSpeedCount = 0
                    self.switchToStationary()
                    
                    if self.state != previousState {
                        self.persistState()
                        self.emitEvent(previous: previousState, current: self.state)
                    }
                }
            }
            self.slowingTimerWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }

    private func stopSlowingTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.slowingTimerWorkItem?.cancel()
            self?.slowingTimerWorkItem = nil
        }
    }

    private func switchToStationary() {
        if stationaryTrackingMode == .geofences {
            delegate?.switchToStationaryGeofences()
        } else {
            delegate?.switchToStationaryPeriodic()
        }
    }

    private func handleSlowing(speed: Double, now: TimeInterval) {
        if speed >= speedMovingThreshold {
            // Back to moving
            let previousState = state
            state = .moving
            lowSpeedCount = 0
            stopSlowingTimer()
            NSLog("[SpeedMotion] SLOWING -> MOVING (speed=%.2f >= threshold=%.2f)",
                  speed, speedMovingThreshold)
                  
            if state != previousState {
                persistState()
                emitEvent(previous: previousState, current: state)
            }
            return
        }

        // Still slow — increment and check elapsed time
        lowSpeedCount += 1
        let elapsed = now - slowingStartTime
        if elapsed >= Double(speedStationaryDelay) {
            let previousState = state
            state = .stationary
            wakeCount = 0
            stopSlowingTimer()
            NSLog("[SpeedMotion] SLOWING -> STATIONARY (elapsed=%.0fs >= delay=%ds, lowCount=%d)",
                  elapsed, speedStationaryDelay, lowSpeedCount)

            switchToStationary()
            
            if state != previousState {
                persistState()
                emitEvent(previous: previousState, current: state)
            }
        }
    }

    private func handleStationary(speed: Double, now: TimeInterval) {
        if speed >= speedMovingThreshold {
            wakeCount += 1
            NSLog("[SpeedMotion] STATIONARY: wake fix (speed=%.2f, wakeCount=%d/%d)",
                  speed, wakeCount, speedWakeConfirmCount)
            if wakeCount >= speedWakeConfirmCount {
                state = .moving
                lowSpeedCount = 0
                wakeCount = 0
                NSLog("[SpeedMotion] STATIONARY -> MOVING (wakeConfirm reached)")
                delegate?.switchToContinuous()
            }
        } else {
            // Reset wake count on low-speed fix
            if wakeCount > 0 {
                NSLog("[SpeedMotion] STATIONARY: reset wakeCount (speed=%.2f < threshold)",
                      speed)
            }
            wakeCount = 0
        }
    }

    // MARK: - Persistence

    private func persistState() {
        stateManager.speedMotionState = state.rawValue
        stateManager.speedLowCount = lowSpeedCount
        stateManager.speedWakeCount = wakeCount
        stateManager.speedLastTransition = slowingStartTime
    }

    // MARK: - Event Emission

    private func emitEvent(previous: SpeedMotionState, current: SpeedMotionState) {
        let trackingMode: Int = (current == .stationary)
            ? (stationaryTrackingMode == .geofences ? 1 : 2) // geofences=1, periodic=2
            : 0 // continuous=0
        
        delegate?.emitSpeedMotionEvent(
            state: current.rawValue,
            previousState: previous.rawValue,
            trackingMode: trackingMode
        )
    }

    // MARK: - Config Loading

    /// Convenience to load config from a MotionConfig dictionary.
    public func loadConfig(from motionConfig: [String: Any]) {
        if let threshold = motionConfig["speedMovingThreshold"] as? Double {
            speedMovingThreshold = threshold
        }
        if let delay = motionConfig["speedStationaryDelay"] as? Int {
            speedStationaryDelay = delay
        }
        if let val = motionConfig["stationaryTrackingMode"] as? Int, let mode = StationaryTrackingMode(rawValue: val) {
            stationaryTrackingMode = mode
        }
        if let interval = motionConfig["stationaryPeriodicInterval"] as? Int {
            stationaryPeriodicInterval = interval
        }
        if let count = motionConfig["speedWakeConfirmCount"] as? Int {
            speedWakeConfirmCount = count
        }
    }
}
