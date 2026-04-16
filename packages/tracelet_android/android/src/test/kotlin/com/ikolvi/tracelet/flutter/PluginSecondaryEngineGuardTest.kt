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
 * These tests verify the guard prevents all three failure modes.
 */
internal class PluginSecondaryEngineGuardTest {

    private lateinit var mockSdk: TraceletSdk

    @BeforeTest
    fun setUp() {
        // Reset the static primaryInstance before each test
        resetPrimaryInstance()

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
     * When a secondary FlutterEngine registers a new plugin instance
     * (e.g. from FirebaseMessaging background isolate), the SDK's event
     * sender must NOT be replaced — it should remain connected to the
     * primary (foreground) engine.
     *
     * RED with old code: setEventSender was called unconditionally.
     * GREEN with fix: secondary instance skips setEventSender.
     */
    @Test
    fun secondaryInstance_doesNotReplaceEventSender() {
        val primaryPlugin = TraceletAndroidPlugin()
        val secondaryPlugin = TraceletAndroidPlugin()

        val primaryBinding = createMockBinding("primary")
        val secondaryBinding = createMockBinding("secondary")

        // Attach primary first
        primaryPlugin.onAttachedToEngine(primaryBinding)

        // Reset call counts so we only track secondary's behavior
        org.mockito.Mockito.clearInvocations(mockSdk)

        // Attach secondary (simulates Firebase background engine)
        secondaryPlugin.onAttachedToEngine(secondaryBinding)

        // SDK event sender must NOT be touched by secondary
        verify(mockSdk, never()).setEventSender(any())
        verify(mockSdk, never()).initialize()
    }

    /**
     * When the secondary (background) engine detaches, `sdk.destroyAll()`
     * must NOT be called — it would destroy the foreground tracking pipeline.
     *
     * RED with old code: destroyAll was called unconditionally.
     * GREEN with fix: secondary instance skips destroyAll.
     */
    @Test
    fun secondaryDetach_doesNotDestroySDK() {
        val primaryPlugin = TraceletAndroidPlugin()
        val secondaryPlugin = TraceletAndroidPlugin()

        val primaryBinding = createMockBinding("primary")
        val secondaryBinding = createMockBinding("secondary")

        // Attach both
        primaryPlugin.onAttachedToEngine(primaryBinding)
        secondaryPlugin.onAttachedToEngine(secondaryBinding)

        org.mockito.Mockito.clearInvocations(mockSdk)

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
     * Full lifecycle: primary attaches → secondary attaches → secondary
     * detaches → primary still works. Simulates the complete Firebase
     * background message scenario.
     */
    @Test
    fun fullLifecycle_primarySurvivesSecondaryEngineLifecycle() {
        val primaryPlugin = TraceletAndroidPlugin()
        val secondaryPlugin = TraceletAndroidPlugin()

        val primaryBinding = createMockBinding("primary")
        val secondaryBinding = createMockBinding("secondary")

        // 1. Primary attaches (app starts)
        primaryPlugin.onAttachedToEngine(primaryBinding)
        verify(mockSdk).setEventSender(any())
        verify(mockSdk).initialize()

        // 2. Secondary attaches (Firebase background message arrives)
        org.mockito.Mockito.clearInvocations(mockSdk)
        secondaryPlugin.onAttachedToEngine(secondaryBinding)
        verify(mockSdk, never()).setEventSender(any())
        verify(mockSdk, never()).initialize()

        // 3. Secondary detaches (Firebase message processed)
        secondaryPlugin.onDetachedFromEngine(secondaryBinding)
        verify(mockSdk, never()).destroyAll()

        // 4. Primary is still alive — detach it normally
        primaryPlugin.onDetachedFromEngine(primaryBinding)
        verify(mockSdk).destroyAll()
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
}
