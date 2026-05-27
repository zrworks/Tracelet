package com.ikolvi.tracelet.sdk.location

import android.content.Context
import android.location.Location
import android.os.Build
import android.os.SystemClock
import androidx.test.core.app.ApplicationProvider
import com.ikolvi.tracelet.sdk.ConfigManager
import com.ikolvi.tracelet.sdk.StateManager
import com.ikolvi.tracelet.sdk.TraceletEventSender
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.kotlin.any
import org.mockito.kotlin.doReturn
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [Build.VERSION_CODES.P])
class LocationEngineMockDetectionTest {

    private lateinit var context: Context
    private lateinit var configManager: ConfigManager
    private lateinit var stateManager: StateManager
    private lateinit var events: TraceletEventSender
    private lateinit var engine: LocationEngine

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        configManager = mock()
        stateManager = mock()
        events = mock()

        // Default mock detection level to heuristics (2)
        whenever(configManager.getMockDetectionLevel()).doReturn(2)
        // Default deferTime to 60000ms
        whenever(configManager.getDeferTime()).doReturn(60000)
        // Default desired accuracy to HIGH
        whenever(configManager.getDesiredAccuracy()).doReturn(0)
        whenever(configManager.getDistanceFilter()).doReturn(0.0)

        engine = LocationEngine(context, configManager, stateManager, events)
    }

    @Test
    fun testDeferredLocationNotFlaggedAsMock() {
        // A real location that was deferred by 60 seconds
        val location = Location("gps").apply {
            latitude = 37.0
            longitude = -122.0
            accuracy = 10f
            time = System.currentTimeMillis() - 60000
            // Set the location's elapsedRealtimeNanos to 60 seconds ago
            elapsedRealtimeNanos = SystemClock.elapsedRealtimeNanos() - 60_000_000_000L
        }

        // We can access the private isLocationMock method by calling enrichLocation
        // and checking the 'mock' field in the returned map.
        val enriched = engine.enrichLocation(location, "location")
        val isMock = enriched["mock"] as Boolean

        // If the fix works, it should NOT be flagged as a mock location
        assertEquals(false, isMock)
    }
}
