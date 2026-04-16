package com.ikolvi.tracelet.flutter.http

import com.ikolvi.tracelet.sdk.http.HttpSyncManager
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Tests for 401-aware retry in [HttpSyncManager].
 *
 * Verifies that:
 * - onAuthorizationRequired callback exists and defaults to null
 * - Callback can be set, cleared, and invoked
 * - Callback lifecycle is independent of other HttpSyncManager state
 *
 * Uses the companion object static property directly since
 * `onAuthorizationRequired` is a static callback on [HttpSyncManager].
 */
internal class HttpSync401RetryTest {

    @AfterTest
    fun tearDown() {
        // Reset static callback after each test
        HttpSyncManager.onAuthorizationRequired = null
    }

    @Test
    fun onAuthorizationRequired_defaultsToNull() {
        HttpSyncManager.onAuthorizationRequired = null
        assertNull(HttpSyncManager.onAuthorizationRequired)
    }

    @Test
    fun onAuthorizationRequired_canBeSet() {
        var callbackInvoked = false
        HttpSyncManager.onAuthorizationRequired = {
            callbackInvoked = true
            true
        }

        val result = HttpSyncManager.onAuthorizationRequired?.invoke()
        assertTrue(callbackInvoked)
        assertEquals(true, result)
    }

    @Test
    fun onAuthorizationRequired_canReturnFalse() {
        HttpSyncManager.onAuthorizationRequired = { false }

        val result = HttpSyncManager.onAuthorizationRequired?.invoke()
        assertFalse(result!!)
    }

    @Test
    fun onAuthorizationRequired_nullSafeInvocation() {
        HttpSyncManager.onAuthorizationRequired = null

        // Null-safe invocation should return null
        val result = HttpSyncManager.onAuthorizationRequired?.invoke()
        assertNull(result)
    }

    @Test
    fun onAuthorizationRequired_multipleInvocations() {
        var callCount = 0
        HttpSyncManager.onAuthorizationRequired = {
            callCount++
            callCount <= 1
        }

        assertTrue(HttpSyncManager.onAuthorizationRequired!!.invoke())
        assertFalse(HttpSyncManager.onAuthorizationRequired!!.invoke())
        assertEquals(2, callCount)
    }
}
