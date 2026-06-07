import Foundation

/// Single source of truth for converting a persisted location record into the
/// nested location schema emitted by `onLocation` and `getLocations`.
///
/// Issue #126: the sync interceptor sink previously built a flat map with a raw
/// `String` `activity`, diverging from the live nested schema and forcing
/// developers to write conditional parsing (crashing code that assumed the
/// nested shape). Routing every DB-sourced map through this mapper guarantees an
/// identical shape everywhere and restores `route_context` / audit-hash metadata
/// that `getLocations` used to drop. Mirrors the Android `LocationMapper`.
public enum LocationMapper {

    /// Builds the canonical nested location map from raw record fields.
    ///
    /// `routeContext` (a JSON string persisted with the record) is split: audit
    /// fields (`audit_hash`, `audit_previous_hash`, `audit_chain_index`) are
    /// promoted to top-level keys so they populate `Location.auditHash` etc.,
    /// while the rest is nested under `extras.route_context` so it surfaces as
    /// `Location.extras['route_context']`.
    public static func buildLocationMap(
        id: Int64,
        uuid: String?,
        timestamp: String,
        latitude: Double,
        longitude: Double,
        altitude: Double,
        speed: Double,
        heading: Double,
        accuracy: Double,
        isMock: Bool,
        activity: String,
        routeContext: String?,
        isMoving: Bool,
        odometer: Double
    ) -> [String: Any] {
        var map: [String: Any] = [
            "uuid": uuid ?? String(id),
            "timestamp": timestamp,
            "is_moving": isMoving,
            "odometer": odometer,
            "event": "location",
            "mock": isMock,
            "coords": [
                "latitude": latitude,
                "longitude": longitude,
                "altitude": altitude,
                "speed": speed,
                "heading": heading,
                "accuracy": accuracy,
            ],
            "activity": [
                "type": activity,
                "confidence": 100,
            ],
            "battery": [
                "level": -1.0,
                "isCharging": false,
            ],
        ]
        applyRouteContext(&map, routeContext)
        return map
    }

    private static func applyRouteContext(_ map: inout [String: Any], _ routeContext: String?) {
        guard
            let raw = routeContext,
            !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            let data = raw.data(using: .utf8),
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else {
            return
        }

        var extrasRouteContext: [String: Any] = [:]
        for (key, value) in json {
            switch key {
            case "audit_hash":
                map["audit_hash"] = value
            case "audit_previous_hash":
                map["audit_previous_hash"] = value
            case "audit_chain_index":
                map["audit_chain_index"] = value
            default:
                extrasRouteContext[key] = value
            }
        }
        if !extrasRouteContext.isEmpty {
            map["extras"] = ["route_context": extrasRouteContext]
        }
    }
}
