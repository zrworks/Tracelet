package com.ikolvi.tracelet.sdk

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Regression for #227 — `destroyAll()` is invoked from the plugin's
 * `onDetachedFromEngine` during engine/Activity teardown, and can run in a
 * process/engine where `initialize()` was never called (e.g. a secondary or
 * headless Flutter engine that is the last to detach). The `lateinit`
 * subsystems (`motionDetector`, `locationEngine`, `geofenceManager`,
 * `scheduleManager`) are then uninitialized, and touching them threw
 * `UninitializedPropertyAccessException` — surfacing as a fatal
 * "Unable to destroy activity" because it's dispatched during teardown.
 *
 * destroyAll() must null-guard every subsystem so teardown never throws.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class DestroyAllUninitializedTest {

    @Before
    fun setUp() {
        // destroyAll() cancels the periodic WorkManager job; production apps have
        // WorkManager auto-initialized via the manifest provider, so stand up the
        // in-memory test scheduler here to mirror that (this is environment setup,
        // not the behavior under test).
        androidx.work.testing.WorkManagerTestInitHelper.initializeTestWorkManager(
            ApplicationProvider.getApplicationContext(),
            androidx.work.Configuration.Builder()
                .setExecutor(androidx.work.testing.SynchronousExecutor())
                .build(),
        )
    }

    @After
    fun tearDown() {
        ConfigManager.resetInstance()
    }

    @Test
    fun `destroyAll on an uninitialized SDK does not throw`() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val sdk = TraceletSdk.getInstance(context)

        // Deliberately do NOT call setEventSender()/initialize(): this mirrors a
        // secondary/headless engine teardown. Must complete without throwing.
        sdk.destroyAll()
    }

    @Test
    fun `destroyAll on an uninitialized SDK with stopOnTerminate=false does not throw`() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        // stopOnTerminate=false drives the keepAlive branch in destroyAll().
        ConfigManager.getInstance(context).setConfig(mapOf("stopOnTerminate" to false))
        val sdk = TraceletSdk.getInstance(context)

        sdk.destroyAll()
    }
}
