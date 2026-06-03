package com.ikolvi.tracelet.sdk.receiver

import android.content.Context
import android.content.Intent
import com.ikolvi.tracelet.sdk.ConfigManager
import com.ikolvi.tracelet.sdk.StateManager
import com.ikolvi.tracelet.sdk.model.TrackingMode
import com.ikolvi.tracelet.sdk.wrapper.TraceletActivityTransitionEvent
import com.ikolvi.tracelet.sdk.wrapper.TraceletActivityTransitionResult
import com.ikolvi.tracelet.sdk.wrapper.TraceletEventExtractor
import com.ikolvi.tracelet.sdk.wrapper.TraceletServices
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE)
class ActivityTransitionReceiverTest {

    private lateinit var context: Context
    private lateinit var stateManager: StateManager
    private lateinit var configManager: ConfigManager
    private lateinit var receiver: ActivityTransitionReceiver

    @Before
    fun setUp() {
        context = RuntimeEnvironment.getApplication()
        stateManager = StateManager(context)
        configManager = ConfigManager(context)
        
        // Ensure tracking is enabled so receiver logic processes
        stateManager.enabled = true
        
        receiver = ActivityTransitionReceiver()
        
        // Note: For Robolectric, TraceletSdk.getInstance(context).isReady is false by default,
        // and LocationService.bootMotionDetector is null by default.
        // This perfectly simulates the "completely killed state" without a foreground service.
    }

    @Test
    fun `moving transition in killed periodic mode wakes up SDK to continuous`() {
        // Setup state: PERIODIC mode, stationary
        stateManager.trackingMode = TrackingMode.PERIODIC
        stateManager.isMoving = false

        // Simulate IN_VEHICLE (0), ENTER (0)
        val intent = createMockTransitionIntent(activityType = 0, transitionType = 0)
        
        receiver.onReceive(context, intent)

        // Verify state changed
        assertTrue(stateManager.isMoving, "State should be moving")
        assertEquals(TrackingMode.CONTINUOUS, stateManager.trackingMode, "Tracking mode should upgrade to CONTINUOUS")
    }

    @Test
    fun `still transition in killed continuous mode switches to periodic`() {
        // Setup state: CONTINUOUS mode, moving
        stateManager.trackingMode = TrackingMode.CONTINUOUS
        stateManager.isMoving = true

        // Simulate STILL (3), ENTER (0)
        val intent = createMockTransitionIntent(activityType = 3, transitionType = 0)
        
        receiver.onReceive(context, intent)

        // Verify state changed
        assertFalse(stateManager.isMoving, "State should be stationary")
        assertEquals(TrackingMode.PERIODIC, stateManager.trackingMode, "Tracking mode should downgrade to PERIODIC")
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    private fun createMockTransitionIntent(activityType: Int, transitionType: Int): Intent {
        val intent = Intent("com.tracelet.ACTION_ACTIVITY_TRANSITION")
        
        // We use a mock extractor by intercepting the TraceletServices.getInstance
        // Because we cannot easily construct a valid Google Play Services intent without the GMS library in classpath.
        // Instead, we just inject our mock into the service wrapper.
        
        val mockExtractor = object : TraceletEventExtractor {
            override fun extractActivityTransitionResult(intent: Intent): TraceletActivityTransitionResult {
                return TraceletActivityTransitionResult(
                    listOf(TraceletActivityTransitionEvent(activityType, transitionType, System.nanoTime()))
                )
            }
            override fun extractGeofencingEvent(intent: Intent): com.ikolvi.tracelet.sdk.wrapper.TraceletGeofencingEvent? = null
            override fun extractActivityRecognitionResult(intent: Intent): com.ikolvi.tracelet.sdk.wrapper.TraceletActivityRecognitionResult? = null
        }
        
        val customProvider = object : com.ikolvi.tracelet.sdk.wrapper.TraceletServicesProvider {
            override fun getLocationClient(context: Context): com.ikolvi.tracelet.sdk.wrapper.TraceletLocationClient = org.mockito.kotlin.mock()
            override fun getGeofencingClient(context: Context): com.ikolvi.tracelet.sdk.wrapper.TraceletGeofencingClient = org.mockito.kotlin.mock()
            override fun getActivityRecognitionClient(context: Context): com.ikolvi.tracelet.sdk.wrapper.TraceletActivityRecognitionClient = org.mockito.kotlin.mock()
            override fun getEventExtractor(): TraceletEventExtractor = mockExtractor
        }
        
        TraceletServices.setProvider(customProvider)
        
        return intent
    }
}
