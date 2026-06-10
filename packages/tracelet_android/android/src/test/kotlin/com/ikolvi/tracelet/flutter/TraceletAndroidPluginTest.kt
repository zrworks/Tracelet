package com.ikolvi.tracelet.flutter

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.ikolvi.tracelet.flutter.service.HeadlessTaskService
import com.ikolvi.tracelet.sdk.TraceletSdk
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.mockito.Mockito.mock
import kotlin.test.assertNotSame

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class TraceletAndroidPluginTest {

    private lateinit var context: Context

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        // Reset state
        TraceletSdk.getInstance(context).dartSyncInterceptor = null
        HeadlessTaskService.isSpawningHeadlessEngine = false
    }

    @After
    fun tearDown() {
        TraceletSdk.getInstance(context).dartSyncInterceptor = null
        HeadlessTaskService.isSpawningHeadlessEngine = false
    }

    @Test
    fun `plugin attached to headless engine acts as secondary instance`() {
        // Set the flag simulating a headless engine spawning
        HeadlessTaskService.isSpawningHeadlessEngine = true

        val plugin = TraceletAndroidPlugin()
        val mockBinding = mock(FlutterPlugin.FlutterPluginBinding::class.java)
        org.mockito.Mockito.`when`(mockBinding.applicationContext).thenReturn(context)
        org.mockito.Mockito.`when`(mockBinding.binaryMessenger).thenReturn(mock(BinaryMessenger::class.java))

        plugin.onAttachedToEngine(mockBinding)

        // The plugin should NOT overwrite the dartSyncInterceptor
        assertNotSame(
            plugin,
            TraceletSdk.getInstance(context).dartSyncInterceptor,
            "TraceletAndroidPlugin should not overwrite dartSyncInterceptor when spawned by a headless engine"
        )
    }
}
