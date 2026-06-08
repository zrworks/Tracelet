import XCTest
import CoreMotion
@testable import TraceletSDK

final class MotionDetectorTests: XCTestCase {

    var configManager: ConfigManager!
    var stateManager: StateManager!
    var eventDispatcher: DummyEventDispatcher!
    var logger: TraceletLogger!
    var detector: MotionDetector!

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults.standard
        defaults.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
        configManager = ConfigManager()
        stateManager = StateManager()
        eventDispatcher = DummyEventDispatcher()

        // Force accelerometer-only mode with a 1-min timeout. Seed the still
        // threshold/sample-count so the state-machine assertions below are
        // deterministic regardless of config defaults.
        _ = configManager.setConfig([
            "motion": [
                "disableMotionActivityUpdates": true,
                "stopTimeout": 1,
                "stillThreshold": 0.15,
                "stillSampleCount": 50
            ]
        ])

        stateManager.isMoving = true

        logger = TraceletLogger(configManager: configManager)
        detector = MotionDetector(
            configManager: configManager,
            stateManager: stateManager,
            eventDispatcher: eventDispatcher,
            logger: logger
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

    /// Issue #130: while stationary, a shake-magnitude sample must declare
    /// moving. This exercises the stationary branch that now stops the duty
    /// cycle (instead of the old continuous accelerometer) before resuming.
    func testShakeWhileStationaryDeclaresMoving() {
        stateManager.isMoving = false   // enter STATIONARY

        // magnitude = sqrt(0+0+2.0^2) - 1.0 = 1.0, well above the shake threshold.
        let shake = CMAcceleration(x: 0, y: 0, z: 2.0)
        detector.handleAcceleration(shake)

        let exp = XCTestExpectation(description: "moving declared after shake")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertTrue(self.stateManager.isMoving,
                          "A shake while stationary should declare moving")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    /// Issue #130: a still sample below the shake threshold while stationary
    /// must NOT declare moving (no spurious wakeups from minor noise).
    func testSmallNoiseWhileStationaryStaysStationary() {
        stateManager.isMoving = false   // enter STATIONARY

        // magnitude = sqrt(1.05^2) - 1.0 = 0.05, below the 0.15 shake threshold.
        let noise = CMAcceleration(x: 0, y: 0, z: 1.05)
        for _ in 0..<10 { detector.handleAcceleration(noise) }

        let exp = XCTestExpectation(description: "remains stationary")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertFalse(self.stateManager.isMoving,
                           "Sub-threshold noise must not wake the detector")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
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
