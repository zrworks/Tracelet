package com.ikolvi.tracelet.sdk.location

import android.content.Context
import android.location.Address
import android.location.Geocoder
import android.location.Location
import androidx.test.core.app.ApplicationProvider
import com.ikolvi.tracelet.sdk.ConfigManager
import com.ikolvi.tracelet.sdk.EventSender
import com.ikolvi.tracelet.sdk.StateManager
import com.ikolvi.tracelet.sdk.model.GeoConfig
import com.ikolvi.tracelet.sdk.model.TraceletConfig
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.kotlin.any
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowGeocoder
import java.util.Locale
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33]) // API 33 to test Geocoder behavior
class LocationEngineReverseGeocodingTest {

    private lateinit var context: Context
    private lateinit var configManager: ConfigManager
    private lateinit var stateManager: StateManager
    private lateinit var eventSender: EventSender
    private lateinit var engine: LocationEngine
    private lateinit var shadowGeocoder: ShadowGeocoder

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
        configManager = ConfigManager(context)
        stateManager = StateManager(context)
        eventSender = mock()
        
        // Setup shadow geocoder
        val geocoder = Geocoder(context)
        shadowGeocoder = shadowOf(geocoder)

        engine = LocationEngine(context, configManager, stateManager, eventSender)
    }

    @After
    fun teardown() {
        engine.destroy()
    }

    @Test
    fun `when resolveAddress is true, location is enriched with address`() {
        // Arrange
        configManager.setConfig(TraceletConfig(geo = GeoConfig(resolveAddress = true)).toMap())
        
        val lat = 37.7749
        val lng = -122.4194
        
        val address = Address(Locale.US).apply {
            thoroughfare = "Market St"
            locality = "San Francisco"
            adminArea = "CA"
            postalCode = "94103"
            countryName = "United States"
        }
        shadowGeocoder.addAddress(address)

        val location = Location("gps").apply {
            latitude = lat
            longitude = lng
            accuracy = 10f
            time = System.currentTimeMillis()
        }
        
        var dispatchedLocation: Map<String, Any?>? = null
        val latch = CountDownLatch(1)
        
        whenever(eventSender.sendLocation(any())).thenAnswer { invocation ->
            dispatchedLocation = invocation.arguments[0] as Map<String, Any?>
            latch.countDown()
            true
        }

        // Act
        // Invoke private onLocationReceived via reflection to bypass JNI filtering for the test
        val method = LocationEngine::class.java.getDeclaredMethod("onLocationReceived", Location::class.java, String::class.java)
        method.isAccessible = true
        
        try {
            method.invoke(engine, location, "test_event")
        } catch (e: Exception) {
            // Ignore Rust processor exceptions if they occur, though Robolectric might swallow them
        }

        // Wait for async geocoding
        latch.await(3, TimeUnit.SECONDS)
        org.robolectric.shadows.ShadowLooper.runUiThreadTasksIncludingDelayedTasks()

        // Assert
        assertNotNull("Location should have been dispatched", dispatchedLocation)
        val addressMap = dispatchedLocation!!["address"] as? Map<String, Any?>
        assertNotNull("Address map should be present", addressMap)
        assertEquals("Market St", addressMap!!["street"])
        assertEquals("San Francisco", addressMap["city"])
        assertEquals("CA", addressMap["state"])
        assertEquals("94103", addressMap["postalCode"])
        assertEquals("United States", addressMap["country"])
    }
}
