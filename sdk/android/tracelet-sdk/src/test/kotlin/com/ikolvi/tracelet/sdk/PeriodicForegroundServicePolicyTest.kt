package com.ikolvi.tracelet.sdk

import android.Manifest
import android.app.Application
import android.content.Context
import android.content.Intent
import android.os.Looper
import androidx.test.core.app.ApplicationProvider
import com.ikolvi.tracelet.sdk.model.TrackingMode
import com.ikolvi.tracelet.sdk.service.LocationService
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
 * Regression test for #237: periodic mode with `periodicUseForegroundService`
 * enabled did not start a foreground service.
 *
 * Root cause: `startPeriodic()` unconditionally stopped the foreground service
 * up-front (ACTION_STOP) and then immediately restarted it (ACTION_START) in the
 * foreground branch. On a fresh start the ACTION_STOP handler's `stopSelf()`
 * races the pending ACTION_START and can destroy the service right after it was
 * promoted, leaving NO foreground service at all. Continuous mode never
 * pre-stops, which is why it was unaffected.
 *
 * Contract: foreground-periodic mode must issue ACTION_START and must NOT issue
 * an up-front ACTION_STOP that races it; the non-foreground strategies must tear
 * down any leftover service instead.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class PeriodicForegroundServicePolicyTest {

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

    /** Drains and returns the actions of every LocationService intent started so far. */
    private fun drainStartedServiceActions(): List<String?> {
        val app = shadowOf(context as Application)
        val actions = mutableListOf<String?>()
        var intent: Intent? = app.nextStartedService
        while (intent != null) {
            if (intent.component?.className == LocationService::class.java.name) {
                actions.add(intent.action)
            }
            intent = app.nextStartedService
        }
        return actions
    }

    @Test
    fun `foreground periodic mode starts the service and does not pre-stop it`() {
        var ready = false
        sdk.ready(
            mapOf(
                "fg_enabled" to true,
                "periodicUseForegroundService" to true,
                "periodicLocationInterval" to 60,
            ),
        ) { ready = true }
        idle()
        assert(ready)

        // Ignore anything ready() may have queued; we only care about startPeriodic().
        drainStartedServiceActions()

        sdk.startPeriodic()
        idle()

        assertEquals(TrackingMode.PERIODIC, sdk.stateManager.trackingMode)

        val actions = drainStartedServiceActions()
        assertTrue(
            actions.contains(LocationService.ACTION_START),
            "foreground-periodic mode must start the foreground service (#237); got $actions",
        )
        assertTrue(
            !actions.contains(LocationService.ACTION_STOP),
            "foreground-periodic mode must not issue an ACTION_STOP that races the " +
                "ACTION_START and tears the service down (#237); got $actions",
        )
    }
}
