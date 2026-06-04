package com.ikolvi.tracelet.sdk.sync

import com.ikolvi.tracelet.sdk.TraceletSdk
import com.ikolvi.tracelet.sdk.location.LocationDataSink
import uniffi.tracelet_sync.SyncManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class NativeSyncProvider(private val sdk: TraceletSdk) : LocationDataSink, TraceletSdk.SyncProvider {
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
            sdk.logger.debug("NativeSyncProvider: triggerSync started")
            val db = sdk.rustDatabase ?: run {
                sdk.logger.error("NativeSyncProvider: rustDatabase is null")
                return
            }
            val state = sdk.rustEngineState ?: run {
                sdk.logger.error("NativeSyncProvider: rustEngineState is null")
                return
            }

            try {
                val coreHttp = state.getConfig().http
                sdk.logger.debug("NativeSyncProvider: coreHttp config: url=${coreHttp.url}, autoSync=${coreHttp.autoSync}")
                if (coreHttp.url.isNullOrEmpty() || !coreHttp.autoSync) return

                val limit = if (coreHttp.maxBatchSize > 0) coreHttp.maxBatchSize else 250
                val records = db.getLocationsBatch(uniffi.tracelet_core.LocationQuery(
                    startTimeMs = null,
                    endTimeMs = null,
                    limit = limit.toInt(),
                    offset = null,
                    orderDescending = null
                ))
                sdk.logger.debug("NativeSyncProvider: Found ${records.size} locations in DB")
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
                        sdk.logger.info("NativeSyncProvider: Synced and cleared $count locations.")
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
                sdk.logger.error("NativeSyncProvider: Sync failed: ${e.message}")
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
        return syncManager.syncBatchBlocking(syncConfig, syncRecords).toLong()
    }
}
