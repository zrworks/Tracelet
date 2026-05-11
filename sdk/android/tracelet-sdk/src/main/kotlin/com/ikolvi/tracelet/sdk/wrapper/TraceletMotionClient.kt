package com.ikolvi.tracelet.sdk.wrapper

import android.content.Context

/**
 * Interface for activity recognition providers.
 */
interface TraceletMotionClient {
    fun registerActivityTransitions(
        onSuccess: () -> Unit,
        onFailure: (Exception) -> Unit,
        onSecurityException: (SecurityException) -> Unit
    )
    fun unregisterActivityTransitions()
    fun isAvailable(): Boolean
}
