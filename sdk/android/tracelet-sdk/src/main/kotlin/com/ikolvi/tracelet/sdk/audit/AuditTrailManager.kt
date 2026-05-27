package com.ikolvi.tracelet.sdk.audit

import android.content.Context
import com.ikolvi.tracelet.sdk.ConfigManager
import java.security.MessageDigest
import java.util.Locale

/**
 * **[Enterprise]** Tamper-proof location audit trail manager.
 *
 * Creates a SHA-256 hash chain over persisted location records. Each record's
 * hash is computed from the previous record's hash and a canonical representation
 * of the location data. The chain can be verified to prove that no records were
 * inserted, deleted, or modified.
 *
 * ## Hash Computation
 *
 * ```
 * genesis  = SHA256("tracelet:genesis:" + deviceId)
 * hash[i]  = SHA256(hash[i-1] + "|TRACELET_AUDIT|" + chainIndex + "|" +
 *            uuid + "|" + lat6 + "|" + lng6 + "|" + timestamp + "|" +
 *            accuracy2 + "|" + speed2 + "|" + heading2 + "|" + altitude2 + "|" +
 *            odometer2 + "|" + isMoving01)
 * ```
 *
 * All floating-point values are formatted to fixed decimal places to ensure
 * cross-platform (Android/iOS/server) hash consistency.
 */
class AuditTrailManager(
    private val context: Context,
    private val configManager: ConfigManager,
    private val rustDatabase: uniffi.tracelet_core.DatabaseManager? = null,
) {

    companion object {
        private const val PREFS_NAME = "com.tracelet.audit"
        private const val KEY_CHAIN_INDEX = "chain_index"
        private const val KEY_LATEST_HASH = "latest_hash"
        private const val SEPARATOR = "|TRACELET_AUDIT|"
        private val HEX_CHARS = "0123456789abcdef".toCharArray()
    }

    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /** Thread-local MessageDigest — not thread-safe, so each thread gets its own. */
    private val digestLocal = ThreadLocal.withInitial {
        MessageDigest.getInstance("SHA-256")
    }

    private val engine = uniffi.tracelet_core.AuditTrailEngine(
        android.os.Build.FINGERPRINT,
        prefs.getInt(KEY_CHAIN_INDEX, 0),
        prefs.getString(KEY_LATEST_HASH, null)
    )

    /** Current chain index (next record will get this index). */
    private var chainIndex: Int
        get() = prefs.getInt(KEY_CHAIN_INDEX, 0)
        set(value) {
            prefs.edit().putInt(KEY_CHAIN_INDEX, value).apply()
        }

    /** The latest hash in the chain. */
    private var latestHash: String
        get() = prefs.getString(KEY_LATEST_HASH, null) ?: uniffi.tracelet_core.computeGenesisHash(android.os.Build.FINGERPRINT)
        set(value) {
            prefs.edit().putString(KEY_LATEST_HASH, value).apply()
        }

    /** Whether audit trail is enabled in the current config. */
    fun isEnabled(): Boolean = configManager.getAuditEnabled()

    // =========================================================================
    // Hash computation
    // =========================================================================

    fun computeGenesisHash(): String {
        return uniffi.tracelet_core.computeGenesisHash(android.os.Build.FINGERPRINT)
    }

    fun buildCanonicalString(
        previousHash: String,
        chainIndex: Int,
        uuid: String,
        latitude: Double,
        longitude: Double,
        timestamp: String,
        accuracy: Double,
        speed: Double,
        heading: Double,
        altitude: Double,
        odometer: Double,
        isMoving: Boolean,
    ): String {
        return uniffi.tracelet_core.buildCanonicalString(
            previousHash,
            chainIndex,
            uniffi.tracelet_core.LocationRecord(
                uuid, latitude, longitude, timestamp, accuracy, speed, heading, altitude, odometer, isMoving
            )
        )
    }

    fun sha256(input: String): String {
        return uniffi.tracelet_core.sha256(input)
    }

    // =========================================================================
    // Chain operations
    // =========================================================================

    /**
     * Appends a location to the audit chain.
     *
     * Computes the hash from the location's canonical fields and the previous
     * hash, stores it in the `audit_trail` table, and updates the chain state.
     *
     * @param locationMap The enriched location map (same format as DB insert).
     * @return A map with `audit_hash`, `audit_previous_hash`, `audit_chain_index`
     *         to be merged into the location record, or `null` if audit is disabled.
     */
    fun appendToChain(locationMap: Map<String, Any?>): Map<String, Any?>? {
        if (!isEnabled()) return null

        val uuid = locationMap["uuid"] as? String ?: return null
        val latitude = (locationMap["latitude"] as? Number)?.toDouble() ?: 0.0
        val longitude = (locationMap["longitude"] as? Number)?.toDouble() ?: 0.0
        val timestamp = locationMap["timestamp"]?.toString() ?: ""
        val accuracy = (locationMap["accuracy"] as? Number)?.toDouble() ?: 0.0
        val speed = (locationMap["speed"] as? Number)?.toDouble() ?: 0.0
        val heading = (locationMap["heading"] as? Number)?.toDouble() ?: 0.0
        val altitude = (locationMap["altitude"] as? Number)?.toDouble() ?: 0.0
        val odometer = (locationMap["odometer"] as? Number)?.toDouble() ?: 0.0
        val isMoving = (locationMap["is_moving"] ?: locationMap["isMoving"]) == true

        val loc = uniffi.tracelet_core.LocationRecord(
            uuid, latitude, longitude, timestamp, accuracy, speed, heading, altitude, odometer, isMoving
        )
        
        val result = engine.generateNextHash(loc)

        // Store in audit_trail table
        try {
            rustDatabase?.insertAuditTrail(uuid, result.hash, result.previousHash, result.chainIndex)
        } catch (e: Exception) {
            android.util.Log.e("Tracelet", "Failed to persist audit trail to Rust DB", e)
        }

        // Update chain state
        latestHash = result.hash
        chainIndex = result.chainIndex + 1

        return mapOf(
            "audit_hash" to result.hash,
            "audit_previous_hash" to result.previousHash,
            "audit_chain_index" to result.chainIndex,
        )
    }

    /**
     * Verifies the cryptographic integrity of the entire audit trail chain.
     *
     * Alignment Design Decision:
     * Since location records in the Rust database (`location_events` table) are queried
     * sequentially (ordered by ID) and do not store the runtime UUID column directly,
     * they are aligned 1-to-1 by index with the sequential audit records (ordered by chain index).
     * This index pairing allows us to reconstruct the exact [LocationRecord] models with their
     * original hashing UUIDs and feed them to the Rust [AuditTrailEngine] for verification.
     *
     * @return A map describing the verification status: isValid, totalRecords, verifiedRecords, etc.
     */
    fun verifyChain(): Map<String, Any?> {
        val auditRecords = rustDatabase?.getAuditTrail() ?: emptyList()
        if (auditRecords.isEmpty()) {
            return mapOf(
                "isValid" to true,
                "totalRecords" to 0,
                "verifiedRecords" to 0,
            )
        }

        val locations = rustDatabase?.getLocationsBatch(10000) ?: emptyList()

        // Map sequential audit trail records to AuditRecordWithLocation structures
        val rustRecords = auditRecords.mapIndexed { index, auditRecord ->
            val location = if (index >= 0 && index < locations.size) locations[index] else null
            val hasLocation = location != null

            val loc = if (location != null) {
                // Reconstruct the LocationRecord using the exact UUID string stored in the audit trail block
                uniffi.tracelet_core.LocationRecord(
                    uuid = auditRecord.uuid,
                    latitude = location.latitude,
                    longitude = location.longitude,
                    timestamp = location.timestamp,
                    accuracy = location.accuracy,
                    speed = location.speed,
                    heading = location.heading,
                    altitude = location.altitude,
                    odometer = 0.0, // Default to 0.0 as it is not stored in location_events schema
                    isMoving = location.activity != "still" // Deriving motion state from activity
                )
            } else null

            uniffi.tracelet_core.AuditRecordWithLocation(
                hash = auditRecord.auditHash,
                previousHash = auditRecord.auditPreviousHash,
                chainIndex = auditRecord.auditChainIndex,
                hasLocation = hasLocation,
                location = loc
            )
        }

        // Delegate cryptographic verification to the Rust engine
        val result = engine.verifyChain(rustRecords)

        val map = mutableMapOf<String, Any?>(
            "isValid" to result.isValid,
            "totalRecords" to result.totalRecords,
            "verifiedRecords" to result.verifiedRecords,
        )
        result.brokenAtIndex?.let { map["brokenAtIndex"] = it }
        result.brokenAtUuid?.let { map["brokenAtUuid"] = it }
        result.error?.let { map["error"] = it }

        return map
    }

    /**
     * Retrieves the cryptographic proof for a specific location record by its UUID.
     * Pairs the audit trail record with its corresponding location record by matching their index sequence.
     *
     * @param uuid Unique UUID of the location/audit record.
     * @return A map containing proof details: uuid, hash, previous_hash, chain_index, and location coordinates.
     */
    fun getProof(uuid: String): Map<String, Any?>? {
        val auditRecords = rustDatabase?.getAuditTrail() ?: return null
        val matchedRecord = auditRecords.find { it.uuid == uuid } ?: return null
        
        // Find the index of the audit record to pair with the location record at the same position
        val recordIndex = auditRecords.indexOf(matchedRecord)
        val locations = rustDatabase?.getLocationsBatch(10000) ?: return null
        val location = if (recordIndex >= 0 && recordIndex < locations.size) locations[recordIndex] else null
        
        return mapOf(
            "uuid" to matchedRecord.uuid,
            "hash" to matchedRecord.auditHash,
            "previous_hash" to matchedRecord.auditPreviousHash,
            "chain_index" to matchedRecord.auditChainIndex,
            "timestamp" to (location?.timestamp ?: ""),
            "latitude" to (location?.latitude ?: 0.0),
            "longitude" to (location?.longitude ?: 0.0),
            "accuracy" to (location?.accuracy ?: 0.0),
            "speed" to (location?.speed ?: 0.0),
            "heading" to (location?.heading ?: 0.0),
            "altitude" to (location?.altitude ?: 0.0),
        )
    }

    /**
     * Resets the audit chain state (e.g. after [Tracelet.reset()]).
     */
    fun reset() {
        prefs.edit().clear().apply()
        engine.resetState()
    }
}
