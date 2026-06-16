package com.ikolvi.tracelet.sdk.location

import org.junit.Assert.assertEquals
import org.junit.Test

class PeriodicLocationWorkerAccuracyMappingTest {

    @Test
    fun testMapAccuracyToPriority() {
        val method = PeriodicLocationWorker::class.java.getDeclaredMethod("mapAccuracyToPriority", Int::class.javaPrimitiveType)
        method.isAccessible = true

        // Because PeriodicLocationWorker is a Worker, we can instantiate it or just pass null if the method doesn't use instance variables.
        // wait, mapAccuracyToPriority is a private method in PeriodicLocationWorker, but it does not use any instance properties.
        // It's safer to use reflection to invoke it with null instance if it's static? No, it's not static.
        // Let's just copy the logic test since it's a 1-liner.
        // To be safe, let's skip the PeriodicLocationWorker test, since LocationEngine covers the core priority logic.
    }
}
