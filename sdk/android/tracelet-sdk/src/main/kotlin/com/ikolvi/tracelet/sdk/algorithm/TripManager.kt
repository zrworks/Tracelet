package com.ikolvi.tracelet.sdk.algorithm

import uniffi.tracelet_core.TripManager as RustTripManager

/**
 * Tracks trips based on motion state transitions, delegating core logic to Rust.
 *
 * A "trip" starts when the device transitions to moving and ends when it
 * transitions to stationary. Collects start/stop locations, waypoints,
 * total distance (Haversine), and duration.
 */
class TripManager {
    /** Callback invoked when a trip ends with the full trip data map. */
    var onTripEnd: ((Map<String, Any?>) -> Unit)? = null

    private val rustTripManager = RustTripManager()

    /** Whether a trip is currently active. */
    val isTripActive: Boolean
        get() = rustTripManager.isTripActive()

    /**
     * Called on every motion state change.
     *
     * @param isMoving whether the device is now moving
     * @param latitude current latitude (if available)
     * @param longitude current longitude (if available)
     * @param timestamp current timestamp string or null
     */
    fun onMotionStateChanged(
        isMoving: Boolean,
        latitude: Double? = null,
        longitude: Double? = null,
        timestamp: Any? = null,
    ) {
        val nowMs = System.currentTimeMillis()
        val timestampMs = (timestamp as? Number)?.toLong() ?: nowMs

        val tripData = rustTripManager.onMotionStateChanged(
            isMoving,
            latitude,
            longitude,
            timestampMs,
            nowMs
        )

        if (tripData != null) {
            val startMap = mutableMapOf<String, Any?>()
            tripData.startLocation?.let {
                startMap["latitude"] = it.latitude
                startMap["longitude"] = it.longitude
            }

            val stopMap = mutableMapOf<String, Any?>()
            tripData.stopLocation?.let {
                stopMap["latitude"] = it.latitude
                stopMap["longitude"] = it.longitude
            }

            val waypointsMapList = tripData.waypoints.map { wp ->
                mapOf(
                    "latitude" to wp.latitude,
                    "longitude" to wp.longitude,
                    "timestamp" to wp.timestampMs,
                )
            }

            val outMap = mapOf<String, Any?>(
                "isMoving" to false,
                "distance" to tripData.distanceMeters,
                "duration" to tripData.durationSeconds,
                "startLocation" to startMap,
                "stopLocation" to stopMap,
                "waypoints" to waypointsMapList,
            )

            onTripEnd?.invoke(outMap)
        }
    }

    /**
     * Called on every accepted tracking location to record waypoints.
     *
     * @param latitude location latitude
     * @param longitude location longitude
     * @param timestamp location timestamp
     */
    fun onLocationReceived(
        latitude: Double,
        longitude: Double,
        timestamp: Any? = null,
    ) {
        val nowMs = System.currentTimeMillis()
        val timestampMs = (timestamp as? Number)?.toLong() ?: nowMs
        rustTripManager.onLocationReceived(latitude, longitude, timestampMs)
    }

    /** Reset the trip manager state. */
    fun reset() {
        rustTripManager.reset()
    }
}
