package com.ikolvi.tracelet.sdk.impact

import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Unit tests for the process-death-safe crash-confirmation store (#182).
 */
@RunWith(RobolectricTestRunner::class)
class CrashConfirmStoreTest {

    private fun sample(id: Long, kind: String = "potential_crash", deadlineMs: Long = 10_000): PendingImpact =
        PendingImpact(
            id = id,
            kind = kind,
            confidence = 0.8,
            peakG = 4.2,
            speedBefore = 16.0,
            latitude = 12.34,
            longitude = 56.78,
            timestampMs = 1_000,
            confirmDeadlineMs = deadlineMs,
        )

    @Test
    fun `put then claim round-trips all fields`() {
        val store = CrashConfirmStore(RuntimeEnvironment.getApplication())
        val p = sample(id = 1)
        store.put(p)

        val claimed = store.claim(1)
        assertEquals(p, claimed)
    }

    @Test
    fun `claim is one-shot`() {
        val store = CrashConfirmStore(RuntimeEnvironment.getApplication())
        store.put(sample(id = 2))

        assertTrue(store.claim(2) != null)
        assertNull(store.claim(2))
    }

    @Test
    fun `remove makes a candidate unclaimable`() {
        val store = CrashConfirmStore(RuntimeEnvironment.getApplication())
        store.put(sample(id = 3))
        store.remove(3)
        assertNull(store.claim(3))
    }

    @Test
    fun `claiming an unknown id returns null`() {
        val store = CrashConfirmStore(RuntimeEnvironment.getApplication())
        assertNull(store.claim(999))
    }

    @Test
    fun `candidates are independent across ids`() {
        val store = CrashConfirmStore(RuntimeEnvironment.getApplication())
        store.put(sample(id = 4))
        store.put(sample(id = 5))

        assertNull(store.claim(6))
        assertTrue(store.claim(4) != null)
        // Removing/claiming one must not affect the other.
        assertTrue(store.claim(5) != null)
    }

    @Test
    fun `confirmedKind maps potential prefixes`() {
        assertEquals("crash", sample(id = 7, kind = "potential_crash").confirmedKind)
        assertEquals("fall", sample(id = 8, kind = "potential_fall").confirmedKind)
    }
}
