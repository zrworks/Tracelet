package com.ikolvi.tracelet.sdk.location
import com.ikolvi.tracelet.sdk.util.TraceletLog

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import androidx.core.content.ContextCompat
import androidx.work.*
import com.ikolvi.tracelet.sdk.ConfigManager
import com.ikolvi.tracelet.sdk.TraceletEventSender
import com.ikolvi.tracelet.sdk.StateManager
import com.ikolvi.tracelet.sdk.model.TrackingMode
import com.ikolvi.tracelet.sdk.receiver.PeriodicAlarmReceiver
import com.ikolvi.tracelet.sdk.TraceletBootstrap
import com.ikolvi.tracelet.sdk.util.BatteryUtils
import com.ikolvi.tracelet.sdk.wrapper.TraceletLocationPriority
import com.ikolvi.tracelet.sdk.wrapper.TraceletLocationCallback
import com.ikolvi.tracelet.sdk.wrapper.TraceletLocationRequest
import com.ikolvi.tracelet.sdk.wrapper.TraceletServices
import com.ikolvi.tracelet.sdk.wrapper.TraceletCancellationTokenSource
import kotlinx.coroutines.suspendCancellableCoroutine
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume

/**
 * WorkManager Worker that performs a single one-shot location fix.
 */
class PeriodicLocationWorker(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {

    companion object {
        private const val TAG = "PeriodicLocationWorker"
        const val WORK_NAME = "com.tracelet.periodic_location"
        const val ACTION_PERIODIC_ALARM = "com.tracelet.PERIODIC_ALARM"
        private const val ALARM_REQUEST_CODE = 8001
        private const val PERIODIC_HIGH_WINDOW_MS = 20_000L

        @Volatile
        var eventSender: TraceletEventSender? = null

        fun schedule(context: Context, intervalSeconds: Int) {
            val interval = intervalSeconds.toLong().coerceAtLeast(900L)
            val request = PeriodicWorkRequestBuilder<PeriodicLocationWorker>(
                interval, TimeUnit.SECONDS,
                5L.coerceAtMost(interval), TimeUnit.MINUTES,
            )
                .setConstraints(
                    Constraints.Builder()
                        .setRequiresBatteryNotLow(false)
                        .build()
                )
                .addTag(WORK_NAME)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.UPDATE,
                request,
            )
            TraceletLog.debug("Scheduled periodic location work: interval=${interval}s")
        }

        fun scheduleOneTime(context: Context) {
            val request = OneTimeWorkRequestBuilder<PeriodicLocationWorker>()
                .addTag(WORK_NAME)
                .build()

            WorkManager.getInstance(context).enqueueUniqueWork(
                "${WORK_NAME}_onetime",
                ExistingWorkPolicy.REPLACE,
                request,
            )
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
            WorkManager.getInstance(context).cancelUniqueWork("${WORK_NAME}_onetime")
            cancelExactAlarm(context)
            TraceletLog.debug("Cancelled periodic location work")
        }

        fun scheduleExactAlarm(context: Context, intervalSeconds: Int) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE)
                as? AlarmManager ?: return

            val triggerAtMs = System.currentTimeMillis() + (intervalSeconds * 1000L)
            val pi = createAlarmPendingIntent(context)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (!alarmManager.canScheduleExactAlarms()) {
                    TraceletLog.warning("SCHEDULE_EXACT_ALARM not granted \u2014 using setAndAllowWhileIdle")
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
                    } else {
                        alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
                    }
                    return
                }
            }

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, triggerAtMs, pi
                    )
                } else {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
                }
                TraceletLog.debug("Scheduled exact alarm in ${intervalSeconds}s")
            } catch (e: SecurityException) {
                TraceletLog.warning("Exact alarm SecurityException \u2014 using setAndAllowWhileIdle", e)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
                } else {
                    alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
                }
            }
        }

        fun cancelExactAlarm(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE)
                as? AlarmManager ?: return
            alarmManager.cancel(createAlarmPendingIntent(context))
            TraceletLog.debug("Cancelled exact periodic alarm")
        }

        fun canScheduleExactAlarms(context: Context): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE)
                as? AlarmManager ?: return false
            return alarmManager.canScheduleExactAlarms()
        }

        private fun createAlarmPendingIntent(context: Context): PendingIntent {
            val intent = Intent(ACTION_PERIODIC_ALARM)
                .setClass(context, PeriodicAlarmReceiver::class.java)
            return PendingIntent.getBroadcast(
                context,
                ALARM_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }

    override suspend fun doWork(): Result {
        TraceletLog.info("PeriodicStrategy: worker started")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val hasBackground = ContextCompat.checkSelfPermission(
                applicationContext, android.Manifest.permission.ACCESS_BACKGROUND_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
            if (!hasBackground) {
                TraceletLog.warning("PeriodicStrategy: ACCESS_BACKGROUND_LOCATION revoked, stopping periodic work")
                StateManager(applicationContext).apply {
                    enabled = false
                }
                return Result.failure()
            }
        }

        return try {
            val config = ConfigManager.getInstance(applicationContext)
            val state = StateManager(applicationContext)

            // Tracking was stopped after this work was enqueued — don't
            // capture, persist, or sync anything.
            if (!state.enabled) {
                com.ikolvi.tracelet.sdk.TraceletSdk.getInstance(applicationContext).logger
                    .info("PeriodicStrategy: tracking disabled, skipping periodic worker")
                return Result.success()
            }

            TraceletLog.info(
                "PeriodicStrategy: worker executing " +
                    "(trackingMode=${state.trackingMode}, periodicAccuracy=${config.getPeriodicDesiredAccuracy()}, " +
                    "interval=${config.getPeriodicLocationInterval()}s, locationTimeout=${config.getLocationTimeout()}s, " +
                    "gpsEnabled=${LocationEngine.isGpsProviderEnabled(applicationContext)})"
            )

            val location = fetchLocation(config)

            if (location != null) {
                var effectiveSpeed = location.speed.toDouble()
                val locationMap = buildLocationMap(location, config, state)
                val locationSource = locationMap["locationSource"] as? String

                // Bootstrap native tracking and persist location so it can be synced even if UI is dead.
                val sdk = com.ikolvi.tracelet.sdk.TraceletSdk.getInstance(applicationContext)
                val fallbackSender = TraceletBootstrap.eventSenderFactory?.invoke(applicationContext) ?: com.ikolvi.tracelet.sdk.ListenerEventSender()
                sdk.bootstrapForBackground(fallbackSender)
                sdk.insertLocation(locationMap)

                // Dispatch to the event sender which will route to UI/Headless
                dispatchLocation(locationMap)
                TraceletLog.info(
                    "PeriodicStrategy: worker fix dispatched " +
                        "(finalSource=${LocationEngine.formatLocationSourceForLog(locationSource)}, " +
                        "provider=${location.provider}, lat=${location.latitude}, lng=${location.longitude}, " +
                        "acc=${location.accuracy}, speed=$effectiveSpeed)"
                )

                // Feed speed to motion coordinators to allow wake up from stationary
                if (sdk.isReady) {
                    sdk.locationEngine.speedMotionSpeedSink?.invoke(effectiveSpeed)
                }
            } else {
                TraceletLog.warning("PeriodicStrategy: worker produced no location")
            }

            val interval = config.getPeriodicLocationInterval()
            val useExact = config.getPeriodicUseExactAlarms() || interval < 900

            if (state.enabled && state.trackingMode == TrackingMode.PERIODIC && useExact) {
                TraceletLog.info("PeriodicStrategy: worker scheduling next exact alarm in ${interval}s")
                scheduleExactAlarm(applicationContext, interval)
            }

            // CRITICAL FIX: The tracelet_sync plugin delays HTTP syncs by autoSyncDelay.
            // If we exit immediately, the OS will release the WakeLock and suspend the app,
            // failing the upload. So we hold the worker alive for (autoSyncDelay + 1) seconds.
            val traceletSdk = com.ikolvi.tracelet.sdk.TraceletSdk.getInstance(applicationContext)
            val httpConfig = traceletSdk.rustEngineState?.getConfig()?.http
            if (httpConfig != null && httpConfig.autoSync) {
                val delayMs = httpConfig.autoSyncDelay.toLong()
                TraceletLog.debug("Delaying worker exit for ${delayMs + 1000L} ms to allow tracelet_sync background upload...")
                kotlinx.coroutines.delay(delayMs + 1000L)
            }

            Result.success()
        } catch (e: kotlinx.coroutines.CancellationException) {
            // Cooperative cancellation — not a failure. Typically the SDK
            // switched from PERIODIC to CONTINUOUS mode (ready()/start()) and
            // cancelled this periodic job while we were holding it open for the
            // sync delay above. Never swallow CancellationException; let it
            // propagate so WorkManager records the work as cancelled cleanly.
            TraceletLog.debug("PeriodicStrategy: worker cancelled")
            throw e
        } catch (e: Exception) {
            TraceletLog.error("PeriodicStrategy: worker failed: ${e.message}", e)
            Result.retry()
        }
    }

    private suspend fun fetchLocation(config: ConfigManager): android.location.Location? {
        val client = TraceletServices.getInstance(applicationContext).getLocationClient(applicationContext)
        val priority = mapAccuracyToPriority(config.getPeriodicDesiredAccuracy())
        TraceletLog.info(
            "PeriodicStrategy: worker fetchLocation " +
                "(priority=$priority, periodicAccuracy=${config.getPeriodicDesiredAccuracy()})"
        )

        if (priority == TraceletLocationPriority.PRIORITY_HIGH_ACCURACY) {
            return fetchHighAccuracyPeriodicLocation(config)
        }

        val cts = TraceletCancellationTokenSource()

        return suspendCancellableCoroutine { continuation ->
            client.getCurrentLocation(priority, cts.token) { location ->
                TraceletLog.info(
                    "PeriodicStrategy: worker one-shot completed " +
                        "(hasLocation=${location != null}, provider=${location?.provider}, acc=${location?.accuracy})"
                )
                continuation.resume(location)
            }
            continuation.invokeOnCancellation {
                TraceletLog.debug("PeriodicStrategy: worker one-shot cancelled")
                cts.cancel()
            }
        }
    }

    private suspend fun fetchHighAccuracyPeriodicLocation(config: ConfigManager): android.location.Location? {
        val client = TraceletServices.getInstance(applicationContext).getLocationClient(applicationContext)
        val handler = Handler(Looper.getMainLooper())
        val windowMs = (config.getLocationTimeout().toLong() * 1000L)
            .coerceAtMost(PERIODIC_HIGH_WINDOW_MS)
            .coerceAtLeast(5_000L)
        TraceletLog.info(
            "PeriodicStrategy: worker high window started " +
                "(windowMs=$windowMs, gpsEnabled=${LocationEngine.isGpsProviderEnabled(applicationContext)})"
        )

        val highLocation = suspendCancellableCoroutine<android.location.Location?> { continuation ->
            val samples = mutableListOf<android.location.Location>()
            var completed = false
            var callback: TraceletLocationCallback? = null

            fun complete(location: android.location.Location?) {
                if (completed) return
                completed = true
                callback?.let { client.removeLocationUpdates(it) }
                val source = location?.let { LocationEngine.classifyLocationSource(it) }
                TraceletLog.info(
                    "PeriodicStrategy: worker high window completed " +
                        "(hasLocation=${location != null}, finalSource=${LocationEngine.formatLocationSourceForLog(source)}, " +
                        "provider=${location?.provider}, " +
                        "acc=${location?.accuracy}, samples=${samples.size})"
                )
                continuation.resume(location)
            }

            val timeoutRunnable = Runnable {
                val best = samples.minByOrNull { it.accuracy }
                if (best != null) {
                    val source = LocationEngine.classifyLocationSource(best)
                    TraceletLog.info(
                        "PeriodicStrategy: worker high window timed out, using best sample " +
                            "(source=${LocationEngine.formatLocationSourceForLog(source)}, provider=${best.provider}, " +
                            "acc=${best.accuracy}, samples=${samples.size})"
                    )
                } else {
                    TraceletLog.warning("PeriodicStrategy: worker high window timed out with no samples")
                }
                complete(best)
            }

            callback = object : TraceletLocationCallback {
                override fun onLocationResult(locations: List<android.location.Location>) {
                    if (completed) return
                    for (location in locations) {
                        samples.add(location)
                        val source = LocationEngine.classifyLocationSource(location)
                        TraceletLog.debug(
                            "PeriodicStrategy: worker high sample " +
                                "(source=${LocationEngine.formatLocationSourceForLog(source)}, " +
                                "provider=${location.provider}, acc=${location.accuracy}, " +
                                "lat=${location.latitude}, lng=${location.longitude}, " +
                                "gpsFix=${LocationEngine.isGpsFix(location)})"
                        )
                        if (LocationEngine.isGpsFix(location)) {
                            TraceletLog.info(
                                "PeriodicStrategy: worker high accepted GPS-quality fix " +
                                    "(source=${LocationEngine.formatLocationSourceForLog(source)}, " +
                                    "provider=${location.provider}, acc=${location.accuracy})"
                            )
                            handler.removeCallbacks(timeoutRunnable)
                            complete(location)
                            return
                        }
                    }
                }

                override fun onLocationAvailability(isLocationAvailable: Boolean) {
                    TraceletLog.debug("PeriodicStrategy: worker high availability=$isLocationAvailable")
                }
            }

            val request = TraceletLocationRequest(
                priority = TraceletLocationPriority.PRIORITY_HIGH_ACCURACY,
                intervalMillis = 2_000L,
                minUpdateDistanceMeters = 0f,
                minUpdateIntervalMillis = 1_000L,
            )

            try {
                client.requestLocationUpdates(request, callback, Looper.getMainLooper())
                handler.postDelayed(timeoutRunnable, windowMs)
            } catch (e: SecurityException) {
                handler.removeCallbacks(timeoutRunnable)
                TraceletLog.error("PeriodicStrategy: worker high request failed by SecurityException", e)
                complete(null)
            }

            continuation.invokeOnCancellation {
                handler.removeCallbacks(timeoutRunnable)
                TraceletLog.debug("PeriodicStrategy: worker high window cancelled")
                client.removeLocationUpdates(callback)
            }
        }

        if (highLocation != null) return highLocation

        TraceletLog.warning("PeriodicStrategy: worker high unavailable, falling back to balanced")
        val cts = TraceletCancellationTokenSource()
        return suspendCancellableCoroutine { continuation ->
            client.getCurrentLocation(
                TraceletLocationPriority.PRIORITY_BALANCED_POWER_ACCURACY,
                cts.token,
            ) { location ->
                val source = location?.let { LocationEngine.classifyLocationSource(it) }
                TraceletLog.info(
                    "PeriodicStrategy: worker balanced fallback completed " +
                        "(hasLocation=${location != null}, finalSource=${LocationEngine.formatLocationSourceForLog(source)}, " +
                        "provider=${location?.provider}, acc=${location?.accuracy})"
                )
                continuation.resume(location)
            }
            continuation.invokeOnCancellation {
                TraceletLog.debug("PeriodicStrategy: worker balanced fallback cancelled")
                cts.cancel()
            }
        }
    }

    private fun buildLocationMap(
        location: android.location.Location,
        config: ConfigManager,
        state: StateManager,
    ): Map<String, Any?> {
        val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }

        val map = mutableMapOf<String, Any?>(
            "uuid" to UUID.randomUUID().toString(),
            "timestamp" to isoFormat.format(Date(location.time)),
            "locationSource" to LocationEngine.classifyLocationSource(location),
            "provider" to location.provider,
            "coords" to mapOf(
                "latitude" to location.latitude,
                "longitude" to location.longitude,
                "altitude" to location.altitude,
                "speed" to location.speed.toDouble(),
                "heading" to location.bearing.toDouble(),
                "accuracy" to location.accuracy.toDouble(),
                "altitudeAccuracy" to if (android.os.Build.VERSION.SDK_INT >= 26)
                    location.verticalAccuracyMeters.toDouble() else -1.0,
                "speedAccuracy" to if (android.os.Build.VERSION.SDK_INT >= 26)
                    location.speedAccuracyMetersPerSecond.toDouble() else -1.0,
                "headingAccuracy" to if (android.os.Build.VERSION.SDK_INT >= 26)
                    location.bearingAccuracyDegrees.toDouble() else -1.0,
            ),
            "is_moving" to (location.speed > 0),
            "odometer" to state.odometer,
            "event" to "periodic",
            "mock" to location.isFromMockProvider,
            "activity" to mapOf(
                "type" to "unknown",
                "confidence" to -1,
            ),
        )

        val batteryInfo = BatteryUtils.getBatteryInfo(applicationContext)
        map["battery"] = batteryInfo

        val extras = config.getHttpExtras()
        if (extras.isNotEmpty()) {
            map["extras"] = extras
        }

        val ageMs = (SystemClock.elapsedRealtimeNanos() - location.elapsedRealtimeNanos) / 1_000_000
        map["age"] = ageMs

        return map
    }

    private fun dispatchLocation(locationMap: Map<String, Any?>) {
        val sender = eventSender
        if (sender != null) {
            Handler(Looper.getMainLooper()).post {
                sender.sendLocation(locationMap)
            }
        } else {
            try {
                val headless = TraceletBootstrap.headlessDispatcherFactory?.invoke(applicationContext)
                if (headless != null && headless.isRegistered()) {
                    headless.dispatchEvent("location", locationMap)
                }
            } catch (_: Exception) {}
        }
    }

    private fun mapAccuracyToPriority(accuracyIndex: Int): Int {
        return when (accuracyIndex) {
            0 -> TraceletLocationPriority.PRIORITY_HIGH_ACCURACY
            1 -> TraceletLocationPriority.PRIORITY_BALANCED_POWER_ACCURACY
            2 -> TraceletLocationPriority.PRIORITY_LOW_POWER
            3 -> TraceletLocationPriority.PRIORITY_PASSIVE
            4 -> TraceletLocationPriority.PRIORITY_PASSIVE
            else -> TraceletLocationPriority.PRIORITY_BALANCED_POWER_ACCURACY
        }
    }
}
