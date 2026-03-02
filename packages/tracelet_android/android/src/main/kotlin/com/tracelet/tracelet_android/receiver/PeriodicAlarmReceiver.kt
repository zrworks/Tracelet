package com.tracelet.tracelet_android.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.tracelet.tracelet_android.StateManager
import com.tracelet.tracelet_android.location.PeriodicLocationWorker

/**
 * BroadcastReceiver triggered by AlarmManager for exact-alarm periodic mode.
 *
 * When `periodicUseExactAlarms` is `true`, the plugin schedules exact alarms
 * via [AlarmManager]. When the alarm fires, this receiver enqueues a
 * [OneTimeWorkRequest] via [PeriodicLocationWorker.scheduleOneTime] to perform
 * a single location fix. The worker itself re-schedules the next exact alarm
 * after completing.
 *
 * Flow:
 * ```
 * handleStartPeriodic()
 *   → scheduleExactAlarm()
 *     → AlarmManager fires
 *       → PeriodicAlarmReceiver.onReceive()
 *         → PeriodicLocationWorker.scheduleOneTime()
 *           → doWork() performs fix
 *             → scheduleExactAlarm() for next interval
 * ```
 */
class PeriodicAlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "PeriodicAlarmReceiver"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != PeriodicLocationWorker.ACTION_PERIODIC_ALARM) {
            return
        }

        // Verify periodic tracking is still enabled
        val state = StateManager(context)
        if (!state.enabled || state.trackingMode != 2) {
            Log.d(TAG, "Periodic tracking no longer active — ignoring alarm")
            return
        }

        Log.d(TAG, "Exact alarm fired — enqueuing one-time location work")
        PeriodicLocationWorker.scheduleOneTime(context)
    }
}
