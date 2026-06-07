package com.ikolvi.tracelet.sdk

import android.content.Context
import android.os.Build
import androidx.test.core.app.ApplicationProvider
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.util.ReflectionHelpers

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
class OemConfigOverrideTest {

    private lateinit var context: Context
    private lateinit var configManager: ConfigManager

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        configManager = ConfigManager.getInstance(context)
        // Reset config before each test
        configManager.reset(null)
    }

    @After
    fun tearDown() {
        // Reset back to normal to avoid polluting other tests
        ReflectionHelpers.setStaticField(Build::class.java, "MANUFACTURER", "unknown")
    }

    @Test
    fun testRestrictedOem_Oppo_ForcesForegroundServiceAndHighAccuracy() {
        ReflectionHelpers.setStaticField(Build::class.java, "MANUFACTURER", "OPPO")
        
        // Even if default is false, it should return true
        assertTrue(configManager.isForegroundServiceEnabled())
        assertTrue(configManager.getGeofenceModeHighAccuracy())
        assertTrue(configManager.getPeriodicUseForegroundService())
    }

    @Test
    fun testRestrictedOem_Xiaomi_ForcesForegroundServiceAndHighAccuracy() {
        ReflectionHelpers.setStaticField(Build::class.java, "MANUFACTURER", "Xiaomi")
        
        assertTrue(configManager.isForegroundServiceEnabled())
        assertTrue(configManager.getGeofenceModeHighAccuracy())
        assertTrue(configManager.getPeriodicUseForegroundService())
    }

    @Test
    fun testStandardOem_Google_ReturnsConfiguredValue() {
        ReflectionHelpers.setStaticField(Build::class.java, "MANUFACTURER", "Google")
        
        // Should return defaults (true for FG, false for geofence mode)
        assertTrue(configManager.isForegroundServiceEnabled()) // Default is true
        assertFalse(configManager.getGeofenceModeHighAccuracy()) // Default is false
        assertFalse(configManager.getPeriodicUseForegroundService()) // Default is false

        // Change config to false/true
        configManager.setConfig(mapOf(
            "android" to mapOf(
                "foregroundService" to mapOf("enabled" to false),
                "periodicUseForegroundService" to true
            ),
            "geofence" to mapOf("geofenceModeHighAccuracy" to true)
        ))

        assertFalse(configManager.isForegroundServiceEnabled())
        assertTrue(configManager.getGeofenceModeHighAccuracy())
        assertTrue(configManager.getPeriodicUseForegroundService())
    }

    @Test
    fun testRestrictedOem_DoesNotOverrideShowNotificationOnPauseOnly() {
        ReflectionHelpers.setStaticField(Build::class.java, "MANUFACTURER", "vivo")
        
        // Default is false
        assertFalse(configManager.getShowNotificationOnPauseOnly())

        // Change config to true
        configManager.setConfig(mapOf(
            "android" to mapOf("foregroundService" to mapOf("showNotificationOnPauseOnly" to true))
        ))

        // Should be true now, untouched by the OEM override
        assertTrue(configManager.getShowNotificationOnPauseOnly())
    }
}
