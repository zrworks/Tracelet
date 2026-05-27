package com.ikolvi.tracelet.sdk.motion

import android.content.Context
import com.ikolvi.tracelet.sdk.ConfigManager
import com.ikolvi.tracelet.sdk.TraceletEventSender
import com.ikolvi.tracelet.sdk.location.LocationEngine
import com.ikolvi.tracelet.sdk.model.TrackingMode
import com.ikolvi.tracelet.sdk.StateManager
import com.ikolvi.tracelet.sdk.motion.MotionDetector
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.mock
import org.mockito.Mockito.verify
import org.mockito.Mockito.times
import org.mockito.Mockito.never
import org.mockito.Mockito.anyString
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

@RunWith(RobolectricTestRunner::class)
class SmartMotionCoordinatorTest {

    private lateinit var context: Context
    private lateinit var config: ConfigManager
    private lateinit var state: StateManager
    private lateinit var eventSender: TraceletEventSender
    private lateinit var locationEngine: LocationEngine
    private lateinit var motionDetector: MotionDetector
    private lateinit var coordinator: SmartMotionCoordinator

    @Before
    fun setUp() {
        context = RuntimeEnvironment.getApplication()
        config = ConfigManager(context)
        state = StateManager(context)
        eventSender = mock(TraceletEventSender::class.java)
        locationEngine = mock(LocationEngine::class.java)
        motionDetector = mock(MotionDetector::class.java)

        // Default state: not moving, periodic tracking
        state.isMoving = false
        state.trackingMode = TrackingMode.PERIODIC

        coordinator = SmartMotionCoordinator(context, config, state, eventSender, locationEngine, motionDetector)
        coordinator.syncCurrentMode()
    }

    @Test
    fun `initial state is Accel=false, Speed=true`() {
        assertFalse(coordinator.isAccelMoving)
        assertTrue(coordinator.isSpeedMoving)
    }

    @Test
    fun `onAccelStateChange to true switches to CONTINUOUS`() {
        // Given that Speed is initially true, Accel changing to true should trigger CONTINUOUS switch
        // Actually, if Speed is true and Accel changes to true, the combined state is still true.
        // Wait, if trackingMode is PERIODIC, it should switch to CONTINUOUS.
        
        coordinator.onAccelStateChange(true)
        
        assertTrue(coordinator.isAccelMoving)
        assertEquals(TrackingMode.CONTINUOUS, state.trackingMode)
        assertTrue(state.isMoving)
        verify(locationEngine).start()
    }

    @Test
    fun `both sensors false switches to STATIONARY`() {
        // First simulate being in CONTINUOUS mode
        state.trackingMode = TrackingMode.CONTINUOUS
        state.isMoving = true
        coordinator.syncCurrentMode()
        
        // Speed becomes false -> combined = false (because Accel is initially false)
        coordinator.onSpeedStateChange(false)
        
        assertFalse(coordinator.isSpeedMoving)
        assertFalse(coordinator.isAccelMoving)
        
        // Should switch to PERIODIC by default
        assertEquals(TrackingMode.PERIODIC, state.trackingMode)
        assertFalse(state.isMoving)
        verify(locationEngine).stop()
    }
    
    @Test
    fun `speed stationary overrides accel moving (hand tremor failsafe)`() {
        state.trackingMode = TrackingMode.CONTINUOUS
        state.isMoving = true
        coordinator.syncCurrentMode()
        
        // Accel is true (hand tremor), Speed becomes false (GPS confirms still)
        coordinator.onAccelStateChange(true)
        coordinator.onSpeedStateChange(false)
        
        // GPS speed takes priority: should switch to STATIONARY because the
        // speed failsafe overrides accel jitter when GPS confirms stationary.
        assertFalse(state.isMoving)
    }

    @Test
    fun `consecutive duplicate states do not trigger engine`() {
        coordinator.onAccelStateChange(true)
        // Now tracking mode is CONTINUOUS
        
        // Accel is true, Speed is true -> still CONTINUOUS
        coordinator.onSpeedStateChange(true)
        
        // start() should only be called once when it initially switched to CONTINUOUS
        verify(locationEngine, times(1)).start()
    }
}
