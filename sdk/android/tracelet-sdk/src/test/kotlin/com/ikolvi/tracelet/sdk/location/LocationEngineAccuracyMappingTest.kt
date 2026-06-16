package com.ikolvi.tracelet.sdk.location

import android.content.Context
import android.os.Build
import androidx.test.core.app.ApplicationProvider
import com.ikolvi.tracelet.sdk.ConfigManager
import com.ikolvi.tracelet.sdk.StateManager
import com.ikolvi.tracelet.sdk.TraceletEventSender
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.kotlin.mock
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [Build.VERSION_CODES.P])
class LocationEngineAccuracyMappingTest {

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
        engine = LocationEngine(context, configManager, stateManager, events)
    }

    @Test
    fun testAccuracyToPriorityMapping() {
        val method = LocationEngine::class.java.getDeclaredMethod("accuracyToPriority", Int::class.javaPrimitiveType)
        method.isAccessible = true

        val invokeMapping = { accuracy: Int -> method.invoke(engine, accuracy) as Int }

        // 0 -> HIGH_ACCURACY
        assertEquals(TraceletLocationPriority.PRIORITY_HIGH_ACCURACY, invokeMapping(0))
        // 1 -> BALANCED_POWER_ACCURACY
        assertEquals(TraceletLocationPriority.PRIORITY_BALANCED_POWER_ACCURACY, invokeMapping(1))
        // 2 -> LOW_POWER
        assertEquals(TraceletLocationPriority.PRIORITY_LOW_POWER, invokeMapping(2))
        // 3 -> PASSIVE (veryLow)
        assertEquals(TraceletLocationPriority.PRIORITY_PASSIVE, invokeMapping(3))
        // 4 -> PASSIVE (passive)
        assertEquals(TraceletLocationPriority.PRIORITY_PASSIVE, invokeMapping(4))
        // Invalid -> HIGH_ACCURACY
        assertEquals(TraceletLocationPriority.PRIORITY_HIGH_ACCURACY, invokeMapping(99))
    }
}
