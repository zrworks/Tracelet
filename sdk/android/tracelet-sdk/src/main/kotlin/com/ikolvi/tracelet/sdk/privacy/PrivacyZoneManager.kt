package com.ikolvi.tracelet.sdk.privacy

import android.content.Context
import com.ikolvi.tracelet.sdk.ConfigManager
import uniffi.tracelet_core.CorePrivacyZone
import uniffi.tracelet_core.PrivacyZoneEvaluator

/**
 * **[Enterprise]** Privacy Zone Manager.
 *
 * This manager orchestrates geographic compliance and privacy controls (GDPR, CCPA, etc.).
 * It intercepts incoming device GPS locations, matches them against registered geographic zones,
 * and routes them through the appropriate action filters.
 *
 * The evaluation and mathematical grid snapping (precision degradation) logic are centralized
 * in the shared Rust Core via [PrivacyZoneEvaluator] to guarantee cross-platform consistency.
 *
 * Supported Privacy Actions:
 * - **Exclude** (`action = 0`): Drops the location entirely. It is not persisted in SQLite,
 *   not sent to Dart, and not cryptographically audited.
 * - **Degrade** (`action = 1`): Degrades coordinate precision by rounding latitude/longitude
 *   to a configurable accuracy grid (e.g., 1000m cells). The degraded record is persisted
 *   and dispatched, ensuring tracking without precise personal location tracing.
 * - **Event-only** (`action = 2`): Dispatches location events to real-time Dart/Flutter
 *   subscribers but does NOT save them to the database or include them in subsequent sync batches.
 */
class PrivacyZoneManager(
    private val context: Context,
    private val configManager: ConfigManager,
    private val rustDatabase: uniffi.tracelet_core.DatabaseManager? = null,
) {
    companion object {
        // Action constants (matching the Dart/Swift platform contract)
        const val ACTION_EXCLUDE = 0
        const val ACTION_DEGRADE = 1
        const val ACTION_EVENT_ONLY = 2
    }

    /**
     * Checks if geographic privacy zone enforcement is enabled in the configuration.
     * Evaluates the core settings layer.
     */
    fun isEnabled(): Boolean = configManager.getPrivacyZoneEnabled()

    // =========================================================================
    // In-memory zone cache
    // =========================================================================

    /**
     * In-memory cache of privacy control zones to avoid performing database queries
     * on every individual GPS location update.
     */
    private var cachedZones: List<CorePrivacyZone>? = null

    /**
     * Returns the list of privacy zones. Queries the database if the cache is empty
     * or has been invalidated.
     */
    private fun getCachedZones(): List<CorePrivacyZone> {
        val cached = cachedZones
        if (cached != null) {
            return cached
        }
        // Fetch from the shared Rust SQLite database
        val loaded = rustDatabase?.getPrivacyZones() ?: emptyList()
        cachedZones = loaded
        return loaded
    }

    /**
     * Invalidates the in-memory cache, forcing a refresh from the SQLite database
     * on the next location evaluation.
     */
    private fun invalidateCache() {
        cachedZones = null
    }

    // =========================================================================
    // Zone CRUD (delegated to Rust database)
    // =========================================================================

    /**
     * Registers a new geographic privacy zone in the shared database.
     *
     * @param zone A map containing zone properties: identifier, latitude, longitude, radius, action, degradedAccuracyMeters.
     * @return True if the zone was inserted successfully, false otherwise.
     */
    fun addZone(zone: Map<String, Any?>): Boolean {
        val identifier = zone["identifier"] as? String ?: return false
        val lat = (zone["latitude"] as? Number)?.toDouble() ?: 0.0
        val lng = (zone["longitude"] as? Number)?.toDouble() ?: 0.0
        val radius = (zone["radius"] as? Number)?.toDouble() ?: 0.0
        val action = (zone["action"] as? Number)?.toInt() ?: ACTION_EXCLUDE
        val degradedAccuracy = (zone["degradedAccuracyMeters"] as? Number)?.toDouble() ?: 1000.0
        
        try {
            rustDatabase?.insertPrivacyZone(identifier, lat, lng, radius, action, degradedAccuracy)
            invalidateCache()
            return true
        } catch (e: Exception) {
            return false
        }
    }

    /**
     * Registers multiple privacy zones in a single sweep.
     *
     * @param zones List of privacy zone property maps.
     * @return True if all zones were added successfully.
     */
    fun addZones(zones: List<Map<String, Any?>>): Boolean {
        var allSuccess = true
        for (zone in zones) {
            if (!addZone(zone)) {
                allSuccess = false
            }
        }
        return allSuccess
    }

    /**
     * Removes a specific privacy zone from the database by its identifier.
     *
     * @param identifier Unique zone string identifier.
     */
    fun removeZone(identifier: String): Boolean {
        try {
            rustDatabase?.deletePrivacyZone(identifier)
            invalidateCache()
            return true
        } catch (e: Exception) {
            return false
        }
    }

    /**
     * Removes all registered privacy zones from the database.
     */
    fun removeAllZones(): Boolean {
        try {
            rustDatabase?.clearPrivacyZones()
            invalidateCache()
            return true
        } catch (e: Exception) {
            return false
        }
    }

    /**
     * Exposes the currently active privacy zones as maps to preserve API compatibility
     * with the Dart/Flutter bridge channel.
     */
    fun getZones(): List<Map<String, Any?>> {
        return getCachedZones().map { mapFromCorePrivacyZone(it) }
    }

    // =========================================================================
    // Location evaluation
    // =========================================================================

    /**
     * The result of evaluating a location against privacy boundaries.
     *
     * @property action The resolved restrictive action to apply, or `null` if no zone contains the coordinate.
     * @property zone The matching zone property map, or `null` if no zone matches.
     */
    data class EvaluationResult(
        val action: Int?,
        val zone: Map<String, Any?>?,
    )

    /**
     * Evaluates a location coordinate against all cached privacy zones.
     * Delegates math and priority resolving (Exclude > EventOnly > Degrade) to the Rust [PrivacyZoneEvaluator].
     *
     * @param latitude The coordinate latitude.
     * @param longitude The coordinate longitude.
     */
    fun evaluate(latitude: Double, longitude: Double): EvaluationResult {
        if (!isEnabled()) return EvaluationResult(null, null)

        val zones = getCachedZones()
        if (zones.isEmpty()) return EvaluationResult(null, null)

        // Instantiate the Rust evaluator to run optimized spatial checks and resolve action priorities
        val evaluator = PrivacyZoneEvaluator()
        val result = evaluator.evaluate(latitude, longitude, zones)

        if (result.action == null) return EvaluationResult(null, null)

        // Locate the winner zone to build the detailed compatibility map
        val matchedZone = zones.find { it.identifier == result.matchedZoneId }
        val matchedZoneMap = matchedZone?.let { mapFromCorePrivacyZone(it) }

        return EvaluationResult(result.action, matchedZoneMap)
    }

    /**
     * Processes a location against privacy zone rules and returns a [ProcessedLocation]
     * indicating whether it should be kept, dropped, degraded, or kept event-only.
     *
     * @param location The input location property map.
     */
    fun processLocation(location: Map<String, Any?>): ProcessedLocation {
        val coords = location["coords"] as? Map<*, *> ?: location
        val lat = (coords["latitude"] as? Number)?.toDouble() ?: return ProcessedLocation.passThrough(location)
        val lng = (coords["longitude"] as? Number)?.toDouble() ?: return ProcessedLocation.passThrough(location)

        val result = evaluate(lat, lng)
        if (result.action == null) return ProcessedLocation.passThrough(location)

        return when (result.action) {
            ACTION_EXCLUDE -> ProcessedLocation.drop()
            ACTION_EVENT_ONLY -> ProcessedLocation.eventOnly(location)
            ACTION_DEGRADE -> {
                val degradedAccuracy = (result.zone?.get("degradedAccuracyMeters") as? Number)?.toDouble() ?: 1000.0
                val degraded = degradeLocation(location, lat, lng, degradedAccuracy)
                ProcessedLocation.degraded(degraded)
            }
            else -> ProcessedLocation.passThrough(location)
        }
    }

    // =========================================================================
    // Processed location result
    // =========================================================================

    /**
     * Encapsulates the routing decisions for location records after privacy checks.
     */
    data class ProcessedLocation(
        val action: Action,
        val location: Map<String, Any?>?,
    ) {
        enum class Action {
            /** Pass through normally — no privacy zone matches. */
            PASS_THROUGH,
            /** Drop entirely — location is in an exclusion zone. */
            DROP,
            /** Event-only — dispatch to active Dart subscribers but do not persist. */
            EVENT_ONLY,
            /** Degraded — persist and dispatch the coordinate with snapped/degraded precision. */
            DEGRADED,
        }

        companion object {
            fun passThrough(location: Map<String, Any?>) = ProcessedLocation(Action.PASS_THROUGH, location)
            fun drop() = ProcessedLocation(Action.DROP, null)
            fun eventOnly(location: Map<String, Any?>) = ProcessedLocation(Action.EVENT_ONLY, location)
            fun degraded(location: Map<String, Any?>) = ProcessedLocation(Action.DEGRADED, location)
        }
    }

    // =========================================================================
    // Internals
    // =========================================================================

    /**
     * Degrades coordinate precision by leveraging the Rust evaluator to snap coordinates
     * to a coarse grid, then updates the coordinates and accuracy metadata fields in the map.
     */
    private fun degradeLocation(
        location: Map<String, Any?>,
        lat: Double,
        lng: Double,
        accuracyMeters: Double,
    ): Map<String, Any?> {
        val evaluator = PrivacyZoneEvaluator()
        val snapped = evaluator.degradeCoordinates(lat, lng, accuracyMeters)

        return location.toMutableMap().apply {
            put("latitude", snapped.lat)
            put("longitude", snapped.lng)
            put("accuracy", accuracyMeters)
            // Synchronize nested coordinate structure if it exists
            val coords = get("coords")
            if (coords is Map<*, *>) {
                @Suppress("UNCHECKED_CAST")
                val updatedCoords = (coords as Map<String, Any?>).toMutableMap().apply {
                    put("latitude", snapped.lat)
                    put("longitude", snapped.lng)
                    put("accuracy", accuracyMeters)
                }
                put("coords", updatedCoords)
            }
        }
    }

    /**
     * Maps a [CorePrivacyZone] struct into a generic map structure for transmission
     * across framework bindings.
     */
    private fun mapFromCorePrivacyZone(zone: CorePrivacyZone): Map<String, Any?> {
        return mapOf(
            "identifier" to zone.identifier,
            "latitude" to zone.latitude,
            "longitude" to zone.longitude,
            "radius" to zone.radius,
            "action" to zone.action,
            "degradedAccuracyMeters" to zone.degradedAccuracyMeters
        )
    }
}
