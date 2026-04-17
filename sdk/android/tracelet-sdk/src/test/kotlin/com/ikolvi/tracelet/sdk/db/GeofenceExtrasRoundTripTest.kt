package com.ikolvi.tracelet.sdk.db

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Regression test for GitHub issue #51 follow-up:
 *   "Geofence extras are not returned in GeofenceEvent — evt.extras is always empty"
 *
 * Verifies that a Map passed as `extras` when adding a geofence survives a full
 * DB round-trip (insert → read) as a Map, not a `toString()` representation.
 */
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE)
class GeofenceExtrasRoundTripTest {

    private lateinit var db: TraceletDatabase

    @Before
    fun setUp() {
        val context: Context = ApplicationProvider.getApplicationContext()
        db = TraceletDatabase.getInstance(context)
        db.deleteAllGeofences()
    }

    @After
    fun tearDown() {
        db.deleteAllGeofences()
    }

    @Test
    fun extrasMapSurvivesInsertAndRead() {
        val extras = mapOf(
            "demo_test" to "Hello from the geofence extras!",
            "count" to 42,
            "enabled" to true,
        )

        val inserted = db.insertGeofence(
            mapOf(
                "identifier" to "test_zone",
                "latitude" to 37.7749,
                "longitude" to -122.4194,
                "radius" to 200.0,
                "notifyOnEntry" to true,
                "notifyOnExit" to true,
                "extras" to extras,
            )
        )
        assertTrue(inserted)

        val stored = db.getGeofence("test_zone")
        assertNotNull(stored)

        @Suppress("UNCHECKED_CAST")
        val storedExtras = stored["extras"] as? Map<String, Any?>
        assertNotNull(storedExtras, "extras must deserialize as a Map, not a String")
        assertEquals("Hello from the geofence extras!", storedExtras["demo_test"])
        assertEquals(42, storedExtras["count"])
        assertEquals(true, storedExtras["enabled"])
    }

    @Test
    fun nullExtrasReadsBackAsNull() {
        val inserted = db.insertGeofence(
            mapOf(
                "identifier" to "no_extras_zone",
                "latitude" to 0.0,
                "longitude" to 0.0,
                "radius" to 100.0,
            )
        )
        assertTrue(inserted)

        val stored = db.getGeofence("no_extras_zone")
        assertNotNull(stored)
        assertNull(stored["extras"])
    }
}
