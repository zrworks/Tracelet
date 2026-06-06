package com.ikolvi.tracelet_sync

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

import com.ikolvi.tracelet.sdk.TraceletSdk
import com.ikolvi.tracelet.sdk.location.LocationDataSink
import uniffi.tracelet_sync.SyncManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class TraceletSyncSink(private val sdk: TraceletSdk) : LocationDataSink, TraceletSdk.SyncProvider {
    private val scope = CoroutineScope(Dispatchers.IO)
    private val syncMutex = Mutex()
    private val syncManager = SyncManager()
    
    private var syncJob: kotlinx.coroutines.Job? = null
    private val DEBOUNCE_MS = 10_000L
    
    override fun insertLocation(location: Map<String, Any?>) {
        val delayMs = sdk.rustEngineState?.getConfig()?.http?.autoSyncDelay?.toLong() ?: 10_000L
        if (syncJob?.isActive == true) return
        syncJob = scope.launch {
            kotlinx.coroutines.delay(delayMs)
            triggerSync()
        }
    }
    
    private suspend fun triggerSync() {
        syncMutex.withLock {
            android.util.Log.d("TraceletSync", "triggerSync started")
            val db = sdk.rustDatabase ?: run {
                android.util.Log.e("TraceletSync", "rustDatabase is null")
                return
            }
            val state = sdk.rustEngineState ?: run {
                android.util.Log.e("TraceletSync", "rustEngineState is null")
                return
            }
            
            try {
                val coreHttp = state.getConfig().http
                android.util.Log.d("TraceletSync", "coreHttp config: url=${coreHttp.url}, autoSync=${coreHttp.autoSync}")
                if (coreHttp.url.isNullOrEmpty() || !coreHttp.autoSync) return
                
                val limit = if (coreHttp.maxBatchSize > 0) coreHttp.maxBatchSize else 250
                val records = db.getLocationsBatch(uniffi.tracelet_core.LocationQuery(
                    startTimeMs = null,
                    endTimeMs = null,
                    limit = limit.toInt(),
                    offset = null,
                    orderDescending = null
                ))
                android.util.Log.d("TraceletSync", "Found ${records.size} locations in DB")
                if (records.isEmpty()) return
                
                val syncConfig = uniffi.tracelet_sync.SyncHttpConfig(
                    url = coreHttp.url,
                    method = coreHttp.method,
                    headers = coreHttp.headers,
                    batchSync = coreHttp.batchSync,
                    maxBatchSize = coreHttp.maxBatchSize,
                    autoSync = coreHttp.autoSync,
                    maxRetries = coreHttp.maxRetries,
                    retryBackoffBase = coreHttp.retryBackoffBase,
                    retryBackoffCap = coreHttp.retryBackoffCap,
                    sslPinningCertificates = coreHttp.sslPinningCertificates,
                    httpRootProperty = coreHttp.httpRootProperty,
                    params = coreHttp.params,
                    extras = coreHttp.extras,
                    disableAutoSyncOnCellular = coreHttp.disableAutoSyncOnCellular,
                    enableDeltaCompression = coreHttp.enableDeltaCompression,
                    deltaCoordinatePrecision = coreHttp.deltaCoordinatePrecision,
                    locationsOrderDirection = coreHttp.locationsOrderDirection
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
                        activity = it.activity,
                        routeContext = it.routeContext
                    )
                }

                val count = syncManager.syncBatchBlocking(syncConfig, syncRecords)
                if (count > 0U) {
                    records.lastOrNull()?.id?.let { lastId ->
                        db.clearLocationsUpTo(lastId)
                        android.util.Log.i("TraceletSync", "Synced and cleared $count locations.")
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
                android.util.Log.e("TraceletSync", "Sync failed: ${e.message}")
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
                activity = it.activity,
                routeContext = it.routeContext
            )
        }
        val interceptor = sdk.dartSyncInterceptor
        android.util.Log.d("TraceletSync", "TraceletSyncPlugin Interceptor is $interceptor")
        if (interceptor != null) {
            val recordMaps = records.map { record ->
                mapOf(
                    "id" to record.id,
                    "uuid" to record.uuid,
                    "timestamp" to record.timestamp,
                    "latitude" to record.latitude,
                    "longitude" to record.longitude,
                    "accuracy" to record.accuracy,
                    "speed" to record.speed,
                    "heading" to record.heading,
                    "altitude" to record.altitude,
                    "isMock" to record.isMock,
                    "activity" to record.activity,
                    "routeContext" to record.routeContext
                )
            }
            android.util.Log.d("TraceletSync", "Calling requestSyncBody on interceptor with ${recordMaps.size} records")
            val customBody = interceptor.requestSyncBody(recordMaps)
            android.util.Log.d("TraceletSync", "requestSyncBody returned: $customBody")
            if (customBody != null) {
                return kotlinx.coroutines.runBlocking {
                    val success = executeFallbackHttpSync(config, customBody, interceptor)
                    android.util.Log.d("TraceletSync", "executeFallbackHttpSync success: $success")
                    if (success) records.size.toLong() else 0L
                }
            }
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
                        val headersMap = org.json.JSONObject(currentHeaders)
                        val iter = headersMap.keys()
                        while (iter.hasNext()) {
                            val key = iter.next()
                            conn.setRequestProperty(key, headersMap.getString(key))
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("TraceletSync", "Failed to parse HTTP headers: ${e.message}")
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
                android.util.Log.e("TraceletSync", "HTTP Sync failed: ${e.message}")
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
            
            android.util.Log.i("TraceletSync", "Sync sink registered!")
        } catch (e: Exception) {
            android.util.Log.e("TraceletSync", "Failed to init sync engine: ${e.message}")
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
