package com.ikolvi.tracelet_sync

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

import com.ikolvi.tracelet.sdk.TraceletSdk
import com.ikolvi.tracelet.sdk.location.LocationDataSink
import com.ikolvi.tracelet.sdk.model.Location
import uniffi.tracelet_sync.SyncManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class TraceletSyncSink(private val sdk: TraceletSdk) : LocationDataSink {
    private val scope = CoroutineScope(Dispatchers.IO)
    private val syncMutex = Mutex()
    private val syncManager = SyncManager()
    
    override fun onLocationReceived(location: Location) {
        scope.launch {
            triggerSync()
        }
    }
    
    private suspend fun triggerSync() {
        syncMutex.withLock {
            val db = sdk.rustDatabase ?: return
            val state = sdk.rustEngineState ?: return
            
            try {
                val coreHttp = state.getConfig().http
                if (coreHttp.url.isNullOrEmpty() || !coreHttp.autoSync) return
                
                val limit = if (coreHttp.maxBatchSize > 0) coreHttp.maxBatchSize else 250
                val records = db.getLocationsBatch(limit)
                if (records.isEmpty()) return
                
                val count = syncManager.syncBatchBlocking(coreHttp, records)
                if (count > 0) {
                    records.lastOrNull()?.id?.let { lastId ->
                        db.clearLocationsUpTo(lastId)
                        android.util.Log.i("TraceletSync", "Synced and cleared $count locations.")
                    }
                }
            } catch (e: Exception) {
                android.util.Log.e("TraceletSync", "Sync failed: ${e.message}")
            }
        }
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
            traceletSdk.locationEngine?.registerSink(sink)
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
