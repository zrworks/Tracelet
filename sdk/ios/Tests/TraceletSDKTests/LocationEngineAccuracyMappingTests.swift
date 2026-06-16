import CoreLocation
import XCTest

@testable import TraceletSDK

/// Regression tests for the desiredAccuracy enum-to-native mapping in LocationEngine.
///
/// Issue: #198 (Passive accuracy mapped incorrectly, raw values used instead of enum indices)
final class LocationEngineAccuracyMappingTests: XCTestCase {

    private func makeEngine() -> (LocationEngine, ConfigManager, RecordingLocationManager) {
        let db = try! DatabaseManager(dbPath: ":memory:")
        let config = ConfigManager()
        let state = StateManager()
        let sender = NoopEventSender()
        let engine = LocationEngine(
            configManager: config,
            stateManager: state,
            eventDispatcher: sender
        )
        let recorder = RecordingLocationManager()
        engine.locationManager = recorder
        recorder.delegate = engine
        return (engine, config, recorder)
    }

    func testDesiredAccuracyMapping() {
        let (engine, config, recorder) = makeEngine()

        // 0: high
        _ = config.setConfig(["desiredAccuracy": 0])
        engine.configureLocationManager()
        XCTAssertEqual(recorder.desiredAccuracy, kCLLocationAccuracyBest, "0 should map to Best")

        // 1: medium
        _ = config.setConfig(["desiredAccuracy": 1])
        engine.configureLocationManager()
        XCTAssertEqual(recorder.desiredAccuracy, kCLLocationAccuracyHundredMeters, "1 should map to 100m")

        // 2: low
        _ = config.setConfig(["desiredAccuracy": 2])
        engine.configureLocationManager()
        XCTAssertEqual(recorder.desiredAccuracy, kCLLocationAccuracyKilometer, "2 should map to 1km")

        // 3: veryLow
        _ = config.setConfig(["desiredAccuracy": 3])
        engine.configureLocationManager()
        XCTAssertEqual(recorder.desiredAccuracy, kCLLocationAccuracyThreeKilometers, "3 should map to 3km")

        // 4: passive
        _ = config.setConfig(["desiredAccuracy": 4])
        engine.configureLocationManager()
        XCTAssertEqual(recorder.desiredAccuracy, kCLLocationAccuracyThreeKilometers, "4 should map to 3km")

        // Invalid: fallback
        _ = config.setConfig(["desiredAccuracy": 99])
        engine.configureLocationManager()
        XCTAssertEqual(recorder.desiredAccuracy, kCLLocationAccuracyBest, "Invalid should map to Best")
    }
}

// MARK: - Test doubles

private final class RecordingLocationManager: CLLocationManager {
    private var _allowsBackground = false

    override var allowsBackgroundLocationUpdates: Bool {
        get { _allowsBackground }
        set { _allowsBackground = newValue }
    }

    override var authorizationStatus: CLAuthorizationStatus {
        return .authorizedAlways
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
