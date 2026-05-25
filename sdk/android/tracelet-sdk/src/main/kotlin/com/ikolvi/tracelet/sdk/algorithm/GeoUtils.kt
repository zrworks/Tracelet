package com.ikolvi.tracelet.sdk.algorithm

import uniffi.tracelet_core.Coordinate
import uniffi.tracelet_core.haversine
import uniffi.tracelet_core.isPointInPolygon

object GeoUtils {
    /**
     * Calculates the great-circle distance between two points on the Earth's surface
     * using the Haversine formula. Returns the distance in meters.
     */
    fun haversine(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        return uniffi.tracelet_core.haversine(lat1, lon1, lat2, lon2)
    }

    /**
     * Determines if a given point is inside a polygon using the Ray-Casting algorithm.
     */
    fun isPointInPolygon(latitude: Double, longitude: Double, polygon: List<List<Double>>): Boolean {
        val coords = polygon.map { Coordinate(it[0], it[1]) }
        return uniffi.tracelet_core.isPointInPolygon(latitude, longitude, coords)
    }
}
