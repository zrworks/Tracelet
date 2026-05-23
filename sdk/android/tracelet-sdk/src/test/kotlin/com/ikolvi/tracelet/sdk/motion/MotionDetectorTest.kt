package com.ikolvi.tracelet.sdk.motion

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import com.ikolvi.tracelet.sdk.ConfigManager
import com.ikolvi.tracelet.sdk.StateManager
import com.ikolvi.tracelet.sdk.TraceletEventSender
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import java.lang.reflect.Field
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

@RunWith(RobolectricTestRunner::class)
class MotionDetectorTest {

    private lateinit var config: ConfigManager
    private lateinit var state: StateManager
    private lateinit var events: DummyEventSender
    private lateinit var detector: MotionDetector

    @Before
    fun setUp() {
        val context = RuntimeEnvironment.getApplication()
        config = ConfigManager(context)
        state = StateManager(context)
        events = DummyEventSender()

        // Force accelerometer-only mode
        config.setConfig(mapOf(
            "motion" to mapOf(
                "disableMotionActivityUpdates" to true,
                "stopTimeout" to 1 // 1 minute
            )
        ))
        
        state.isMoving = true // Start in moving state

        detector = MotionDetector(context, config, state, events)
        detector.start()
    }

    @Test
    fun `sustained stillness starts stop timeout but keeps accelerometer running`() {
        val listener = getAccelerometerListener()
        assertNotNull(listener, "Accelerometer should be listening for stillness")

        // Send STILL_SAMPLE_COUNT - 1 samples of stillness (magnitude = 0.0)
        repeat(24) {
            sendSensorEvent(listener, floatArrayOf(0f, 0f, 9.81f)) // Magnitude = 0.0
        }
        assertNull(getStopTimeoutRunnable(), "Timeout should not be started yet")

        // 25th sample
        sendSensorEvent(listener, floatArrayOf(0f, 0f, 9.81f))
        
        // Timeout should be started
        assertNotNull(getStopTimeoutRunnable(), "Timeout should be started after sustained stillness")
        
        // CRITICAL FIX TEST: Accelerometer should STILL be running!
        assertNotNull(getAccelerometerListener(), "Accelerometer must NOT be shut down during the stop countdown")
    }

    @Test
    fun `motion during stop timeout aborts the stop transition`() {
        val listener = getAccelerometerListener()!!

        // Send 25 samples to trigger the countdown
        repeat(25) {
            sendSensorEvent(listener, floatArrayOf(0f, 0f, 9.81f))
        }
        assertNotNull(getStopTimeoutRunnable(), "Timeout should be started")

        // Now simulate a bump (magnitude > 0.4)
        // 9.81 + 1.0 = 10.81 (magnitude = 1.0 > 0.4 still threshold)
        sendSensorEvent(listener, floatArrayOf(0f, 0f, 10.81f))

        // Timeout should be cancelled!
        assertNull(getStopTimeoutRunnable(), "Timeout should be cancelled because motion resumed")
        assertTrue(state.isMoving, "State should remain moving")
    }

    // =========================================================================
    // Reflection Helpers
    // =========================================================================

    private fun getAccelerometerListener(): SensorEventListener? {
        val field = MotionDetector::class.java.getDeclaredField("accelerometerListener")
        field.isAccessible = true
        return field.get(detector) as? SensorEventListener
    }

    private fun getStopTimeoutRunnable(): Runnable? {
        val field = MotionDetector::class.java.getDeclaredField("stopTimeoutRunnable")
        field.isAccessible = true
        return field.get(detector) as? Runnable
    }

    private fun sendSensorEvent(listener: SensorEventListener, values: FloatArray) {
        // Create a mock SensorEvent using reflection (constructor is package-private in Android)
        val constructor = SensorEvent::class.java.getDeclaredConstructors().first { it.parameterTypes.size == 1 }
        constructor.isAccessible = true
        val event = constructor.newInstance(values.size) as SensorEvent
        System.arraycopy(values, 0, event.values, 0, values.size)
        listener.onSensorChanged(event)
    }

    private class DummyEventSender : TraceletEventSender {
        override fun sendMotionChange(data: Map<String, Any?>) {}
        override fun sendSpeedMotionChange(data: Map<String, Any?>) {}
        override fun sendLocation(data: Map<String, Any?>) {}
        override fun sendActivityChange(data: Map<String, Any?>) {}
        override fun sendGeofencesChange(data: Map<String, Any?>) {}
        override fun sendGeofence(data: Map<String, Any?>) {}
        override fun sendHeartbeat(data: Map<String, Any?>) {}
        override fun sendHttp(data: Map<String, Any?>) {}
        override fun sendProviderChange(data: Map<String, Any?>) {}
        override fun sendConnectivityChange(data: Map<String, Any?>) {}
        override fun sendEnabledChange(enabled: Boolean) {}
        override fun sendPowerSaveChange(isPowerSaveMode: Boolean) {}
        override fun sendNotificationAction(action: String) {}
        override fun sendAuthorization(data: Map<String, Any?>) {}
        override fun sendRemoteConfigEvent(data: Map<String, Any?>) {}
        override fun sendSchedule(data: Map<String, Any?>) {}
        override fun sendWatchPosition(data: Map<String, Any?>) {}
        override fun sendTrip(data: Map<String, Any?>) {}
        override fun sendBudgetAdjustment(data: Map<String, Any?>) {}
        override fun hasListener(eventName: String): Boolean = false
    }
}
