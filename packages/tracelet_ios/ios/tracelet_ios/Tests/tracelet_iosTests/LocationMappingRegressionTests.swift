import XCTest
@testable import tracelet_ios

/// Field-by-field regression tests for the native-map → Pigeon `TlLocation`
/// converter in `TraceletHostApiImpl` (#175). Guards the key contract between
/// the SDK's enriched location map (snake_case: `is_moving`, `is_charging`) and
/// `TlLocation`, so a field is never silently dropped or read under the wrong key.
final class LocationMappingRegressionTests: XCTestCase {

    private func hostApi() -> TraceletHostApiImpl {
        TraceletHostApiImpl(headlessRunner: HeadlessRunner())
    }

    /// A native enriched location map, exactly as the SDK emits it (snake_case).
    private func enrichedDict() -> [String: Any] {
        [
            "uuid": "uuid-123",
            "timestamp": "2026-06-15T10:00:00.000Z",
            "is_moving": true,                       // snake_case — the #175 bug key
            "odometer": 1234.5,
            "event": "location",
            "coords": [
                "latitude": 37.4220,
                "longitude": -122.0841,
                "accuracy": 8.0,
                "speed": 14.0,
                "heading": 90.0,
                "altitude": 12.0,
            ],
            "activity": ["type": "automotive", "confidence": 95],
            "battery": ["level": 0.87, "is_charging": true], // snake_case — the #175 bug key
            "extras": ["alarm": "sos"],
            "address": ["city": "Mountain View", "country": "US"],
        ]
    }

    func testDictToTlLocation_roundtripsEveryField() {
        let loc = hostApi().dictToTlLocation(enrichedDict())

        XCTAssertEqual(loc.uuid, "uuid-123")
        XCTAssertEqual(loc.timestamp, "2026-06-15T10:00:00.000Z")
        XCTAssertEqual(loc.event, "location")
        XCTAssertEqual(loc.odometer, 1234.5)
        XCTAssertTrue(loc.isMoving, "isMoving must come from native `is_moving` (#175)")

        XCTAssertEqual(loc.coords.latitude, 37.4220)
        XCTAssertEqual(loc.coords.longitude, -122.0841)
        XCTAssertEqual(loc.coords.accuracy, 8.0)
        XCTAssertEqual(loc.coords.speed, 14.0)

        XCTAssertEqual(loc.battery.level, 0.87)
        XCTAssertTrue(loc.battery.isCharging, "isCharging must come from native `is_charging` (#175)")

        XCTAssertEqual(loc.activity?.type, "automotive")
        XCTAssertEqual(loc.activity?.confidence, 95)

        XCTAssertEqual(loc.extras?["alarm"] as? String, "sos", "extras must not be dropped (#175)")
        XCTAssertEqual(loc.address?.city, "Mountain View")
        XCTAssertEqual(loc.address?.country, "US")
    }

    func testDictToTlLocation_acceptsCamelCaseToo() {
        var d = enrichedDict()
        d["is_moving"] = nil
        d["isMoving"] = true
        d["battery"] = ["level": 0.5, "isCharging": true]
        let loc = hostApi().dictToTlLocation(d)
        XCTAssertTrue(loc.isMoving)
        XCTAssertTrue(loc.battery.isCharging)
    }

    // MARK: - #206 completeness guards (pigeon → SDK dict input converters)

    /// Every property of `TlCurrentPositionOptions` must survive into the SDK
    /// dict. With all fields set, a forgotten/newly-added field in
    /// `optionsToDict` (the #175/#201 failure mode) trips this automatically.
    func testOptionsToDict_coversEveryPigeonField() {
        let options = TlCurrentPositionOptions(
            desiredAccuracy: .passive,
            timeout: 11,
            maximumAge: 22,
            persist: false,
            samples: 3,
            extras: ["k": "v"]
        )
        let dict = hostApi().optionsToDict(options)

        for child in Mirror(reflecting: options).children {
            guard let label = child.label else { continue }
            XCTAssertNotNil(
                dict[label],
                "optionsToDict dropped Pigeon field '\(label)' (#206) — add it to the converter"
            )
        }
    }

    /// Every property of `TlGeofence` must survive into the SDK dict.
    func testGeofenceToDict_coversEveryPigeonField() {
        let geofence = TlGeofence(
            identifier: "g1",
            latitude: 1.0,
            longitude: 2.0,
            radius: 3.0,
            notifyOnEntry: true,
            notifyOnExit: true,
            notifyOnDwell: true,
            loiteringDelay: 5,
            extras: ["k": "v"],
            vertices: [[1.0, 2.0]]
        )
        let dict = hostApi().tlGeofenceToDict(geofence)

        for child in Mirror(reflecting: geofence).children {
            guard let label = child.label else { continue }
            XCTAssertNotNil(
                dict[label],
                "tlGeofenceToDict dropped Pigeon field '\(label)' (#206) — add it to the converter"
            )
        }
    }
}
