package com.ikolvi.tracelet.sdk.wrapper

import android.content.Context

class AospMotionClient(private val context: Context) : TraceletMotionClient {
    override fun isAvailable(): Boolean = false

    override fun registerActivityTransitions(
        onSuccess: () -> Unit,
        onFailure: (Exception) -> Unit,
        onSecurityException: (SecurityException) -> Unit
    ) {
        onFailure(Exception("Activity Recognition not available on AOSP"))
    }

    override fun unregisterActivityTransitions() {
        // No-op
    }
}
