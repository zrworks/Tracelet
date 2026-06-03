import CoreLocation
import XCTest

@testable import TraceletSDK

/// Tests that `LocationEngine.changePace(true)` fires an additional one-shot
/// `requestLocation()` call on stationary → moving transitions, eliminating
/// the wait for the continuous stream's first `distanceFilter`-gated delivery.
///
/// Issue: https://github.com/Ikolvi/Tracelet/issues/54
final class LocationEngineChangePaceImmediateFixTests: XCTestCase {

    private func makeEngine() -> (LocationEngine, RecordingLocationManager) {
        let db = try! DatabaseManager(dbPath: ":memory:")
        let config = ConfigManager()
        let state = StateManager()
        let sender = NoopEventSender()
        let engine = LocationEngine(
            configManager: config,
            stateManager: state,
            eventDispatcher: sender,
        )
        let recorder = RecordingLocationManager()
        engine.locationManager = recorder
        recorder.delegate = engine
        return (engine, recorder)
    }

    func testChangePaceTrueOnStationaryToMovingFiresImmediateOneShot() {
        let (engine, recorder) = makeEngine()
        XCTAssertEqual(recorder.requestLocationCallCount, 0)

        let result = engine.changePace(true)

        XCTAssertTrue(result)
        XCTAssertEqual(
            recorder.requestLocationCallCount, 1,
            "changePace(true) on stationary→moving must fire one requestLocation()"
        )
    }

    func testChangePaceTrueWhenAlreadyTrackingDoesNotFireExtraOneShot() {
        let (engine, recorder) = makeEngine()

        // First call: transitions stationary → moving (fires one-shot).
        _ = engine.changePace(true)
        XCTAssertEqual(recorder.requestLocationCallCount, 1)

        // Second call: already moving/tracking, must NOT fire another one-shot.
        _ = engine.changePace(true)
        XCTAssertEqual(
            recorder.requestLocationCallCount, 1,
            "Re-entering moving state while already tracking must not fire a new one-shot"
        )
    }

    func testChangePaceFalseDoesNotFireImmediateOneShot() {
        let (engine, recorder) = makeEngine()

        // Establish tracking first.
        _ = engine.changePace(true)
        let baseline = recorder.requestLocationCallCount

        // Now stop — must not trigger a one-shot.
        _ = engine.changePace(false)
        XCTAssertEqual(
            recorder.requestLocationCallCount, baseline,
            "changePace(false) must not fire requestLocation()"
        )
    }
}

// MARK: - Test doubles

/// CLLocationManager subclass that records `requestLocation()` calls and
/// suppresses CoreLocation side effects (background updates, hardware access)
/// that would require entitlements or simulator runtime.
private final class RecordingLocationManager: CLLocationManager {
    var requestLocationCallCount = 0
    private var _allowsBackground = false

    // Override entitlement-gated property to a no-op getter/setter pair.
    // The real setter raises NSInternalInconsistencyException without the
    // UIBackgroundModes:location entitlement, which the test bundle lacks.
    override var allowsBackgroundLocationUpdates: Bool {
        get { _allowsBackground }
        set { _allowsBackground = newValue }
    }

    override var authorizationStatus: CLAuthorizationStatus {
        if #available(iOS 14.0, *) {
            return .authorizedAlways
        } else {
            return .authorizedAlways
        }
    }

    override func requestLocation() {
        requestLocationCallCount += 1
        // Do NOT call super — avoids hitting real CoreLocation in unit tests.
    }

    override func startUpdatingLocation() {
        // No-op — avoid CoreLocation side effects in unit tests.
    }

    override func stopUpdatingLocation() {
        // No-op
    }

    override func startMonitoringSignificantLocationChanges() {
        // No-op
    }

    override func stopMonitoringSignificantLocationChanges() {
        // No-op
    }
}

private final class NoopEventSender: TraceletEventSending {
    func sendLocation(_ data: [String: Any]) {}
    func sendMotionChange(_ data: [String: Any]) {}
    func sendActivityChange(_ data: [String: Any]) {}
    func sendProviderChange(_ data: [String: Any]) {}
    func sendGeofence(_ data: [String: Any]) {}
    func sendGeofencesChange(_ data: [String: Any]) {}
    func sendHeartbeat(_ data: [String: Any]) {}
    func sendHttp(_ data: [String: Any]) {}
    func sendSchedule(_ data: [String: Any]) {}
    func sendPowerSaveChange(_ isPowerSave: Bool) {}
    func sendConnectivityChange(_ data: [String: Any]) {}
    func sendEnabledChange(_ enabled: Bool) {}
    func sendNotificationAction(_ data: [String: Any]) {}
    func sendAuthorization(_ data: [String: Any]) {}
    func sendWatchPosition(_ data: [String: Any]) {}
    func sendRemoteConfigEvent(_ data: [String: Any]) {}
    func sendTrip(_ data: [String: Any]) {}
    func sendBudgetAdjustment(_ data: [String: Any]) {}
    func sendSpeedMotionEvent(_ data: [String: Any]) {}
    func hasListener(eventName: String) -> Bool { false }
}
