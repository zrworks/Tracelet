package com.ikolvi.tracelet.sdk.schedule

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.util.Log
import com.ikolvi.tracelet.sdk.ConfigManager
import com.ikolvi.tracelet.sdk.TraceletEventSender
import com.ikolvi.tracelet.sdk.StateManager
import uniffi.tracelet_core.ScheduleParser
import java.util.Calendar
import java.util.TimeZone

/**
 * Schedule-based tracking engine.
 *
 * Parses schedule strings like "1-7 09:00-17:00" (day-of-week range + time range)
 * and uses AlarmManager to start/stop tracking at the specified times.
 */
class ScheduleManager(
    private val context: Context,
    private val config: ConfigManager,
    private val state: StateManager,
    private val events: TraceletEventSender,
) {
    companion object {
        private const val TAG = "ScheduleManager"
        private const val ACTION_SCHEDULE_START = "com.tracelet.SCHEDULE_START"
        private const val ACTION_SCHEDULE_STOP = "com.tracelet.SCHEDULE_STOP"
        private const val REQUEST_CODE_START = 9001
        private const val REQUEST_CODE_STOP = 9002
    }

    var onScheduleStart: (() -> Unit)? = null
    var onScheduleStop: (() -> Unit)? = null

    private var scheduleReceiver: BroadcastReceiver? = null
    private val parser = ScheduleParser()

    /** Start the schedule engine. Reads schedule strings from config. */
    fun start() {
        val schedules = config.getSchedule()
        if (schedules.isEmpty()) return

        state.schedulerEnabled = true
        registerReceiver()
        scheduleNext(schedules)
    }

    /** Stop the schedule engine. */
    fun stop() {
        state.schedulerEnabled = false
        cancelAlarms()
        unregisterReceiver()
    }

    fun isWithinSchedule(): Boolean {
        val schedules = config.getSchedule()
        if (schedules.isEmpty()) return false

        val nowMs = System.currentTimeMillis()
        val tzOffsetSeconds = TimeZone.getDefault().getOffset(nowMs) / 1000
        return parser.isWithinSchedule(schedules, nowMs, tzOffsetSeconds)
    }

    // =========================================================================
    // Private
    // =========================================================================

    private fun scheduleNext(schedules: List<String>) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        if (schedules.isEmpty()) return

        val nowMs = System.currentTimeMillis()
        val tzOffsetSeconds = TimeZone.getDefault().getOffset(nowMs) / 1000
        
        val alarms = parser.calculateNextAlarms(schedules, nowMs, tzOffsetSeconds)

        if (alarms.nextStartMs < Long.MAX_VALUE) {
            setAlarm(alarmManager, ACTION_SCHEDULE_START, REQUEST_CODE_START, alarms.nextStartMs)
        }
        if (alarms.nextStopMs < Long.MAX_VALUE) {
            setAlarm(alarmManager, ACTION_SCHEDULE_STOP, REQUEST_CODE_STOP, alarms.nextStopMs)
        }
    }

    private fun setAlarm(alarmManager: AlarmManager, action: String, requestCode: Int, triggerAtMs: Long) {
        val intent = Intent(action).setPackage(context.packageName)
        val pi = PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        if (config.getScheduleUseAlarmManager()) {
            // Exact alarm — requires SCHEDULE_EXACT_ALARM on Android 12+
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
                } else {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
                }
            } catch (e: SecurityException) {
                // Fallback to inexact if exact alarm permission denied
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
            }
        } else {
            // Inexact alarm — battery-friendly, no SCHEDULE_EXACT_ALARM needed
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
        }
    }

    private fun cancelAlarms() {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        for ((action, code) in listOf(
            ACTION_SCHEDULE_START to REQUEST_CODE_START,
            ACTION_SCHEDULE_STOP to REQUEST_CODE_STOP
        )) {
            val intent = Intent(action).setPackage(context.packageName)
            val pi = PendingIntent.getBroadcast(
                context, code, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pi)
        }
    }

    private fun registerReceiver() {
        scheduleReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                when (intent?.action) {
                    ACTION_SCHEDULE_START -> {
                        Log.d(TAG, "Schedule start triggered")
                        onScheduleStart?.invoke()
                        events.sendSchedule(state.toMap())
                        // Re-schedule for next occurrence
                        scheduleNext(config.getSchedule())
                    }
                    ACTION_SCHEDULE_STOP -> {
                        Log.d(TAG, "Schedule stop triggered")
                        onScheduleStop?.invoke()
                        events.sendSchedule(state.toMap())
                        scheduleNext(config.getSchedule())
                    }
                }
            }
        }

        val filter = IntentFilter().apply {
            addAction(ACTION_SCHEDULE_START)
            addAction(ACTION_SCHEDULE_STOP)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(scheduleReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(scheduleReceiver, filter)
        }
    }

    private fun unregisterReceiver() {
        scheduleReceiver?.let {
            try { context.unregisterReceiver(it) } catch (_: Exception) {}
        }
        scheduleReceiver = null
    }
}
