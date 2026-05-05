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
import com.ikolvi.tracelet.sdk.http.HttpSyncManager
import com.ikolvi.tracelet.TraceletHostApi
import com.ikolvi.tracelet.flutter.service.HeadlessTaskService
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * TraceletAndroidPlugin — Slim Flutter bridge for Tracelet.
 *
 * All engine logic lives in [TraceletSdk]. This class only handles:
 * - Flutter plugin lifecycle (attach/detach)
 * - EventDispatcher creation & injection (Pigeon FlutterApi)
 * - Pigeon HostApi registration
 * - Activity lifecycle & permission result forwarding
 * - Flutter-specific: headless tasks, emailLog, device info
 */
class TraceletAndroidPlugin :
    FlutterPlugin,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

    companion object {
        private const val TAG = "TraceletAndroidPlugin"
        /** Timeout for Dart callback round-trips (headers refresh, sync body). */
        private const val DART_CALLBACK_TIMEOUT_MS = 10_000L

        /**
         * Reference to the primary (foreground) plugin instance.
         *
         * When a headless [FlutterEngine] is created (e.g., by
         * [HeadlessTaskService]), [GeneratedPluginRegistrant] registers
         * all plugins on that engine, triggering a second
         * [onAttachedToEngine] on a NEW plugin instance. That instance
         * must NOT overwrite the [httpSyncManager] callbacks — those
         * belong to the foreground engine's MethodChannel.
         */
        @Volatile
        @JvmStatic
        private var primaryInstance: TraceletAndroidPlugin? = null

        /**
         * Returns true when the calling thread is the Android main (UI) thread.
         *
         * Exposed as an internal `@JvmField` lambda so unit tests can stub it
         * via reflection without Robolectric. Production code must never
         * reassign this field.
         */
        @JvmField
        internal var isMainThread: () -> Boolean = {
            Looper.myLooper() == Looper.getMainLooper()
        }
    }

    private lateinit var context: Context
    private lateinit var eventDispatcher: EventDispatcher
    private lateinit var headlessService: HeadlessTaskService

    private var activityBinding: ActivityPluginBinding? = null
    private var syncBodyChannel: MethodChannel? = null
    @Volatile private var isEngineAttached = false

    private val sdk: TraceletSdk get() = TraceletSdk.getInstance(context)

    // =========================================================================
    // FlutterPlugin lifecycle
    // =========================================================================

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        isEngineAttached = true

        // ── Primary instance guard ───────────────────────────────────────
        // When a background FlutterEngine is created (by HeadlessTaskService,
        // FirebaseMessaging.onBackgroundMessage, or any other plugin that
        // spawns a background isolate), GeneratedPluginRegistrant registers
        // ALL plugins on that engine, triggering onAttachedToEngine on a
        // NEW TraceletAndroidPlugin instance.
        //
        // Two distinct secondary-engine scenarios require different handling:
        //
        //   (A) IN-PROCESS UI ENGINE (e.g. flutter_overlay_window via
        //       FlutterEngineGroup). These engines attach on the MAIN thread
        //       and live for the app's lifetime. On Flutter 3.22+ with
        //       FlutterEngineGroup, the primary engine's BinaryMessenger
        //       stops routing Pigeon FlutterApi messages back to the primary
        //       Dart isolate once a second engine attaches. Re-binding the
        //       EventDispatcher to the secondary engine's messenger restores
        //       delivery (the secondary messenger does route correctly in
        //       this configuration). SDK sub-systems are NOT re-initialized.
        //
        //   (B) HEADLESS BACKGROUND ENGINE (e.g. Firebase background message
        //       handler, HeadlessTaskService). These engines attach on a
        //       BACKGROUND thread. Letting them touch the SDK singleton
        //       routes events to the wrong short-lived isolate and causes
        //       destroyAll() on detach to kill the foreground pipeline (#51).
        //       These must be fully skipped.
        //
        // Discriminator: Looper.myLooper() == Looper.getMainLooper()
        //   • true  → scenario (A): re-bind dispatcher only
        //   • false → scenario (B): skip everything (preserves #51 fix)
        //
        // Guard: Only the first (primary/foreground) instance — or the
        // same instance on hot restart — fully initializes the SDK and
        // wires callbacks.
        val isPrimary = primaryInstance == null || primaryInstance === this
        if (isPrimary) {
            primaryInstance = this

            // Event dispatcher (Pigeon FlutterApi → Dart)
            eventDispatcher = EventDispatcher()
            eventDispatcher.register(binding.binaryMessenger)

            // Inject event sender and initialize SDK
            sdk.setEventSender(eventDispatcher)
            sdk.initialize()

            // Flutter-specific: headless task service
            headlessService = HeadlessTaskService(context, sdk.configManager)

            val mainHandler = Handler(Looper.getMainLooper())
            syncBodyChannel = MethodChannel(binding.binaryMessenger, "com.tracelet/sync_body")

            // Wire 401 → foreground token refresh, headless fallback
            HttpSyncManager.onAuthorizationRequired = {
                // Try foreground engine first
                if (isEngineAttached && Looper.myLooper() != Looper.getMainLooper()) {
                    val refreshed = requestTokenRefreshFromDart(mainHandler)
                    if (refreshed) {
                        true
                    } else {
                        // Fallback to headless service
                        headlessService.requestHeadersRefresh(DART_CALLBACK_TIMEOUT_MS)
                    }
                } else {
                    headlessService.requestHeadersRefresh(DART_CALLBACK_TIMEOUT_MS)
                }
            }

            HttpSyncManager.onRequestFreshHeaders = {
                // Try foreground engine first
                if (isEngineAttached && Looper.myLooper() != Looper.getMainLooper()) {
                    val refreshed = requestFreshHeadersFromDart(mainHandler)
                    if (!refreshed) {
                        // Fallback to headless service
                        headlessService.requestHeadersRefresh(DART_CALLBACK_TIMEOUT_MS)
                    }
                } else {
                    headlessService.requestHeadersRefresh(DART_CALLBACK_TIMEOUT_MS)
                }
            }

            // Wire custom sync body builder (foreground → MethodChannel, headless → fallback)
            HttpSyncManager.onBuildCustomSyncBody = buildCustomSyncBodyCallback@{ locations ->
                // Try foreground engine first
                if (isEngineAttached && Looper.myLooper() != Looper.getMainLooper()) {
                    val result = requestSyncBodyFromDart(mainHandler, locations)
                    if (result != null) return@buildCustomSyncBodyCallback result
                }
                // Fallback to headless service
                headlessService.requestCustomSyncBody(locations, DART_CALLBACK_TIMEOUT_MS)
            }

            // Wire headless fallback for background events
            eventDispatcher.headlessFallback = { eventName, eventData ->
                if (headlessService.isRegistered()) {
                    headlessService.dispatchEvent(eventName, eventData)
                }
            }

            // Bootstrap factory for headless dispatcher
            TraceletBootstrap.headlessDispatcherFactory = { ctx ->
                HeadlessTaskService(ctx)
            }

            // Override event sender factory so boot/task-removal restarts
            // produce an EventDispatcher with headlessFallback properly wired.
            // Without this, geofence events fired after task removal are
            // silently dropped because the EventDispatcher has no fallback.
            TraceletBootstrap.eventSenderFactory = { ctx ->
                val dispatcher = EventDispatcher()
                val hs = HeadlessTaskService(ctx)
                dispatcher.headlessFallback = { eventName, eventData ->
                    if (hs.isRegistered()) {
                        hs.dispatchEvent(eventName, eventData)
                    }
                }
                dispatcher
            }

            Log.d(TAG, "onAttachedToEngine: primary instance — SDK initialized, callbacks wired")
        } else {
            // ── Secondary engine discriminator ───────────────────────────
            // Main-thread attach → in-process UI engine (e.g. flutter_overlay_window
            // via FlutterEngineGroup). Re-bind the EventDispatcher so the SDK
            // routes events through the messenger that actually delivers to the
            // primary Dart isolate on this Flutter/engine-group configuration.
            // SDK sub-systems (location engine, geofence manager, etc.) are NOT
            // re-initialized — only the Pigeon FlutterApi channel is re-pointed.
            //
            // Off-thread attach → headless background engine (e.g. Firebase
            // background messaging, HeadlessTaskService). Skip everything to
            // preserve the #51 fix — events must not be routed to a wrong isolate.
            val isMainThread = isMainThread()
            if (isMainThread) {
                // Re-bind dispatcher to the secondary (overlay) engine's messenger.
                // The headlessFallback from the primary attach is deliberately
                // preserved — it references the HeadlessTaskService that was
                // constructed with the full configManager during primary init.
                eventDispatcher = EventDispatcher()
                eventDispatcher.register(binding.binaryMessenger)
                if (::headlessService.isInitialized) {
                    eventDispatcher.headlessFallback = { eventName, eventData ->
                        if (headlessService.isRegistered()) {
                            headlessService.dispatchEvent(eventName, eventData)
                        }
                    }
                }
                sdk.setEventSender(eventDispatcher)
                Log.d(
                    TAG,
                    "onAttachedToEngine: secondary in-process UI engine (main thread) — " +
                        "re-bound EventDispatcher to overlay messenger",
                )
            } else {
                // Headless/background engine — full skip (preserves #51).
                Log.d(
                    TAG,
                    "onAttachedToEngine: secondary headless engine (background thread) — " +
                        "skipping SDK init & callback wiring",
                )
            }
        }

        // Pigeon API: register on EVERY engine so host API calls from
        // background isolates (e.g. setDynamicHeaders) still work.
        // HeadlessTaskService is safe to construct without configManager
        // for secondary instances — it only needs context for SharedPrefs.
        val hostApiHeadless = if (isPrimary) headlessService else HeadlessTaskService(context)
        TraceletHostApi.setUp(
            binding.binaryMessenger,
            TraceletHostApiImpl(context, hostApiHeadless),
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        isEngineAttached = false
        TraceletHostApi.setUp(binding.binaryMessenger, null)

        if (primaryInstance === this) {
            primaryInstance = null
            syncBodyChannel = null
            HttpSyncManager.onAuthorizationRequired = null
            HttpSyncManager.onRequestFreshHeaders = null
            HttpSyncManager.onBuildCustomSyncBody = null
            eventDispatcher.unregister()
            sdk.destroyAll()
            headlessService.destroy()
        } else {
            Log.d(TAG, "onDetachedFromEngine: secondary instance — skipping SDK destroy")
        }
    }

    // =========================================================================
    // Custom Sync Body (foreground MethodChannel)
    // =========================================================================

    /**
     * Request a custom sync body from Dart via the foreground FlutterEngine.
     *
     * Invokes `buildSyncBody` on `com.tracelet/sync_body` MethodChannel and
     * blocks on a CountDownLatch until Dart responds. Runs on the sync
     * executor thread — must NOT be called on the main thread.
     */
    private fun requestSyncBodyFromDart(
        mainHandler: Handler,
        locations: List<Map<String, Any?>>,
    ): String? {
        val channel = syncBodyChannel ?: return null
        val latch = java.util.concurrent.CountDownLatch(1)
        var result: String? = null

        mainHandler.post {
            channel.invokeMethod(
                "buildSyncBody",
                locations,
                object : MethodChannel.Result {
                    override fun success(r: Any?) {
                        result = r as? String
                        latch.countDown()
                    }
                    override fun error(code: String, msg: String?, details: Any?) {
                        Log.w(TAG, "buildSyncBody Dart error: $code — $msg")
                        latch.countDown()
                    }
                    override fun notImplemented() {
                        latch.countDown()
                    }
                },
            )
        }

        val completed = latch.await(DART_CALLBACK_TIMEOUT_MS, java.util.concurrent.TimeUnit.MILLISECONDS)
        if (!completed) {
            Log.w(TAG, "buildSyncBody timed out waiting for Dart response")
        }
        return result
    }

    // =========================================================================
    // Fresh Headers (foreground MethodChannel)
    // =========================================================================

    /**
     * Request fresh headers from Dart via the foreground FlutterEngine.
     *
     * Invokes `requestFreshHeaders` on `com.tracelet/sync_body` MethodChannel.
     * Dart's handler calls _headersCallback → setDynamicHeaders, updating
     * ConfigManager before the sync request proceeds.
     *
     * Blocks on a CountDownLatch — must NOT be called on the main thread.
     */
    private fun requestFreshHeadersFromDart(mainHandler: Handler): Boolean {
        val channel = syncBodyChannel ?: return false
        val latch = java.util.concurrent.CountDownLatch(1)
        var success = false

        mainHandler.post {
            channel.invokeMethod(
                "requestFreshHeaders",
                null,
                object : MethodChannel.Result {
                    override fun success(r: Any?) {
                        success = (r as? Boolean) ?: false
                        latch.countDown()
                    }
                    override fun error(code: String, msg: String?, details: Any?) {
                        Log.w(TAG, "requestFreshHeaders Dart error: $code — $msg")
                        latch.countDown()
                    }
                    override fun notImplemented() {
                        Log.w(TAG, "requestFreshHeaders: Dart handler not registered")
                        latch.countDown()
                    }
                },
            )
        }

        val completed = latch.await(DART_CALLBACK_TIMEOUT_MS, java.util.concurrent.TimeUnit.MILLISECONDS)
        if (!completed) {
            Log.w(TAG, "requestFreshHeaders timed out after ${DART_CALLBACK_TIMEOUT_MS}ms")
        }
        return success
    }

    // =========================================================================
    // Token Refresh — 401 recovery (foreground MethodChannel)
    // =========================================================================

    /**
     * Request a token refresh from Dart via the foreground FlutterEngine.
     *
     * Invokes `requestTokenRefresh` on `com.tracelet/sync_body` MethodChannel.
     * Dart's handler calls _tokenRefreshCallback (which should refresh the
     * token from the auth API) → setDynamicHeaders, updating ConfigManager.
     *
     * Blocks on a CountDownLatch — must NOT be called on the main thread.
     */
    private fun requestTokenRefreshFromDart(mainHandler: Handler): Boolean {
        val channel = syncBodyChannel ?: return false
        val latch = java.util.concurrent.CountDownLatch(1)
        var success = false

        mainHandler.post {
            channel.invokeMethod(
                "requestTokenRefresh",
                null,
                object : MethodChannel.Result {
                    override fun success(r: Any?) {
                        success = (r as? Boolean) ?: false
                        latch.countDown()
                    }
                    override fun error(code: String, msg: String?, details: Any?) {
                        Log.w(TAG, "requestTokenRefresh Dart error: $code — $msg")
                        latch.countDown()
                    }
                    override fun notImplemented() {
                        latch.countDown()
                    }
                },
            )
        }

        val completed = latch.await(DART_CALLBACK_TIMEOUT_MS, java.util.concurrent.TimeUnit.MILLISECONDS)
        if (!completed) {
            Log.w(TAG, "requestTokenRefresh timed out waiting for Dart response")
        }
        return success
    }

    // =========================================================================
    // ActivityAware lifecycle
    // =========================================================================

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        sdk.activity = binding.activity
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        sdk.activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        sdk.activity = binding.activity
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        // Invoke and clear any pending permission callback so the Dart
        // Future doesn't hang forever when the Activity is destroyed
        // while a permission dialog is showing.
        sdk.clearPendingPermissionCallback()
        sdk.activity = null
    }

    // =========================================================================
    // Permission result forwarding
    // =========================================================================

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        return sdk.handlePermissionResult(requestCode, permissions, grantResults)
    }
}
