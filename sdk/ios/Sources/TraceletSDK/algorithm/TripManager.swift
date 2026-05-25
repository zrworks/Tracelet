import Foundation
import TraceletCore

/// Tracks trips based on motion state transitions, delegating core logic to Rust.
public class TripManager {
    /// Callback invoked when a trip ends with the full trip data map.
    public var onTripEnd: (([String: Any?]) -> Void)?

    private let rustTripManager = TraceletCore.TripManager()

    /// Whether a trip is currently active.
    public var isTripActive: Bool {
        return rustTripManager.isTripActive()
    }

    public init() {}

    public func onMotionStateChanged(
        isMoving: Bool,
        latitude: Double? = nil,
        longitude: Double? = nil,
        timestamp: Any? = nil
    ) {
        let now = Date()
        let nowMs = Int64(now.timeIntervalSince1970 * 1000)
        let timestampMs = (timestamp as? NSNumber)?.int64Value ?? nowMs

        let tripData = rustTripManager.onMotionStateChanged(
            isMoving: isMoving,
            latitude: latitude,
            longitude: longitude,
            timestampMs: timestampMs,
            nowMs: nowMs
        )

        if let tripData = tripData {
            var startMap: [String: Any?] = [:]
            if let startLoc = tripData.startLocation {
                startMap["latitude"] = startLoc.latitude
                startMap["longitude"] = startLoc.longitude
            }

            var stopMap: [String: Any?] = [:]
            if let stopLoc = tripData.stopLocation {
                stopMap["latitude"] = stopLoc.latitude
                stopMap["longitude"] = stopLoc.longitude
            }

            let waypoints = tripData.waypoints.map { wp in
                [
                    "latitude": wp.latitude,
                    "longitude": wp.longitude,
                    "timestamp": wp.timestampMs
                ]
            }

            let outData: [String: Any?] = [
                "isMoving": false,
                "distance": tripData.distanceMeters,
                "duration": tripData.durationSeconds,
                "startLocation": startMap,
                "stopLocation": stopMap,
                "waypoints": waypoints
            ]

            onTripEnd?(outData)
        }
    }

    public func onLocationReceived(
        latitude: Double,
        longitude: Double,
        timestamp: Any? = nil
    ) {
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let timestampMs = (timestamp as? NSNumber)?.int64Value ?? nowMs
        rustTripManager.onLocationReceived(
            latitude: latitude,
            longitude: longitude,
            timestampMs: timestampMs
        )
    }

    public func reset() {
        rustTripManager.reset()
    }
}
