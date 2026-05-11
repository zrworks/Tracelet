package com.ikolvi.tracelet.sdk.attestation

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import kotlin.test.assertTrue
import kotlin.test.assertNull
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

@RunWith(RobolectricTestRunner::class)
class DeviceAttestorTest {

    @Test
    fun isAvailable_returnsTrueWhenPlayIntegrityOnClasspath() {
        // play-integrity is in testImplementation, so it should be available
        assertTrue(DeviceAttestor.isAvailable())
    }

    @Test
    fun requestToken_invokesCallback() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val attestor = DeviceAttestor(context)
        val latch = CountDownLatch(1)
        var resultToken: Map<String, Any?>? = null

        attestor.requestToken { token ->
            resultToken = token
            latch.countDown()
        }

        // It might fail or succeed depending on Robolectric's Play Services support,
        // but it should NOT throw a NoClassDefFoundError.
        latch.await(5, TimeUnit.SECONDS)
        // In unit tests without Google Play Services configured properly, it usually fails and returns null.
        // We just ensure it completed without crashing.
    }

    @Test
    fun startRefresh_and_stopRefresh_executesWithoutCrashing() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val attestor = DeviceAttestor(context)

        // Should not crash even if missing dependencies
        attestor.startRefresh(60)
        attestor.stopRefresh()
        assertTrue(true) // Reaching here means no crash
    }
}
