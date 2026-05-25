package com.ikolvi.tracelet.sdk.http

import org.json.JSONObject
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.roundToLong

/**
 * Encodes a batch of location maps into delta-compressed format.
 *
 * The first location is emitted as a full reference (`ref: true`).
 * Subsequent locations are encoded as deltas relative to the previous.
 *
 * Achieves 60–80% payload size reduction for high-frequency batch payloads.
 */
internal object DeltaEncoder {

    /**
     * Encode a batch of location maps into delta-compressed format.
     *
     * @param locations Non-empty, timestamp-ordered location maps.
     * @param precision Coordinate decimal places (5 ≈ 1.1m, 6 ≈ 0.11m).
     * @return List of maps ready for JSON serialization.
     */
    fun encode(
        locations: List<Map<String, Any?>>,
        precision: Int = 6
    ): List<Map<String, Any?>> {
        if (locations.isEmpty()) return emptyList()
        if (locations.size == 1) {
            return listOf(HashMap<String, Any?>(locations.first()).apply { put("ref", true) })
        }

        // Convert List<Map> to JSON string for Rust
        val jsonString = org.json.JSONArray(locations).toString()
        
        // Call Rust core
        val resultString = uniffi.tracelet_core.encodeDeltas(jsonString, precision)
        
        // Parse Rust JSON string back to List<Map>
        val resultJson = org.json.JSONArray(resultString)
        val result = mutableListOf<Map<String, Any?>>()
        for (i in 0 until resultJson.length()) {
            val obj = resultJson.optJSONObject(i) ?: continue
            result.add(jsonToMap(obj))
        }

        return result
    }

    private fun jsonToMap(json: org.json.JSONObject): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>()
        for (key in json.keys()) {
            val value = json.opt(key)
            map[key] = when (value) {
                is org.json.JSONObject -> jsonToMap(value)
                is org.json.JSONArray -> jsonArrayToList(value)
                org.json.JSONObject.NULL -> null
                else -> value
            }
        }
        return map
    }

    private fun jsonArrayToList(array: org.json.JSONArray): List<Any?> {
        val list = mutableListOf<Any?>()
        for (i in 0 until array.length()) {
            val value = array.opt(i)
            list.add(when (value) {
                is org.json.JSONObject -> jsonToMap(value)
                is org.json.JSONArray -> jsonArrayToList(value)
                org.json.JSONObject.NULL -> null
                else -> value
            })
        }
        return list
    }
}
