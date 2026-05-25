import Foundation
import CoreLocation

/// Coordinates between MotionDetector (Accelerometer/ActivityRecognition) and
/// SpeedMotionManager (GPS Speed) to implement the 'smart' MotionDetectionMode.
///
/// Implements a Logical OR:
/// If EITHER sensor detects motion, the app stays in continuous tracking mode.
/// If BOTH sensors detect stationary, the app stops continuous tracking and relies
/// on Geofences/periodic wakeups to save battery.
public class TraceletSmartMotionCoordinator {
    
    private var coreCoordinator: SmartMotionCoordinator?
    
    public var isAccelMoving: Bool { coreCoordinator?.isAccelMoving() ?? false }
    public var isSpeedMoving: Bool { coreCoordinator?.isSpeedMoving() ?? true }
    
    private weak var sdk: TraceletSdk?
    
    public init(sdk: TraceletSdk) {
        self.sdk = sdk
        
        let useGeofences = sdk.configManager?.getStationaryTrackingMode() == .geofences
        self.coreCoordinator = SmartMotionCoordinator(useGeofencesWhenStationary: useGeofences)
    }
    
    /// Synchronize the Rust core mode with the native StateManager on startup or mode change.
    public func syncCurrentMode() {
        guard let stateManager = sdk?.stateManager else { return }
        
        let mode: TrackingMode
        switch stateManager.trackingMode {
        case .continuous:
            mode = .continuous
        case .geofences:
            mode = .stationaryGeofences
        case .periodic:
            mode = .stationaryPeriodic
        }
        
        coreCoordinator?.setCurrentMode(mode: mode)
        coreCoordinator?.setUseGeofencesWhenStationary(useGeofences: sdk?.configManager?.getStationaryTrackingMode() == .geofences)
    }
    
    /// Called when the accelerometer/activity recognition state changes.
    public func onAccelStateChange(isMoving: Bool) {
        guard let action = coreCoordinator?.onAccelStateChange(isMoving: isMoving) else { return }
        NSLog("[Tracelet] SmartMotionCoordinator: onAccelStateChange -> isMoving=\(isMoving), action=\(action)")
        handleAction(action)
    }
    
    /// Called when the GPS speed state changes.
    public func onSpeedStateChange(isMoving: Bool) {
        guard let action = coreCoordinator?.onSpeedStateChange(isMoving: isMoving) else { return }
        NSLog("[Tracelet] SmartMotionCoordinator: onSpeedStateChange -> isMoving=\(isMoving), action=\(action)")
        handleAction(action)
    }
    
    private func handleAction(_ action: CoordinatorAction) {
        guard let sdk = sdk else { return }
        
        switch action {
        case .switchToContinuous:
            NSLog("[Tracelet] SmartMotionCoordinator: Switching to CONTINUOUS")
            sdk.switchToContinuousForce()
            sdk.motionDetector.onManualPaceChange(true)
            
        case .switchToStationaryGeofences:
            NSLog("[Tracelet] SmartMotionCoordinator: Switching to STATIONARY_GEOFENCES")
            sdk.switchToStationaryGeofencesForce()
            sdk.motionDetector.onManualPaceChange(false)
            
        case .switchToStationaryPeriodic:
            NSLog("[Tracelet] SmartMotionCoordinator: Switching to STATIONARY_PERIODIC")
            sdk.switchToStationaryPeriodicForce()
            sdk.motionDetector.onManualPaceChange(false)
            
        case .none:
            break
        }
    }
}
