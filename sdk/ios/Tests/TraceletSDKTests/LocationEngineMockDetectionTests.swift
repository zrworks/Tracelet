import CoreLocation
import XCTest

@testable import TraceletSDK

final class LocationEngineMockDetectionTests: XCTestCase {

    private func makeEngine() -> LocationEngine {
        let db = TraceletDatabase(inMemory: true)
        let config = ConfigManager()
        
        let _ = config.setConfig([
            "mockDetectionLevel": 2,
            "deferTime": 60000,
            "desiredAccuracy": 0,
            "distanceFilter": 0.0
        ])
        
        let state = StateManager()
        let sender = NoopEventSender()
        let engine = LocationEngine(
            configManager: config,
            stateManager: state,
            eventDispatcher: sender,
            database: db
        )
        return engine
    }

    func testDeferredLocationNotFlaggedAsMock() {
        let engine = makeEngine()

        // A real location that was deferred by 60 seconds
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0),
            altitude: 0,
            horizontalAccuracy: 10,
            verticalAccuracy: 10,
            timestamp: Date(timeIntervalSinceNow: -60.0) // 60 seconds ago
        )

        // buildLocationMap evaluates isLocationMock internally
        let locationMap = engine.buildLocationMap(location)
        let isMock = locationMap["mock"] as? Bool ?? true

        // If the fix works, it should NOT be flagged as a mock location
        XCTAssertFalse(isMock, "A location deferred by 60s should not be flagged as mock when deferTime is 60000")
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
