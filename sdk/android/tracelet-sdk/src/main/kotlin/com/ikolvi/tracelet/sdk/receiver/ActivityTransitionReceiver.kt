package com.ikolvi.tracelet.sdk.receiver
import com.ikolvi.tracelet.sdk.util.TraceletLog

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.ikolvi.tracelet.sdk.TraceletSdk
import com.ikolvi.tracelet.sdk.service.LocationService

/**
 * Static manifest-declared receiver for Activity Recognition Transition updates.
 *
 * Guarantees that Google Play Services transition events are delivered and processed
 * even when the app is backgrounded, sleeping, or in Doze/standby mode, completely
 * bypassing standard background dynamic receiver constraints.
 */
class ActivityTransitionReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "ActivityTransitionRcvr"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent == null || context == null) return
        TraceletLog.debug("onReceive: Activity transition broadcast received")

        try {
            val sdk = TraceletSdk.getInstance(context)
            if (sdk.isReady) {
                TraceletLog.debug("Forwarding transition event to active SDK MotionDetector")
                sdk.motionDetector.handleTransitionIntent(intent)
            } else {
                TraceletLog.debug("SDK not ready — attempting to route transition event to boot-mode MotionDetector")
                val bootMotionDetector = LocationService.bootMotionDetector
                if (bootMotionDetector != null) {
                    bootMotionDetector.handleTransitionIntent(intent)
                } else {
                    TraceletLog.warning("No active or boot-mode MotionDetector found to handle transition")
                    val state = com.ikolvi.tracelet.sdk.StateManager(context)
                    if (state.enabled) {
                        val extractor = com.ikolvi.tracelet.sdk.wrapper.TraceletServices.getInstance(context).getEventExtractor()
                        val result = extractor.extractActivityTransitionResult(intent)
                        if (result != null) {
                            for (event in result.transitionEvents) {
                                // 0 = ENTER, 3 = STILL
                                if (event.transitionType == 0) {
                                    if (event.activityType != 3) {
                                        if (state.trackingMode == com.ikolvi.tracelet.sdk.model.TrackingMode.PERIODIC) {
                                            TraceletLog.debug("Detected moving transition while in killed periodic mode — waking up SDK!")
                                            state.isMoving = true
                                            state.trackingMode = com.ikolvi.tracelet.sdk.model.TrackingMode.CONTINUOUS
                                            LocationService.startFromBoot(context)
                                            break
                                        }
                                    } else {
                                        if (state.trackingMode == com.ikolvi.tracelet.sdk.model.TrackingMode.CONTINUOUS) {
                                            TraceletLog.debug("Detected STILL transition while in killed continuous mode — switching to stationary!")
                                            state.isMoving = false
                                            val configManager = com.ikolvi.tracelet.sdk.ConfigManager.getInstance(context)
                                            val useForeground = configManager.isForegroundServiceEnabled()
                                            
                                            if (configManager.getStationaryTrackingMode() == com.ikolvi.tracelet.sdk.model.StationaryTrackingMode.GEOFENCES) {
                                                state.trackingMode = com.ikolvi.tracelet.sdk.model.TrackingMode.GEOFENCES
                                            } else {
                                                state.trackingMode = com.ikolvi.tracelet.sdk.model.TrackingMode.PERIODIC
                                                val interval = configManager.getStationaryPeriodicInterval()
                                                val useExactAlarms = configManager.getPeriodicUseExactAlarms() || interval < 900
                                                if (useExactAlarms) {
                                                    com.ikolvi.tracelet.sdk.location.PeriodicLocationWorker.scheduleOneTime(context)
                                                    com.ikolvi.tracelet.sdk.location.PeriodicLocationWorker.scheduleExactAlarm(context, interval)
                                                } else {
                                                    com.ikolvi.tracelet.sdk.location.PeriodicLocationWorker.schedule(context, interval)
                                                }
                                            }
                                            
                                            if (useForeground) {
                                                LocationService.startFromBoot(context)
                                            }
                                            break
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            TraceletLog.error("Error processing activity transition: ${e.message}", e)
        }
    }
}
