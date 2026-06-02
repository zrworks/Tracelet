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

    override fun insertLocation(location: Map<String, Any?>) {
        scope.launch {
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
                val records = db.getLocationsBatch(limit.toInt())
                sdk.logger.debug("NativeSyncProvider: Found ${records.size} locations in DB")
                if (records.isEmpty()) return

                val count = syncManager.syncBatchBlocking(coreHttp, records)
                if (count > 0) {
                    records.lastOrNull()?.id?.let { lastId ->
                        db.clearLocationsUpTo(lastId)
                        sdk.logger.info("NativeSyncProvider: Synced and cleared $count locations.")
                    }
                }
            } catch (e: Exception) {
                sdk.logger.error("NativeSyncProvider: Sync failed: ${e.message}")
            }
        }
    }

    override fun syncBatchBlocking(config: uniffi.tracelet_core.HttpConfig, records: List<uniffi.tracelet_core.DbLocationRecord>): Long {
        return syncManager.syncBatchBlocking(config, records).toLong()
    }
}
