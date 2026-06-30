package com.ikolvi.tracelet.sdk

import android.Manifest
import android.app.Application
import android.content.Context
import android.os.Looper
import androidx.test.core.app.ApplicationProvider
import com.ikolvi.tracelet.sdk.model.TrackingMode
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import kotlin.test.assertEquals
import kotlin.test.assertNull

/**
 * Google Play policy (effective 2026-10-28) prohibits using a foreground service
 * *solely* for geofencing. Tracelet's standard geofence mode relies entirely on
 * the native Geofence API (GeofencingClient), which fires enter/exit while
 * suspended/terminated without a foreground service — so `startGeofences()` in
 * standard mode must NOT start one, even when `foregroundService` is enabled
 * (continuous tracking still uses the FGS; only geofence-only mode is affected).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class GeofenceForegroundServicePolicyTest {

    private lateinit var context: Context
    private lateinit var sdk: TraceletSdk

    @Before
    fun setUp() {
        org.robolectric.shadows.ShadowLog.stream = System.out
        context = ApplicationProvider.getApplicationContext()

        androidx.work.testing.WorkManagerTestInitHelper.initializeTestWorkManager(
            context,
            androidx.work.Configuration.Builder()
                .setExecutor(androidx.work.testing.SynchronousExecutor())
                .build(),
        )

        shadowOf(context as Application).grantPermissions(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION,
            Manifest.permission.ACCESS_BACKGROUND_LOCATION,
        )

        sdk = TraceletSdk.getInstance(context)
        sdk.setEventSender(ListenerEventSender())
        sdk.initialize()
    }

    @After
    fun tearDown() {
        try { sdk.stop() } catch (_: Exception) {}
        shadowOf(Looper.getMainLooper()).idle()
        ConfigManager.resetInstance()
    }

    private fun idle() = shadowOf(Looper.getMainLooper()).idle()

    private fun drainStartedServices() {
        val app = shadowOf(context as Application)
        while (app.nextStartedService != null) { /* drain */ }
    }

    @Test
    fun `standard geofence mode does not start a foreground service`() {
        var ready = false
        sdk.ready(
            mapOf(
                "fg_enabled" to true,
                "geofenceModeHighAccuracy" to false,
            ),
        ) { ready = true }
        idle()
        assert(ready)

        // Ignore anything ready() may have queued; we only care about
        // startGeofences()'s behavior.
        drainStartedServices()

        sdk.startGeofences()
        idle()

        assertEquals(TrackingMode.GEOFENCES, sdk.stateManager.trackingMode)
        assertNull(
            shadowOf(context as Application).peekNextStartedService(),
            "standard geofence-only mode must not start a foreground service " +
                "(Google Play FGS-for-geofencing policy)",
        )
    }
}
