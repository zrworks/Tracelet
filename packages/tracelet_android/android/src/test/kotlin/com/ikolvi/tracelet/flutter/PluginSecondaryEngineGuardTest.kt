package com.ikolvi.tracelet.flutter

import android.content.Context
import android.content.SharedPreferences
import com.ikolvi.tracelet.sdk.TraceletSdk
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import org.mockito.Mockito.clearInvocations
import org.mockito.Mockito.mock
import org.mockito.Mockito.never
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import org.mockito.kotlin.any
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test

/**
 * Tests that the primary-instance guard in [TraceletAndroidPlugin] prevents
 * secondary FlutterEngine registrations from corrupting the SDK singleton.
 *
 * **Background**: When a plugin that spawns a background Dart isolate
 * (e.g. `FirebaseMessaging.onBackgroundMessage`) creates a temporary
 * FlutterEngine, `GeneratedPluginRegistrant` auto-registers ALL plugins
 * on that engine — including TraceletAndroidPlugin. Without a guard, the
 * secondary instance would:
 * 1. Replace the SDK's event sender with one connected to the wrong isolate
 * 2. Re-initialize all subsystems (LocationEngine, GeofenceManager, etc.)
 * 3. Call `sdk.destroyAll()` on detach — killing the foreground pipeline
 *
 * **Secondary engine discriminator** (Looper heuristic, issue #overlay):
 * When a secondary engine is an **in-process UI engine** (e.g.
 * `flutter_overlay_window` via `FlutterEngineGroup`), it attaches on the
 * main thread. The SDK's EventDispatcher must be re-bound to that engine's
 * messenger so Pigeon FlutterApi messages are delivered correctly.
 * When the secondary engine is a **headless background engine** (Firebase,
 * HeadlessTaskService), it attaches on a background thread and must be
 * fully skipped to preserve the #51 fix.
 *
 * These tests verify all three failure modes plus both discriminator branches.
 */
internal class PluginSecondaryEngineGuardTest {

    private lateinit var mockSdk: TraceletSdk

    @BeforeTest
    fun setUp() {
        // Reset the static primaryInstance before each test
        resetPrimaryInstance()
        // Default: simulate main-thread attach (primary engine behaviour)
        setIsMainThread(true)

        // Inject a mock TraceletSdk into the singleton field so that
        // TraceletSdk.getInstance(context) returns our mock without
        // needing mockStatic (avoids matcher issues).
        mockSdk = mock(TraceletSdk::class.java)
        val instanceField = TraceletSdk::class.java.getDeclaredField("instance")
        instanceField.isAccessible = true
        instanceField.set(null, mockSdk)
    }

    @AfterTest
    fun tearDown() {
        // Clear the singleton so it doesn't leak between tests
        val instanceField = TraceletSdk::class.java.getDeclaredField("instance")
        instanceField.isAccessible = true
        instanceField.set(null, null)
        resetPrimaryInstance()
        // Restore production Looper check so other test classes are unaffected
        restoreIsMainThread()
    }

    // =========================================================================
    // Tests
    // =========================================================================

    /**
     * Primary (foreground) plugin instance should initialize the SDK
     * and set the event sender.
     */
    @Test
    fun primaryInstance_initializesSDK() {
        val primaryPlugin = TraceletAndroidPlugin()
        val primaryBinding = createMockBinding("primary")

        primaryPlugin.onAttachedToEngine(primaryBinding)

        verify(mockSdk).setEventSender(any())
        verify(mockSdk).initialize()
    }

    /**
     * When a **headless** secondary FlutterEngine registers a new plugin
     * instance (e.g. from FirebaseMessaging.onBackgroundMessage), the SDK's
     * event sender must NOT be replaced — it should remain connected to the
     * primary (foreground) engine.
     *
     * Simulates a background-thread attach by stubbing [isMainThread] to
     * return `false`.
     *
     * RED with old code: setEventSender was called unconditionally.
     * GREEN with fix: headless secondary skips setEventSender.
     */
    @Test
    fun secondaryInstance_doesNotReplaceEventSender() {
        val primaryPlugin = TraceletAndroidPlugin()
        val secondaryPlugin = TraceletAndroidPlugin()

        val primaryBinding = createMockBinding("primary")
        val secondaryBinding = createMockBinding("secondary")

        // Attach primary (main thread — default stub)
        primaryPlugin.onAttachedToEngine(primaryBinding)
        clearInvocations(mockSdk)

        // Simulate headless engine: stub isMainThread to return false
        setIsMainThread(false)
        secondaryPlugin.onAttachedToEngine(secondaryBinding)

        // SDK event sender must NOT be touched by headless secondary
        verify(mockSdk, never()).setEventSender(any())
        verify(mockSdk, never()).initialize()
    }

    /**
     * When the **headless** secondary engine detaches, `sdk.destroyAll()`
     * must NOT be called — it would destroy the foreground tracking pipeline.
     *
     * Simulates a background-thread attach by stubbing [isMainThread] to
     * return `false`.
     *
     * RED with old code: destroyAll was called unconditionally.
     * GREEN with fix: headless secondary skips destroyAll.
     */
    @Test
    fun secondaryDetach_doesNotDestroySDK() {
        val primaryPlugin = TraceletAndroidPlugin()
        val secondaryPlugin = TraceletAndroidPlugin()

        val primaryBinding = createMockBinding("primary")
        val secondaryBinding = createMockBinding("secondary")

        // Attach primary (main thread — default stub)
        primaryPlugin.onAttachedToEngine(primaryBinding)
        // Attach secondary as headless engine
        setIsMainThread(false)
        secondaryPlugin.onAttachedToEngine(secondaryBinding)
        setIsMainThread(true)

        clearInvocations(mockSdk)

        // Detach secondary (Firebase background engine done)
        secondaryPlugin.onDetachedFromEngine(secondaryBinding)

        // SDK must NOT be destroyed
        verify(mockSdk, never()).destroyAll()
    }

    /**
     * The primary (foreground) plugin detaching SHOULD destroy the SDK
     * (normal app lifecycle).
     */
    @Test
    fun primaryDetach_destroysSDK() {
        val primaryPlugin = TraceletAndroidPlugin()
        val primaryBinding = createMockBinding("primary")

        primaryPlugin.onAttachedToEngine(primaryBinding)
        org.mockito.Mockito.clearInvocations(mockSdk)

        primaryPlugin.onDetachedFromEngine(primaryBinding)

        verify(mockSdk).destroyAll()
    }

    /**
     * Full lifecycle: primary attaches → headless secondary attaches →
     * secondary detaches → primary still works. Simulates the complete
     * Firebase background message scenario.
     *
     * Uses [isMainThread] stub: `false` for secondary attach, `true` otherwise.
     */
    @Test
    fun fullLifecycle_primarySurvivesSecondaryEngineLifecycle() {
        val primaryPlugin = TraceletAndroidPlugin()
        val secondaryPlugin = TraceletAndroidPlugin()

        val primaryBinding = createMockBinding("primary")
        val secondaryBinding = createMockBinding("secondary")

        // 1. Primary attaches (main thread)
        primaryPlugin.onAttachedToEngine(primaryBinding)
        verify(mockSdk).setEventSender(any())
        verify(mockSdk).initialize()

        // 2. Secondary attaches as headless engine (background thread)
        clearInvocations(mockSdk)
        setIsMainThread(false)
        secondaryPlugin.onAttachedToEngine(secondaryBinding)
        setIsMainThread(true)
        verify(mockSdk, never()).setEventSender(any())
        verify(mockSdk, never()).initialize()

        // 3. Secondary detaches (Firebase message processed)
        secondaryPlugin.onDetachedFromEngine(secondaryBinding)
        verify(mockSdk, never()).destroyAll()

        // 4. Primary is still alive — detach it normally
        primaryPlugin.onDetachedFromEngine(primaryBinding)
        verify(mockSdk).destroyAll()
    }

    /**
     * Secondary in-process UI engine (main-thread attach, e.g.
     * `flutter_overlay_window` via `FlutterEngineGroup`) should re-bind
     * the EventDispatcher to its own BinaryMessenger so Pigeon FlutterApi
     * messages are delivered to the primary Dart isolate.
     *
     * Crucially, `initialize()` must NOT be called again — only
     * `setEventSender()` must be invoked to re-point the SDK's dispatcher.
     *
     * Uses the default [isMainThread] stub (`true`) — no extra setup needed.
     */
    @Test
    fun secondaryMainThreadEngine_rebindsDispatcherOnly() {
        val primaryPlugin = TraceletAndroidPlugin()
        val secondaryPlugin = TraceletAndroidPlugin()

        val primaryBinding = createMockBinding("primary")
        // Secondary binding uses a DIFFERENT messenger — simulates overlay engine
        val overlayBinding = createMockBinding("overlay")

        // Attach primary (normal app start)
        primaryPlugin.onAttachedToEngine(primaryBinding)
        clearInvocations(mockSdk)

        // isMainThread stub is already true (set in setUp) — simulates overlay engine
        secondaryPlugin.onAttachedToEngine(overlayBinding)

        // The SDK's event sender MUST be updated to the overlay messenger
        verify(mockSdk).setEventSender(any())
        // But initialize() must NOT be called — no subsystem re-init
        verify(mockSdk, never()).initialize()
    }

    /**
     * Secondary off-thread engine (background-thread attach, e.g.
     * `FirebaseMessaging.onBackgroundMessage`) must be fully skipped.
     *
     * Stubs [isMainThread] to return `false` to exercise the headless-skip
     * branch without needing a real background thread.
     */
    @Test
    fun secondaryBackgroundThreadEngine_fullySkipped() {
        val primaryPlugin = TraceletAndroidPlugin()
        val secondaryPlugin = TraceletAndroidPlugin()

        val primaryBinding = createMockBinding("primary")
        val headlessBinding = createMockBinding("headless")

        // Attach primary (main thread — default stub)
        primaryPlugin.onAttachedToEngine(primaryBinding)
        clearInvocations(mockSdk)

        // Simulate headless engine: stub isMainThread to return false
        setIsMainThread(false)
        secondaryPlugin.onAttachedToEngine(headlessBinding)

        // SDK must NOT be touched at all — full skip (#51 preserved)
        verify(mockSdk, never()).setEventSender(any())
        verify(mockSdk, never()).initialize()
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    private fun createMockBinding(label: String): FlutterPlugin.FlutterPluginBinding {
        val messenger = mock(BinaryMessenger::class.java)
        val context = mock(Context::class.java)
        val headlessPrefs = mock(SharedPreferences::class.java)
        val headlessEditor = mock(SharedPreferences.Editor::class.java)

        `when`(context.applicationContext).thenReturn(context)
        `when`(context.getSharedPreferences(any(), any<Int>())).thenReturn(headlessPrefs)
        `when`(headlessPrefs.edit()).thenReturn(headlessEditor)
        `when`(headlessPrefs.contains(any())).thenReturn(false)
        `when`(headlessPrefs.getLong(any(), any())).thenReturn(-1L)

        val binding = mock(FlutterPlugin.FlutterPluginBinding::class.java)
        `when`(binding.binaryMessenger).thenReturn(messenger)
        `when`(binding.applicationContext).thenReturn(context)

        return binding
    }

    /**
     * Resets the companion object's [primaryInstance] static field via
     * reflection so tests don't leak state.
     */
    private fun resetPrimaryInstance() {
        // Kotlin @JvmStatic companion vars are compiled to a static field
        // on the outer class itself.
        val field = TraceletAndroidPlugin::class.java.getDeclaredField("primaryInstance")
        field.isAccessible = true
        field.set(null, null)
    }

    /**
     * Stubs [TraceletAndroidPlugin.isMainThread] to return [value] for the
     * duration of the current test. Call [restoreIsMainThread] in tearDown
     * to reset to the real Looper check.
     */
    private fun setIsMainThread(value: Boolean) {
        val field = TraceletAndroidPlugin::class.java.getDeclaredField("isMainThread")
        field.isAccessible = true
        field.set(null, { value })
    }

    /**
     * Restores [TraceletAndroidPlugin.isMainThread] to the production default
     * (real Looper check). Called in [tearDown] so other test classes are
     * unaffected.
     */
    private fun restoreIsMainThread() {
        val field = TraceletAndroidPlugin::class.java.getDeclaredField("isMainThread")
        field.isAccessible = true
        // Restore the default production lambda (real Looper check)
        @Suppress("ObjectLiteralToLambda")
        field.set(null, object : Function0<Boolean> {
            override fun invoke(): Boolean =
                android.os.Looper.myLooper() == android.os.Looper.getMainLooper()
        })
    }
}
