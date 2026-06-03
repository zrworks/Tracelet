package com.ikolvi.tracelet.sdk.wrapper

import android.content.Context
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.kotlin.mock
import org.robolectric.RobolectricTestRunner
import kotlin.test.assertIs
import kotlin.test.assertNotNull

@RunWith(RobolectricTestRunner::class)
class TraceletServicesTest {

    private val context: Context = mock()

    @Test
    fun testDefaultProviderSelection() {
        // In a Robolectric environment without GMS on the classpath, 
        // it should fall back to AospServicesProvider.
        val provider = TraceletServices.getProvider(context)
        assertNotNull(provider)
        
        if (TraceletServices.isGmsAvailable(context)) {
            // If GMS happens to be on the classpath in the test environment
            assertIs<PlayServicesProvider>(provider)
        } else {
            assertIs<AospServicesProvider>(provider)
        }
    }

    @Test
    fun testSetCustomProvider() {
        val customProvider = object : TraceletServicesProvider {
            override fun getLocationClient(context: Context): TraceletLocationClient = mock()
            override fun getGeofencingClient(context: Context): TraceletGeofencingClient = mock()
            override fun getActivityRecognitionClient(context: Context): TraceletActivityRecognitionClient = mock()
            override fun getEventExtractor(): TraceletEventExtractor = mock()
        }

        TraceletServices.setProvider(customProvider)
        val provider = TraceletServices.getProvider(context)
        
        assertIs<TraceletServicesProvider>(provider)
        // Verify it's exactly our custom provider
        assert(provider === customProvider)
    }

    @Test
    fun testAospProviderReturnsAospClients() {
        val provider = AospServicesProvider()
        val locationClient = provider.getLocationClient(context)
        val geofencingClient = provider.getGeofencingClient(context)
        val activityClient = provider.getActivityRecognitionClient(context)
        val extractor = provider.getEventExtractor()

        assertIs<AospLocationClient>(locationClient)
        assertIs<AospGeofencingClient>(geofencingClient)
        assertIs<AospActivityRecognitionClient>(activityClient)
        assertIs<AospEventExtractor>(extractor)
    }
}
