package com.ikolvi.tracelet.sdk.location

import android.Manifest
import android.app.Application
import android.location.Location
import androidx.test.core.app.ApplicationProvider
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.tasks.Tasks
import com.ikolvi.tracelet.sdk.ConfigManager
import com.ikolvi.tracelet.sdk.ListenerEventSender
import com.ikolvi.tracelet.sdk.StateManager
import com.ikolvi.tracelet.sdk.db.TraceletDatabase
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.ArgumentMatchers.anyInt
import org.mockito.Mockito.never
import org.mockito.Mockito.times
import org.mockito.Mockito.verify
import org.mockito.kotlin.anyOrNull
import org.mockito.kotlin.doReturn
import org.mockito.kotlin.mock
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * Tests that [LocationEngine.changePace] fires an immediate one-shot
 * `getCurrentLocation()` on stationary → moving transitions, eliminating
 * the wait for the continuous stream's `locationUpdateInterval` tick.
 *
 * Issue: https://github.com/Ikolvi/Tracelet/issues/54
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class LocationEngineChangePaceImmediateFixTest {

    private lateinit var context: Application
    private lateinit var config: ConfigManager
    private lateinit var state: StateManager
    private lateinit var db: TraceletDatabase
    private lateinit var engine: LocationEngine
    private lateinit var mockFusedClient: FusedLocationProviderClient

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        shadowOf(context).grantPermissions(Manifest.permission.ACCESS_FINE_LOCATION)

        config = ConfigManager.getInstance(context)
        state = StateManager(context)
        db = TraceletDatabase.getInstance(context)
        engine = LocationEngine(context, config, state, ListenerEventSender(), db)

        mockFusedClient = mock()
        // Default: getCurrentLocation returns null so the success listener is a no-op.
        doReturn(Tasks.forResult<Location>(null))
            .`when`(mockFusedClient).getCurrentLocation(anyInt(), anyOrNull())

        val field = LocationEngine::class.java.getDeclaredField("fusedClient")
        field.isAccessible = true
        field.set(engine, mockFusedClient)
    }

    @After
    fun tearDown() {
        ConfigManager.resetInstance()
    }

    @Test
    fun `changePace true on stationary to moving fires immediate one-shot fix`() {
        // Act: stationary → moving (engine starts not tracking)
        val result = engine.changePace(true)

        // Assert
        assert(result)
        verify(mockFusedClient, times(1)).getCurrentLocation(anyInt(), anyOrNull())
    }

    @Test
    fun `changePace true when already tracking does not fire extra one-shot fix`() {
        // Arrange: simulate already tracking by seeding trackingCallback (isTracking is computed)
        val callbackField = LocationEngine::class.java.getDeclaredField("trackingCallback")
        callbackField.isAccessible = true
        callbackField.set(engine, object : com.google.android.gms.location.LocationCallback() {})

        // Act
        engine.changePace(true)

        // Assert: no immediate fix because there was no transition
        verify(mockFusedClient, never()).getCurrentLocation(anyInt(), anyOrNull())
    }

    @Test
    fun `changePace false does not fire immediate one-shot fix`() {
        // Arrange: simulate currently tracking so stop() path is exercised
        val callbackField = LocationEngine::class.java.getDeclaredField("trackingCallback")
        callbackField.isAccessible = true
        callbackField.set(engine, object : com.google.android.gms.location.LocationCallback() {})

        // Act
        engine.changePace(false)

        // Assert
        verify(mockFusedClient, never()).getCurrentLocation(anyInt(), anyOrNull())
    }

    @Test
    fun `stop cancels in-flight immediate fix CancellationTokenSource`() {
        // Arrange: trigger an immediate fix to populate immediateFixCts
        engine.changePace(true)

        val ctsField = LocationEngine::class.java.getDeclaredField("immediateFixCts")
        ctsField.isAccessible = true
        val ctsBefore = ctsField.get(engine) as com.google.android.gms.tasks.CancellationTokenSource?
        assert(ctsBefore != null) { "Expected immediateFixCts to be set after changePace(true)" }
        assert(!ctsBefore!!.token.isCancellationRequested) { "Token should not be cancelled yet" }

        // Act: stop() must cancel the in-flight CTS and clear the field
        engine.stop()

        // Assert
        assert(ctsBefore.token.isCancellationRequested) {
            "stop() must cancel the in-flight immediate-fix token"
        }
        val ctsAfter = ctsField.get(engine)
        assert(ctsAfter == null) { "stop() must null out immediateFixCts" }
    }

    @Test
    fun `consecutive immediate fixes cancel the prior one`() {
        // Arrange: ensure first call starts not tracking
        engine.changePace(true)
        val ctsField = LocationEngine::class.java.getDeclaredField("immediateFixCts")
        ctsField.isAccessible = true
        val first = ctsField.get(engine) as com.google.android.gms.tasks.CancellationTokenSource?
        assert(first != null)

        // Force back to a non-tracking state so the second changePace(true)
        // exercises the transition path again.
        val callbackField = LocationEngine::class.java.getDeclaredField("trackingCallback")
        callbackField.isAccessible = true
        callbackField.set(engine, null)

        // Act: second transition supersedes the first
        engine.changePace(true)
        val second = ctsField.get(engine) as com.google.android.gms.tasks.CancellationTokenSource?

        // Assert: a new CTS exists and the prior one was cancelled
        assert(second != null && second !== first) { "Second call must create a new CTS" }
        assert(first!!.token.isCancellationRequested) { "Prior CTS must be cancelled" }
    }
}
