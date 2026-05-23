import XCTest
import CoreMotion
@testable import TraceletSDK

final class MotionDetectorTests: XCTestCase {

    var configManager: ConfigManager!
    var stateManager: StateManager!
    var eventDispatcher: DummyEventDispatcher!
    var detector: MotionDetector!

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults.standard
        defaults.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
        configManager = ConfigManager()
        stateManager = StateManager()
        eventDispatcher = DummyEventDispatcher()

        // Force accelerometer-only mode with 1-min timeout
        configManager.setConfig([
            "motion": [
                "disableMotionActivityUpdates": true,
                "stopTimeout": 1
            ]
        ])

        stateManager.isMoving = true

        detector = MotionDetector(
            configManager: configManager,
            stateManager: stateManager,
            eventDispatcher: eventDispatcher
        )
        detector.start()
    }

    override func tearDown() {
        detector.stop()
        super.tearDown()
    }

    func testSustainedStillnessStartsStopTimeoutButKeepsAccelerometerRunning() {
        XCTAssertTrue(stateManager.isMoving, "Should start in moving state")

        // Send 49 samples of stillness (1.0g on Z axis)
        // 50 samples are required (MotionDetector.stillSampleCount = 50)
        let stillAcc = CMAcceleration(x: 0, y: 0, z: 1.0)
        for _ in 0..<49 {
            detector.handleAcceleration(stillAcc)
        }

        // We can't directly check the internal Timer, but we can verify StateManager
        XCTAssertTrue(stateManager.isMoving, "Should still be moving before 50th sample")

        var timeoutStarted = false
        detector.onStopTimeoutStarted = {
            timeoutStarted = true
        }

        // 50th sample should trigger the stop-timeout countdown
        detector.handleAcceleration(stillAcc)

        let expectation = XCTestExpectation(description: "Timeout started")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(timeoutStarted, "Stop timeout should be started")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testMotionDuringStopTimeoutAbortsStopTransition() {
        var timeoutStarted = false
        var timeoutCancelled = false

        detector.onStopTimeoutStarted = { timeoutStarted = true }
        detector.onStopTimeoutCancelled = { timeoutCancelled = true }

        // Send 50 samples of stillness to trigger countdown
        let stillAcc = CMAcceleration(x: 0, y: 0, z: 1.0)
        for _ in 0..<50 {
            detector.handleAcceleration(stillAcc)
        }

        // Wait for main queue dispatch of startStopTimeoutCountdown
        let startExpectation = XCTestExpectation(description: "Timeout started")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(timeoutStarted, "Stop timeout should be started")
            startExpectation.fulfill()
        }
        wait(for: [startExpectation], timeout: 1.0)

        // Now simulate a bump (magnitude > 0.15 threshold)
        // Let's send 1.5g on Z axis (magnitude = 0.5)
        let bumpAcc = CMAcceleration(x: 0, y: 0, z: 1.5)
        detector.handleAcceleration(bumpAcc)

        let cancelExpectation = XCTestExpectation(description: "Timeout cancelled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(timeoutCancelled, "Stop timeout should be cancelled because motion resumed")
            XCTAssertTrue(self.stateManager.isMoving, "State should remain moving")
            cancelExpectation.fulfill()
        }
        wait(for: [cancelExpectation], timeout: 1.0)
    }
}

// Dummy dispatcher for testing
class DummyEventDispatcher: TraceletEventSending {
    func sendMotionChange(_ data: [String : Any]) {}
    func sendSpeedMotionChange(_ data: [String : Any]) {}
    func sendLocation(_ data: [String : Any]) {}
    func sendActivityChange(_ data: [String : Any]) {}
    func sendGeofencesChange(_ data: [String : Any]) {}
    func sendGeofence(_ data: [String : Any]) {}
    func sendHeartbeat(_ data: [String : Any]) {}
    func sendHttp(_ data: [String : Any]) {}
    func sendProviderChange(_ data: [String : Any]) {}
    func sendConnectivityChange(_ data: [String : Any]) {}
    func sendEnabledChange(_ enabled: Bool) {}
    func sendPowerSaveChange(_ isPowerSave: Bool) {}
    func sendNotificationAction(_ data: [String : Any]) {}
    func sendAuthorization(_ data: [String : Any]) {}
    func sendRemoteConfigEvent(_ data: [String : Any]) {}
    func sendSchedule(_ data: [String : Any]) {}
    func sendWatchPosition(_ data: [String : Any]) {}
    func sendTrip(_ data: [String : Any]) {}
    func sendBudgetAdjustment(_ data: [String : Any]) {}
    func sendSpeedMotionEvent(_ data: [String : Any]) {}
    func hasListener(eventName: String) -> Bool { return false }
}
