package com.ikolvi.tracelet.sdk.motion

import android.content.Context
import com.ikolvi.tracelet.sdk.ConfigManager
import com.ikolvi.tracelet.sdk.TraceletEventSender
import com.ikolvi.tracelet.sdk.location.LocationEngine
import com.ikolvi.tracelet.sdk.service.LocationService
import com.ikolvi.tracelet.sdk.location.PeriodicLocationWorker
import com.ikolvi.tracelet.sdk.model.TrackingMode
import com.ikolvi.tracelet.sdk.StateManager
import com.ikolvi.tracelet.sdk.util.TraceletLogger

/**
 * Coordinates between MotionDetector (Accelerometer/ActivityRecognition) and
 * SpeedMotionManager (GPS Speed) to implement the 'smart' MotionDetectionMode.
 *
 * Implements a Logical OR:
 * If EITHER sensor detects motion, the app stays in continuous tracking mode.
 * If BOTH sensors detect stationary, the app stops continuous tracking and relies
 * on Geofences/periodic wakeups to save battery.
 */
class SmartMotionCoordinator(
    private val context: Context,
    private val configManager: ConfigManager,
    private val stateManager: StateManager,
    var events: TraceletEventSender,
    private val locationEngine: LocationEngine,
    private val motionDetector: MotionDetector,
    private val logger: TraceletLogger,
) {
    private val coreCoordinator = uniffi.tracelet_core.SmartMotionCoordinator(
        configManager.getStationaryTrackingMode() == com.ikolvi.tracelet.sdk.model.StationaryTrackingMode.GEOFENCES
    )

    val isAccelMoving: Boolean
        get() = coreCoordinator.isAccelMoving()

    val isSpeedMoving: Boolean
        get() = coreCoordinator.isSpeedMoving()

    /**
     * Called when the accelerometer/activity recognition state changes.
     * Returns the action taken by the coordinator so the caller can
     * conditionally reset the speed state machine on real wake-ups.
     */
    fun onAccelStateChange(isMoving: Boolean): uniffi.tracelet_core.CoordinatorAction {
        val action = coreCoordinator.onAccelStateChange(isMoving)
        logger.debug("SmartMotionCoordinator: onAccelStateChange -> isMoving=$isMoving, action=$action, isAccelMoving=${coreCoordinator.isAccelMoving()}, isSpeedMoving=${coreCoordinator.isSpeedMoving()}")
        handleAction(action)
        return action
    }

    /**
     * Called when the GPS speed state changes.
     */
    fun onSpeedStateChange(isMoving: Boolean) {
        if (!isMoving && coreCoordinator.isAccelMoving()) {
            // Speed SM declared stationary (30s of speed < 1.5 m/s) but accel
            // still reports moving. This could be:
            //   a) Hand tremor while physically still (GPS speed ≈ 0 m/s)
            //   b) Walking slowly (GPS speed 0.3-0.5 m/s, below speed threshold)
            // Only override accel for case (a) — truly near-zero GPS speed.
            // For case (b), trust the accelerometer: the user IS moving.
            val lastSpeed = locationEngine.getLastLocation()?.speed ?: 0f
            if (lastSpeed <= 0.15f) {
                logger.info("SmartMotionCoordinator: GPS speed near zero (${lastSpeed} m/s) but accel moving — overriding accel to false (hand tremor).")
                coreCoordinator.onAccelStateChange(false)
            } else {
                logger.info("SmartMotionCoordinator: GPS speed ${lastSpeed} m/s suggests walking — trusting accel, staying continuous.")
            }
        }
        val action = coreCoordinator.onSpeedStateChange(isMoving)
        logger.debug("SmartMotionCoordinator: onSpeedStateChange -> isMoving=$isMoving, action=$action, isAccelMoving=${coreCoordinator.isAccelMoving()}, isSpeedMoving=${coreCoordinator.isSpeedMoving()}")
        handleAction(action)
    }

    /**
     * Called when the user manually forces the pace via changePace().
     */
    fun onManualPaceChange(isMoving: Boolean) {
        val accelAction = coreCoordinator.onAccelStateChange(isMoving)
        handleAction(accelAction)
        
        val speedAction = coreCoordinator.onSpeedStateChange(isMoving)
        handleAction(speedAction)
    }
    
    /**
     * Synchronize the Rust core mode with the native StateManager on startup or mode change.
     */
    fun syncCurrentMode() {
        val mode = when (stateManager.trackingMode) {
            TrackingMode.CONTINUOUS -> uniffi.tracelet_core.TrackingMode.CONTINUOUS
            TrackingMode.GEOFENCES -> uniffi.tracelet_core.TrackingMode.STATIONARY_GEOFENCES
            TrackingMode.PERIODIC -> uniffi.tracelet_core.TrackingMode.STATIONARY_PERIODIC
            else -> uniffi.tracelet_core.TrackingMode.CONTINUOUS
        }
        coreCoordinator.setCurrentMode(mode)
        coreCoordinator.setUseGeofencesWhenStationary(
            configManager.getStationaryTrackingMode() == com.ikolvi.tracelet.sdk.model.StationaryTrackingMode.GEOFENCES
        )
    }

    private fun handleAction(action: uniffi.tracelet_core.CoordinatorAction) {
        when (action) {
            uniffi.tracelet_core.CoordinatorAction.SWITCH_TO_CONTINUOUS -> {
                logger.info("SmartMotionCoordinator: Switching to CONTINUOUS")
                val useForeground = configManager.isForegroundServiceEnabled()
                logger.debug("SmartMotionCoordinator: SWITCH_TO_CONTINUOUS — useForeground=$useForeground")
                if (useForeground) {
                    LocationService.switchToContinuous(locationEngine, stateManager)
                } else {
                    PeriodicLocationWorker.cancel(context)
                    locationEngine.start()
                }
                stateManager.isMoving = true
                logger.debug("SmartMotionCoordinator: SWITCH_TO_CONTINUOUS — calling motionDetector.onManualPaceChange(true)")
                motionDetector.onManualPaceChange(true)
                
                // Dispatch motionchange event
                val locationMap = locationEngine.getLastLocation()?.let {
                    locationEngine.enrichLocation(it, "motionchange")
                } ?: mapOf("is_moving" to true)
                events.sendMotionChange(locationMap)
            }
            uniffi.tracelet_core.CoordinatorAction.SWITCH_TO_STATIONARY_GEOFENCES -> {
                logger.info("SmartMotionCoordinator: Switching to STATIONARY_GEOFENCES")
                val useForeground = configManager.isForegroundServiceEnabled()
                if (useForeground) {
                    LocationService.switchToStationaryGeofences(locationEngine, stateManager)
                } else {
                    locationEngine.stop()
                }
                stateManager.isMoving = false
                motionDetector.onManualPaceChange(false)
                
                val locationMap = locationEngine.getLastLocation()?.let {
                    locationEngine.enrichLocation(it, "motionchange")
                } ?: mapOf("is_moving" to false)
                events.sendMotionChange(locationMap)
            }
            uniffi.tracelet_core.CoordinatorAction.SWITCH_TO_STATIONARY_PERIODIC -> {
                logger.info("SmartMotionCoordinator: Switching to STATIONARY_PERIODIC")
                val useForeground = configManager.isForegroundServiceEnabled()
                logger.debug("SmartMotionCoordinator: SWITCH_TO_STATIONARY_PERIODIC — useForeground=$useForeground")
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
                    val interval = configManager.getStationaryPeriodicInterval()
                    
                    val useExactAlarms = configManager.getPeriodicUseExactAlarms() || interval < 900
                    if (useExactAlarms) {
                        PeriodicLocationWorker.scheduleOneTime(context)
                        PeriodicLocationWorker.scheduleExactAlarm(context, interval)
                    } else {
                        PeriodicLocationWorker.schedule(context, interval)
                    }
                }
                stateManager.isMoving = false
                logger.debug("SmartMotionCoordinator: SWITCH_TO_STATIONARY_PERIODIC — calling motionDetector.onManualPaceChange(false)")
                motionDetector.onManualPaceChange(false)
                
                val locationMap = locationEngine.getLastLocation()?.let {
                    locationEngine.enrichLocation(it, "motionchange")
                } ?: mapOf("is_moving" to false)
                events.sendMotionChange(locationMap)
            }
            uniffi.tracelet_core.CoordinatorAction.NONE -> {
                // Do nothing
            }
        }
    }
}
