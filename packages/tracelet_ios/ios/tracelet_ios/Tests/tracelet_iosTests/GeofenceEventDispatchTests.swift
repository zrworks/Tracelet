import XCTest
@testable import tracelet_ios

/// Regression test: geofence ENTER/EXIT/DWELL must survive the trip from the
/// SDK's structured payload to the Pigeon `TlGeofenceEvent`.
///
/// The SDK's `GeofenceManager` emits geofence events as a structured payload —
/// identifier/action/extras nested under `"geofence"`, location coords at the
/// top-level `"coords"`. A prior version of `PluginEventDispatcher` read
/// `action`/`identifier`/`location` from the TOP level, so every field was nil
/// and `action` silently defaulted to `.enter` — meaning EXIT (and DWELL)
/// transitions reached Dart as ENTER. This pins the mapping so it can't regress.
final class GeofenceEventDispatchTests: XCTestCase {

    /// The exact shape GeofenceManager.handleTransition / the high-accuracy path
    /// produce for a transition.
    private func structuredPayload(action: String) -> [String: Any] {
        [
            "uuid": "abc-123",
            "event": "geofence",
            "timestamp": "2026-06-09T00:00:00.000Z",
            "coords": [
                "latitude": 12.345,
                "longitude": 67.890,
                "accuracy": 0.0,
                "speed": 0.0,
                "heading": 0.0,
                "altitude": 0.0,
            ],
            "geofence": [
                "identifier": "office",
                "action": action,
                "extras": ["tier": "gold"],
            ],
        ]
    }

    func testStructuredPayloadExitMapsToExit() {
        let event = PluginEventDispatcher().makeGeofenceEvent(structuredPayload(action: "EXIT"))

        XCTAssertEqual(event.action, .exit, "EXIT must not be mislabeled as ENTER")
        XCTAssertEqual(event.identifier, "office", "identifier must come from the nested geofence map")
        XCTAssertEqual(event.location.coords.latitude, 12.345, "location must come from top-level coords")
        XCTAssertEqual(event.location.coords.longitude, 67.890)
        XCTAssertEqual(event.extras?["tier"] as? String, "gold", "extras must come from the nested geofence map")
    }

    func testStructuredPayloadEnterMapsToEnter() {
        let event = PluginEventDispatcher().makeGeofenceEvent(structuredPayload(action: "ENTER"))
        XCTAssertEqual(event.action, .enter)
        XCTAssertEqual(event.identifier, "office")
    }

    func testStructuredPayloadDwellMapsToDwell() {
        let event = PluginEventDispatcher().makeGeofenceEvent(structuredPayload(action: "DWELL"))
        XCTAssertEqual(event.action, .dwell)
    }

    func testLegacyFlatPayloadExitStillMapsToExit() {
        // Backward-compatibility: the old flat shape must keep working.
        let legacy: [String: Any] = [
            "identifier": "legacy_zone",
            "action": "EXIT",
            "location": ["coords": ["latitude": 1.0, "longitude": 2.0]],
            "extras": ["k": "v"],
        ]

        let event = PluginEventDispatcher().makeGeofenceEvent(legacy)

        XCTAssertEqual(event.action, .exit)
        XCTAssertEqual(event.identifier, "legacy_zone")
        XCTAssertEqual(event.location.coords.latitude, 1.0)
        XCTAssertEqual(event.extras?["k"] as? String, "v")
    }

    func testUnknownOrMissingActionDefaultsToEnter() {
        let event = PluginEventDispatcher().makeGeofenceEvent(["geofence": ["identifier": "x"]])
        XCTAssertEqual(event.action, .enter)
    }
}
