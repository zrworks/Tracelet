package com.ikolvi.tracelet_sync

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

import com.ikolvi.tracelet.sdk.TraceletSdk
import com.ikolvi.tracelet.sdk.location.LocationDataSink
import com.ikolvi.tracelet.sdk.sync.NO_SYNC_BODY_BUILDER_SENTINEL
import uniffi.tracelet_sync.SyncManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class TraceletSyncSink(private val sdk: TraceletSdk) : LocationDataSink, TraceletSdk.SyncProvider {
    // SupervisorJob: a single failed sync must not cancel the scope, else the
    // first background sync that throws kills every future sync (Issue #134).
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val syncMutex = Mutex()
    private val syncManager = SyncManager()

    private var syncJob: kotlinx.coroutines.Job? = null
    private val DEBOUNCE_MS = 10_000L

    override fun insertLocation(location: Map<String, Any?>) {
        val delayMs = sdk.rustEngineState?.getConfig()?.http?.autoSyncDelay?.toLong() ?: 10_000L
        if (syncJob?.isActive == true) return
        syncJob = scope.launch {
            // Contain any throwable so a single failed iteration can't tear down
            // auto-sync; re-throw real cancellation so stop() still works (#134).
            try {
                kotlinx.coroutines.delay(delayMs)
                triggerSync()
            } catch (ce: kotlinx.coroutines.CancellationException) {
                throw ce
            } catch (t: Throwable) {
                sdk.logger.error("TraceletSyncSink: auto-sync iteration failed (contained): ${t.message}")
            }
        }
    }
    
    private suspend fun triggerSync() {
        syncMutex.withLock {
            sdk.logger.debug("triggerSync started")
            val db = sdk.rustDatabase ?: run {
                sdk.logger.error("rustDatabase is null")
                return
            }
            val state = sdk.rustEngineState ?: run {
                sdk.logger.error("rustEngineState is null")
                return
            }
            
            try {
                val coreHttp = state.getConfig().http
                sdk.logger.debug("coreHttp config: url=${coreHttp.url}, autoSync=${coreHttp.autoSync}")
                if (coreHttp.url.isNullOrEmpty() || !coreHttp.autoSync) return
                
                val limit = if (coreHttp.maxBatchSize > 0) coreHttp.maxBatchSize else 250
                val records = db.getLocationsBatch(uniffi.tracelet_core.LocationQuery(
                    startTimeMs = null,
                    endTimeMs = null,
                    limit = limit.toInt(),
                    offset = null,
                    // Honor the configured sort order (0=ascending, 1=descending)
                    // instead of always defaulting to ascending (Issue #138).
                    orderDescending = coreHttp.locationsOrderDirection == 1
                ))
                sdk.logger.debug("Found ${records.size} locations in DB")
                if (records.isEmpty()) return
                
                val count = syncBatchBlocking(coreHttp, records)
                if (count > 0L) {
                    records.lastOrNull()?.id?.let { lastId ->
                        db.clearLocationsUpTo(lastId)
                        sdk.logger.info("Synced and cleared $count locations.")
                    }
                    sdk.getEventSender().sendHttp(mapOf(
                        "success" to true,
                        "status" to 200,
                        "responseText" to "Synced $count locations",
                        "isRetry" to false,
                        "retryCount" to 0
                    ))
                }
            } catch (e: Exception) {
                sdk.logger.error("Sync failed: ${e.message}")
                sdk.getEventSender().sendHttp(mapOf(
                    "success" to false,
                    "status" to 0,
                    "responseText" to (e.message ?: "Unknown error"),
                    "isRetry" to false,
                    "retryCount" to 0
                ))
            }
        }
    }
    
    override fun syncBatchBlocking(config: uniffi.tracelet_core.HttpConfig, records: List<uniffi.tracelet_core.DbLocationRecord>): Long {
        val syncConfig = uniffi.tracelet_sync.SyncHttpConfig(
            url = config.url,
            method = config.method,
            headers = config.headers,
            batchSync = config.batchSync,
            maxBatchSize = config.maxBatchSize,
            autoSync = config.autoSync,
            maxRetries = config.maxRetries,
            retryBackoffBase = config.retryBackoffBase,
            retryBackoffCap = config.retryBackoffCap,
            sslPinningCertificates = config.sslPinningCertificates,
            sslPinningFingerprints = config.sslPinningFingerprints,
            httpRootProperty = config.httpRootProperty,
            params = config.params,
            extras = config.extras,
            disableAutoSyncOnCellular = config.disableAutoSyncOnCellular,
            enableDeltaCompression = config.enableDeltaCompression,
            deltaCoordinatePrecision = config.deltaCoordinatePrecision,
            locationsOrderDirection = config.locationsOrderDirection
        )
        val syncRecords = records.map {
            uniffi.tracelet_sync.SyncLocationRecord(
                id = it.id,
                uuid = it.uuid,
                timestamp = it.timestamp,
                latitude = it.latitude,
                longitude = it.longitude,
                accuracy = it.accuracy,
                speed = it.speed,
                heading = it.heading,
                altitude = it.altitude,
                isMock = it.isMock,
                isMoving = it.isMoving,
                activity = it.activity,
                event = it.eventType,
                routeContext = it.routeContext
            )
        }
        val interceptor = sdk.dartSyncInterceptor
        sdk.logger.debug("TraceletSyncPlugin Interceptor is $interceptor")
        if (interceptor != null) {
            // Issue #126: emit the SAME nested schema as onLocation/getLocations
            // (nested coords/activity/battery + route_context) so the Dart
            // custom-body builder receives a consistent shape instead of a flat
            // map with a raw String activity.
            val recordMaps = records.map { sdk.mapRecordToLocation(it) }
            sdk.logger.debug("Calling requestSyncBody on interceptor with ${recordMaps.size} records")
            val customBody = interceptor.requestSyncBody(recordMaps)
            sdk.logger.debug("requestSyncBody returned: $customBody")
            if (customBody == null) {
                // Builder registered but failed → abort (0 = nothing synced).
                sdk.logger.error("Custom sync body failed to build; aborting sync")
                return 0L
            }
            if (customBody != NO_SYNC_BODY_BUILDER_SENTINEL) {
                return kotlinx.coroutines.runBlocking {
                    val success = executeFallbackHttpSync(config, customBody, interceptor)
                    sdk.logger.debug("executeFallbackHttpSync success: $success")
                    if (success) records.size.toLong() else 0L
                }
            }
            // sentinel → no builder → fall through to the default sync below.
        }

        return syncManager.syncBatchBlocking(syncConfig, syncRecords).toLong()
    }

    private suspend fun executeFallbackHttpSync(
        coreHttp: uniffi.tracelet_core.HttpConfig,
        customBody: String,
        interceptor: com.ikolvi.tracelet.sdk.sync.DartSyncInterceptor?
    ): Boolean {
        var currentHeaders = coreHttp.headers
        val maxRetries = coreHttp.maxRetries.toInt()
        
        for (attempt in 0..maxRetries) {
            try {
                val url = java.net.URL(coreHttp.url)
                val conn = url.openConnection() as java.net.HttpURLConnection
                conn.requestMethod = if (coreHttp.method.toInt() == 1) "PUT" else "POST"
                conn.doOutput = true
                conn.setRequestProperty("Content-Type", "application/json")
                conn.connectTimeout = 15000
                conn.readTimeout = 15000

                if (currentHeaders.isNotEmpty()) {
                    try {
                        currentHeaders.forEach { (key, value) ->
                            conn.setRequestProperty(key, value)
                        }
                    } catch (e: Exception) {
                        sdk.logger.error("Failed to set HTTP headers: ${e.message}")
                    }
                }

                conn.outputStream.use { os ->
                    val input = customBody.toByteArray(kotlin.text.Charsets.UTF_8)
                    os.write(input, 0, input.size)
                }

                val status = conn.responseCode
                conn.disconnect()
                
                if (status in 200..299) {
                    return true
                } else if (status == 401 && interceptor != null) {
                    if (interceptor.requestTokenRefresh()) {
                        val newConfig = sdk.rustEngineState?.getConfig()?.http
                        if (newConfig != null) {
                            currentHeaders = newConfig.headers
                        }
                        continue
                    }
                }
            } catch (e: Exception) {
                sdk.logger.error("HTTP Sync failed: ${e.message}")
            }
            if (attempt < maxRetries) {
                kotlinx.coroutines.delay(1000L * (attempt + 1))
            }
        }
        return false
    }
}

/** TraceletSyncPlugin */
class TraceletSyncPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var syncSink: TraceletSyncSink? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "tracelet_sync")
        channel.setMethodCallHandler(this)
        
        try {
            val context = binding.applicationContext
            val traceletSdk = TraceletSdk.getInstance(context)
            
            val sink = TraceletSyncSink(traceletSdk)
            traceletSdk.registerSyncProvider(sink)
            syncSink = sink
            
            traceletSdk.logger.info("Sync sink registered!")
        } catch (e: Exception) {
            val ctx = binding.applicationContext
            TraceletSdk.getInstance(ctx).logger.error("Failed to init sync engine: ${e.message}")
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method == "initialize") {
            result.success(true)
        } else {
            result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
