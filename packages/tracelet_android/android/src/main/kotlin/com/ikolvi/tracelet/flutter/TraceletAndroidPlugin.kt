package com.ikolvi.tracelet.flutter

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.ikolvi.tracelet.sdk.TraceletBootstrap
import com.ikolvi.tracelet.sdk.TraceletSdk
import com.ikolvi.tracelet.TraceletHostApi
import com.ikolvi.tracelet.flutter.service.HeadlessTaskService
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.CopyOnWriteArrayList

/**
 * Broadcasts events to multiple EventDispatchers.
 */
class MultiEventSender : com.ikolvi.tracelet.sdk.TraceletEventSender {
    private val dispatchers = CopyOnWriteArrayList<EventDispatcher>()

    fun add(dispatcher: EventDispatcher) = dispatchers.addIfAbsent(dispatcher)
    fun remove(dispatcher: EventDispatcher) = dispatchers.remove(dispatcher)
    
    // Fallback getter - uses first available dispatcher for hasListener checks
    private val first: EventDispatcher? get() = dispatchers.firstOrNull()

    override fun sendLocation(data: Map<String, Any?>) { dispatchers.forEach { it.sendLocation(data) } }
    override fun sendMotionChange(data: Map<String, Any?>) { dispatchers.forEach { it.sendMotionChange(data) } }
    override fun sendSpeedMotionChange(data: Map<String, Any?>) { dispatchers.forEach { it.sendSpeedMotionChange(data) } }
    override fun sendActivityChange(data: Map<String, Any?>) { dispatchers.forEach { it.sendActivityChange(data) } }
    override fun sendProviderChange(data: Map<String, Any?>) { dispatchers.forEach { it.sendProviderChange(data) } }
    override fun sendGeofence(data: Map<String, Any?>) { dispatchers.forEach { it.sendGeofence(data) } }
    override fun sendGeofencesChange(data: Map<String, Any?>) { dispatchers.forEach { it.sendGeofencesChange(data) } }
    override fun sendHeartbeat(data: Map<String, Any?>) { dispatchers.forEach { it.sendHeartbeat(data) } }
    override fun sendHttp(data: Map<String, Any?>) { dispatchers.forEach { it.sendHttp(data) } }
    override fun sendSchedule(data: Map<String, Any?>) { dispatchers.forEach { it.sendSchedule(data) } }
    override fun sendPowerSaveChange(isPowerSaveMode: Boolean) { dispatchers.forEach { it.sendPowerSaveChange(isPowerSaveMode) } }
    override fun sendConnectivityChange(data: Map<String, Any?>) { dispatchers.forEach { it.sendConnectivityChange(data) } }
    override fun sendEnabledChange(enabled: Boolean) { dispatchers.forEach { it.sendEnabledChange(enabled) } }
    override fun sendNotificationAction(action: String) { dispatchers.forEach { it.sendNotificationAction(action) } }
    override fun sendAuthorization(data: Map<String, Any?>) { dispatchers.forEach { it.sendAuthorization(data) } }
    override fun sendWatchPosition(data: Map<String, Any?>) { dispatchers.forEach { it.sendWatchPosition(data) } }
    
    override fun sendRemoteConfigEvent(data: Map<String, Any?>) { dispatchers.forEach { it.sendRemoteConfigEvent(data) } }
    override fun sendTrip(data: Map<String, Any?>) { dispatchers.forEach { it.sendTrip(data) } }
    override fun sendBudgetAdjustment(data: Map<String, Any?>) { dispatchers.forEach { it.sendBudgetAdjustment(data) } }

    override fun hasListener(eventName: String): Boolean = dispatchers.any { it.hasListener(eventName) }
}


/**
 * TraceletAndroidPlugin — Robust Flutter bridge for Tracelet.
 */
class TraceletAndroidPlugin :
    FlutterPlugin,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

    companion object {
        private const val TAG = "TraceletAndroidPlugin"
        private const val DART_CALLBACK_TIMEOUT_MS = 10_000L

        @Volatile
        private var primaryInstance: TraceletAndroidPlugin? = null
        
        private val attachedEngineCount = AtomicInteger(0)
        private val globalEventSender = MultiEventSender()

        @JvmField
        internal var isMainThread: () -> Boolean = {
            Looper.myLooper() == Looper.getMainLooper()
        }
    }

    private lateinit var context: Context
    private lateinit var eventDispatcher: EventDispatcher
    private var headlessService: HeadlessTaskService? = null

    private var activityBinding: ActivityPluginBinding? = null
    private var syncBodyChannel: MethodChannel? = null
    @Volatile private var isEngineAttached = false

    private val sdk: TraceletSdk get() = TraceletSdk.getInstance(context)

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        isEngineAttached = true
        
        val count = attachedEngineCount.incrementAndGet()
        val isFirst = count == 1
        val isPrimaryCandidate = primaryInstance == null
        
        Log.d(TAG, "onAttachedToEngine: engineCount=$count, isFirst=$isFirst, isPrimaryCandidate=$isPrimaryCandidate")

        if (isPrimaryCandidate) {
            primaryInstance = this
            Log.d(TAG, "onAttachedToEngine: setting as PRIMARY instance")

            eventDispatcher = EventDispatcher()
            eventDispatcher.register(binding.binaryMessenger)
            globalEventSender.add(eventDispatcher)

            sdk.setEventSender(globalEventSender)
            
            // Only initialize the SDK if it's the very first engine. 
            // If the SDK was already initialized (e.g. by a previous engine that detached),
            // initialize() is usually idempotent but we want to be sure.
            sdk.initialize()

            val hs = HeadlessTaskService(context, sdk.configManager)
            headlessService = hs

            val mainHandler = Handler(Looper.getMainLooper())
            syncBodyChannel = MethodChannel(binding.binaryMessenger, "com.tracelet/sync_body")

            eventDispatcher.headlessFallback = { eventName, eventData ->
                if (hs.isRegistered()) {
                    hs.dispatchEvent(eventName, eventData)
                }
            }

            TraceletBootstrap.headlessDispatcherFactory = { ctx -> HeadlessTaskService(ctx) }
            TraceletBootstrap.eventSenderFactory = { ctx ->
                val dispatcher = EventDispatcher()
                val h = HeadlessTaskService(ctx)
                dispatcher.headlessFallback = { name, data ->
                    if (h.isRegistered()) h.dispatchEvent(name, data)
                }
                dispatcher
            }
        } else {
            // Secondary engine (e.g. headless isolate or EngineGroup overlay)
            Log.d(TAG, "onAttachedToEngine: secondary engine attach")
            
            // We still need an EventDispatcher for this engine if it wants to receive events in the foreground
            eventDispatcher = EventDispatcher()
            eventDispatcher.register(binding.binaryMessenger)
            globalEventSender.add(eventDispatcher)
            
            // At least we ensure that events fall back to headless if this engine is not the primary.
            primaryInstance?.headlessService?.let { hs ->
                eventDispatcher.headlessFallback = { name, data ->
                    if (hs.isRegistered()) hs.dispatchEvent(name, data)
                }
            }
        }

        // Pigeon API: register on EVERY engine.
        val apiHeadless = headlessService ?: HeadlessTaskService(context)
        TraceletHostApi.setUp(
            binding.binaryMessenger,
            TraceletHostApiImpl(context, apiHeadless),
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val count = attachedEngineCount.decrementAndGet()
        Log.d(TAG, "onDetachedFromEngine: remainingEngines=$count")
        
        isEngineAttached = false
        TraceletHostApi.setUp(binding.binaryMessenger, null)

        if (primaryInstance === this) {
            Log.d(TAG, "onDetachedFromEngine: primary instance detaching")
            primaryInstance = null
            syncBodyChannel = null
            
            // If this was the last engine, destroy the SDK.
            // Otherwise, we must NOT destroy the SDK because secondary engines might still be using it!
            globalEventSender.remove(eventDispatcher)
            if (count == 0) {
                Log.d(TAG, "onDetachedFromEngine: last engine detached, destroying SDK")
                eventDispatcher.unregister()
                sdk.destroyAll()
            } else {
                Log.d(TAG, "onDetachedFromEngine: secondary engines still active, SDK preserved")
                // We should probably promote another instance to primaryInstance here if needed.
                // But for Tracelet, the first one is usually the main one.
            }
        } else {
            globalEventSender.remove(eventDispatcher)
            eventDispatcher.unregister()
            if (count == 0) {
                Log.d(TAG, "onDetachedFromEngine: secondary engine was last, destroying SDK")
                sdk.destroyAll()
            }
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        Log.d(TAG, "onAttachedToActivity")
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
        sdk.activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        Log.d(TAG, "onDetachedFromActivityForConfigChanges")
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        sdk.activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        Log.d(TAG, "onReattachedToActivityForConfigChanges")
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
        sdk.activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        Log.d(TAG, "onDetachedFromActivity")
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        sdk.activity = null
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        return sdk.handlePermissionResult(requestCode, permissions, grantResults)
    }

    private fun requestTokenRefreshFromDart(handler: Handler): Boolean {
        val latch = java.util.concurrent.CountDownLatch(1)
        var success = false
        handler.post {
            syncBodyChannel?.invokeMethod("requestTokenRefresh", null, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    success = result as? Boolean ?: false
                    latch.countDown()
                }
                override fun error(code: String, msg: String?, details: Any?) { latch.countDown() }
                override fun notImplemented() { latch.countDown() }
            })
        }
        latch.await(DART_CALLBACK_TIMEOUT_MS, java.util.concurrent.TimeUnit.MILLISECONDS)
        return success
    }

    private fun requestFreshHeadersFromDart(handler: Handler): Boolean {
        val latch = java.util.concurrent.CountDownLatch(1)
        var success = false
        handler.post {
            syncBodyChannel?.invokeMethod("requestFreshHeaders", null, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    success = result as? Boolean ?: false
                    latch.countDown()
                }
                override fun error(code: String, msg: String?, details: Any?) { latch.countDown() }
                override fun notImplemented() { latch.countDown() }
            })
        }
        latch.await(DART_CALLBACK_TIMEOUT_MS, java.util.concurrent.TimeUnit.MILLISECONDS)
        return success
    }

    private fun requestSyncBodyFromDart(handler: Handler, locations: List<Map<String, Any?>>): String? {
        val latch = java.util.concurrent.CountDownLatch(1)
        var body: String? = null
        handler.post {
            syncBodyChannel?.invokeMethod("buildSyncBody", locations, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    body = result as? String
                    latch.countDown()
                }
                override fun error(code: String, msg: String?, details: Any?) { latch.countDown() }
                override fun notImplemented() { latch.countDown() }
            })
        }
        latch.await(DART_CALLBACK_TIMEOUT_MS, java.util.concurrent.TimeUnit.MILLISECONDS)
        return body
    }
}
