package com.ikolvi.tracelet.sdk.wrapper

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.android.gms.location.*

class PlayMotionClient(private val context: Context) : TraceletMotionClient {
    private val activityClient = ActivityRecognition.getClient(context)
    private var transitionPendingIntent: PendingIntent? = null

    companion object {
        private const val TAG = "PlayMotionClient"
        const val ACTION_ACTIVITY_TRANSITION = "com.tracelet.ACTION_ACTIVITY_TRANSITION"
    }

    override fun isAvailable(): Boolean = true

    override fun registerActivityTransitions(
        onSuccess: () -> Unit,
        onFailure: (Exception) -> Unit,
        onSecurityException: (SecurityException) -> Unit
    ) {
        val transitions = listOf(
            activityTransition(DetectedActivity.STILL, ActivityTransition.ACTIVITY_TRANSITION_ENTER),
            activityTransition(DetectedActivity.STILL, ActivityTransition.ACTIVITY_TRANSITION_EXIT),
            activityTransition(DetectedActivity.WALKING, ActivityTransition.ACTIVITY_TRANSITION_ENTER),
            activityTransition(DetectedActivity.RUNNING, ActivityTransition.ACTIVITY_TRANSITION_ENTER),
            activityTransition(DetectedActivity.ON_BICYCLE, ActivityTransition.ACTIVITY_TRANSITION_ENTER),
            activityTransition(DetectedActivity.IN_VEHICLE, ActivityTransition.ACTIVITY_TRANSITION_ENTER),
            activityTransition(DetectedActivity.ON_FOOT, ActivityTransition.ACTIVITY_TRANSITION_ENTER),
        )

        val request = ActivityTransitionRequest(transitions)
        val intent = Intent(ACTION_ACTIVITY_TRANSITION).apply {
            setPackage(context.packageName)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        transitionPendingIntent = PendingIntent.getBroadcast(context, 0, intent, flags)

        try {
            activityClient.requestActivityTransitionUpdates(request, transitionPendingIntent!!)
                .addOnSuccessListener {
                    onSuccess()
                }
                .addOnFailureListener { e ->
                    onFailure(e)
                }
        } catch (e: SecurityException) {
            onSecurityException(e)
        }
    }

    override fun unregisterActivityTransitions() {
        transitionPendingIntent?.let { pi ->
            try {
                activityClient.removeActivityTransitionUpdates(pi)
            } catch (e: Exception) {
                Log.w(TAG, "Failed to remove activity transitions: ${e.message}")
            }
        }
        transitionPendingIntent = null
    }

    private fun activityTransition(activityType: Int, transitionType: Int): ActivityTransition =
        ActivityTransition.Builder()
            .setActivityType(activityType)
            .setActivityTransition(transitionType)
            .build()
}
