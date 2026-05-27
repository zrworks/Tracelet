package com.ikolvi.tracelet.sdk.receiver

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
        Log.d(TAG, "onReceive: Activity transition broadcast received")

        try {
            val sdk = TraceletSdk.getInstance(context)
            if (sdk.isReady) {
                Log.d(TAG, "Forwarding transition event to active SDK MotionDetector")
                sdk.motionDetector.handleTransitionIntent(intent)
            } else {
                Log.d(TAG, "SDK not ready — attempting to route transition event to boot-mode MotionDetector")
                val bootMotionDetector = LocationService.bootMotionDetector
                if (bootMotionDetector != null) {
                    bootMotionDetector.handleTransitionIntent(intent)
                } else {
                    Log.w(TAG, "No active or boot-mode MotionDetector found to handle transition")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error processing activity transition: ${e.message}", e)
        }
    }
}
