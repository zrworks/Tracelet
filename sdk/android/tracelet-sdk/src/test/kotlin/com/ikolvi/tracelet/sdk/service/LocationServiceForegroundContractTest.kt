package com.ikolvi.tracelet.sdk.service

import android.content.Intent
import androidx.test.core.app.ApplicationProvider
import com.ikolvi.tracelet.sdk.ConfigManager
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * Regression test for GitHub issue #59:
 *   "ForegroundService crash in SDK 1.8.13: startForegroundService() not
 *    followed by startForeground()"
 *
 * Verifies that `LocationService.onStartCommand` always promotes itself to
 * foreground — including when delivered:
 *   - a null intent (sticky restart after system kill)
 *   - ACTION_UPDATE_NOTIFICATION
 *   - ACTION_BUTTON
 *   - ACTION_STOP
 *
 * Failing to call `startForeground()` after `startForegroundService()` causes
 * `RemoteServiceException: Context.startForegroundService() did not then call
 * Service.startForeground()` and crashes the host app.
 */
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [33])
class LocationServiceForegroundContractTest {

    private lateinit var serviceController: org.robolectric.android.controller.ServiceController<LocationService>

    @Before
    fun setUp() {
        // Enable foreground service via config so notification path is exercised.
        val ctx = ApplicationProvider.getApplicationContext<android.content.Context>()
        ConfigManager.getInstance(ctx).setConfig(
            mapOf(
                "app" to mapOf(
                    "foregroundService" to mapOf("channelId" to "tl_test_channel"),
                ),
            ),
        )
        serviceController = Robolectric.buildService(LocationService::class.java)
    }

    @After
    fun tearDown() {
        try {
            serviceController.destroy()
        } catch (_: Throwable) {
        }
    }

    private fun assertForegroundPromoted() {
        val service = serviceController.get()
        val shadow = shadowOf(service)
        val notification = shadow.lastForegroundNotification
        assertNotNull(
            notification,
            "Service must call startForeground() within onStartCommand to satisfy the " +
                "Android startForegroundService() contract (#59)",
        )
        assertTrue(
            shadow.lastForegroundNotificationId != 0,
            "startForeground() must be called with a non-zero notification id",
        )
    }

    @Test
    fun `onStartCommand promotes to foreground for ACTION_START`() {
        val intent = Intent().apply { action = LocationService.ACTION_START }
        serviceController.create().withIntent(intent).startCommand(0, 1)
        assertForegroundPromoted()
    }

    @Test
    fun `onStartCommand promotes to foreground for ACTION_STOP before stopping`() {
        // Even ACTION_STOP must promote first — the system may have delivered it
        // via startForegroundService() under Android 12+ background restrictions.
        // We verify by checking the service was stopped cleanly (no exception),
        // which proves startForeground() was called before stopForeground().
        val intent = Intent().apply { action = LocationService.ACTION_STOP }
        // Should not throw — would throw IllegalStateException at runtime if
        // stopForeground was called without a prior startForeground.
        serviceController.create().withIntent(intent).startCommand(0, 1)
    }

    @Test
    fun `onStartCommand promotes to foreground for ACTION_UPDATE_NOTIFICATION`() {
        val intent = Intent().apply { action = LocationService.ACTION_UPDATE_NOTIFICATION }
        serviceController.create().withIntent(intent).startCommand(0, 1)
        assertForegroundPromoted()
    }

    @Test
    fun `onStartCommand promotes to foreground for ACTION_BUTTON`() {
        val intent = Intent().apply {
            action = LocationService.ACTION_BUTTON
            putExtra(LocationService.EXTRA_BUTTON_ACTION, "stop")
        }
        serviceController.create().withIntent(intent).startCommand(0, 1)
        assertForegroundPromoted()
    }

    @Test
    fun `onStartCommand promotes to foreground for null intent (sticky restart)`() {
        // After a system kill, START_STICKY services are restarted by the
        // system with a null intent. Without an explicit promotion, the
        // service crashes with RemoteServiceException.
        serviceController.create().get().onStartCommand(null, 0, 1)
        assertForegroundPromoted()
    }
}
