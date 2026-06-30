package com.ikolvi.tracelet.sdk

import android.Manifest
import android.content.Context
import android.os.Looper
import androidx.test.core.app.ApplicationProvider
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Regression for #230 — runtime config changes (setConfig) must propagate to the
 * active native tracking pipeline. Previously only a few location keys triggered
 * a restart, and only the LocationEngine was restarted, so motion-detector /
 * speed-manager parameter changes (e.g. switching ACCELEROMETER → SPEED) were
 * silently ignored until the app was force-killed.
 *
 * The restart performs a clean stop()/start() of the active pipeline, which is
 * observable here through the enabledChange(false)→(true) lifecycle events.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class SetConfigRestartTest {

    private lateinit var context: Context
    private lateinit var sdk: TraceletSdk
    private lateinit var sender: ListenerEventSender
    private val enabledChanges = mutableListOf<Boolean>()

    @Before
    fun setUp() {
        org.robolectric.shadows.ShadowLog.stream = System.out
        context = ApplicationProvider.getApplicationContext()

        // start()/stop() touch WorkManager (PeriodicLocationWorker.cancel) — stand
        // up the in-memory test scheduler so those calls don't throw.
        androidx.work.testing.WorkManagerTestInitHelper.initializeTestWorkManager(
            context,
            androidx.work.Configuration.Builder()
                .setExecutor(androidx.work.testing.SynchronousExecutor())
                .build(),
        )

        val shadowApp = shadowOf(context as android.app.Application)
        shadowApp.grantPermissions(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION,
            Manifest.permission.ACCESS_BACKGROUND_LOCATION,
            Manifest.permission.ACTIVITY_RECOGNITION,
        )

        sender = ListenerEventSender()
        sender.listener = object : TraceletListener {
            override fun onEnabledChange(enabled: Boolean) { enabledChanges.add(enabled) }
        }

        sdk = TraceletSdk.getInstance(context)
        sdk.setEventSender(sender)
        sdk.initialize()
    }

    @After
    fun tearDown() {
        try { sdk.stop() } catch (_: Exception) {}
        idle()
        ConfigManager.resetInstance()
        enabledChanges.clear()
    }

    private fun idle() = shadowOf(Looper.getMainLooper()).idle()

    private fun ready(config: Map<String, Any?>) {
        var done = false
        sdk.ready(
            config + mapOf(
                "foregroundService" to false,
                "stopOnStationary" to false,
                "isMoving" to true,
            ),
        ) { done = true }
        idle()
        assertTrue(done, "ready() callback should fire")
    }

    @Test
    fun `changing motionDetectionMode at runtime restarts the active pipeline`() {
        ready(mapOf("motionDetectionMode" to 0)) // ACCELEROMETER
        sdk.start()
        idle()
        assertTrue(enabledChanges.contains(true), "start() should emit enabledChange(true)")

        enabledChanges.clear()

        // Switch ACCELEROMETER → SPEED. This is a motion-only key the old code
        // ignored — it must now trigger a full stop/start of the pipeline.
        sdk.setConfig(mapOf("motionDetectionMode" to 1)) // SPEED
        idle()

        assertTrue(
            enabledChanges.contains(false) && enabledChanges.contains(true),
            "motion mode change must restart the pipeline (saw enabledChanges=$enabledChanges)",
        )
        assertEquals(false, enabledChanges.first(), "restart must stop before starting")
        assertEquals(true, enabledChanges.last(), "restart must leave tracking enabled")
        assertTrue(sdk.stateManager.enabled, "tracking should remain enabled after restart")
    }

    @Test
    fun `changing an unrelated config key does not restart the pipeline`() {
        ready(mapOf("motionDetectionMode" to 0))
        sdk.start()
        idle()
        enabledChanges.clear()

        // A non-tracking key — must NOT churn the active pipeline.
        sdk.setConfig(mapOf("stopOnTerminate" to true))
        idle()

        assertTrue(
            enabledChanges.isEmpty(),
            "unrelated config change must not restart tracking (saw $enabledChanges)",
        )
    }
}
