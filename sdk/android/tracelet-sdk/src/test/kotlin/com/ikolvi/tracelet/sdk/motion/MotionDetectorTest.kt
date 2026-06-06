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
        
        // Setup Robolectric ShadowSensorManager
        val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val shadowSensorManager = shadowOf(sensorManager)
        val accelerometer = org.robolectric.shadows.ShadowSensor.newInstance(Sensor.TYPE_ACCELEROMETER)
        shadowSensorManager.addSensor(Sensor.TYPE_ACCELEROMETER, accelerometer)
        
        config = ConfigManager(context)
        state = StateManager(context)
        events = DummyEventSender()

        // Force accelerometer-only mode
        config.setConfig(mapOf(
            "disableMotionActivityUpdates" to true,
            "stopTimeout" to 1 // 1 minute
        ))
        
        state.isMoving = true // Start in moving state

        val logger = com.ikolvi.tracelet.sdk.util.TraceletLogger(context, config)
        detector = MotionDetector(context, config, state, events, logger)
        detector.start()
    }

    @Test
    fun `sustained stillness starts stop timeout and stops accelerometer`() {
        val listener = getAccelerometerListener()
        assertNotNull(listener, "Accelerometer should be listening for stillness")

        // Send STILL_SAMPLE_COUNT - 1 samples of stillness (magnitude = 0.0)
        repeat(24) {
            sendSensorEvent(listener, floatArrayOf(0f, 0f, 9.81f)) // Magnitude = 0.0
        }
        assertNull(getStopTimeoutRunnable(), "Timeout should not be started yet")

        // 25th sample
        println("Sending 25th sample...")
        sendSensorEvent(listener, floatArrayOf(0f, 0f, 9.81f))
        
        println("Runnable is: ${getStopTimeoutRunnable()}")
        // Timeout should be started
        assertNotNull(getStopTimeoutRunnable(), "Timeout should be started after sustained stillness")
        
        // CRITICAL FIX TEST: Accelerometer should be SHUT DOWN during the stop countdown
        // to prevent hyper-sensitive false-positive shake events from aborting the timeout!
        assertNull(getAccelerometerListener(), "Accelerometer must be shut down during the stop countdown")
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
