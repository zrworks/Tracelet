package com.ikolvi.tracelet.sdk.audit

import android.content.Context
import com.ikolvi.tracelet.sdk.ConfigManager
import com.ikolvi.tracelet.sdk.db.TraceletDatabase
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
    private val database: TraceletDatabase,
    private val configManager: ConfigManager,
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
        database.insertAuditRecord(uuid, result.hash, result.previousHash, result.chainIndex)

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
     * Verifies the entire audit trail chain.
     *
     * Walks all records in chain-index order, re-computes each hash, and
     * compares to the stored hash. Returns a verification result map.
     */
    fun verifyChain(): Map<String, Any?> {
        val records = database.getAuditTrailWithLocations()
        if (records.isEmpty()) {
            return mapOf(
                "isValid" to true,
                "totalRecords" to 0,
                "verifiedRecords" to 0,
            )
        }

        val rustRecords = records.map { record ->
            val hasLocation = record["has_location"] == true
            val loc = if (hasLocation) {
                uniffi.tracelet_core.LocationRecord(
                    uuid = record["uuid"] as? String ?: "",
                    latitude = (record["latitude"] as? Number)?.toDouble() ?: 0.0,
                    longitude = (record["longitude"] as? Number)?.toDouble() ?: 0.0,
                    timestamp = record["timestamp"]?.toString() ?: "",
                    accuracy = (record["accuracy"] as? Number)?.toDouble() ?: 0.0,
                    speed = (record["speed"] as? Number)?.toDouble() ?: 0.0,
                    heading = (record["heading"] as? Number)?.toDouble() ?: 0.0,
                    altitude = (record["altitude"] as? Number)?.toDouble() ?: 0.0,
                    odometer = (record["odometer"] as? Number)?.toDouble() ?: 0.0,
                    isMoving = record["is_moving"] == true || record["isMoving"] == true
                )
            } else null

            uniffi.tracelet_core.AuditRecordWithLocation(
                hash = record["hash"] as? String ?: "",
                previousHash = record["previous_hash"] as? String ?: "",
                chainIndex = (record["chain_index"] as? Number)?.toInt() ?: -1,
                hasLocation = hasLocation,
                location = loc
            )
        }

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
     * Gets the audit proof for a specific location record.
     *
     * @return A map with `uuid`, `hash`, `previous_hash`, `chain_index`, `timestamp`,
     *         or `null` if not found.
     */
    fun getProof(uuid: String): Map<String, Any?>? {
        return database.getAuditRecord(uuid)
    }

    /**
     * Resets the audit chain state (e.g. after [Tracelet.reset()]).
     */
    fun reset() {
        prefs.edit().clear().apply()
        engine.resetState()
    }
}
