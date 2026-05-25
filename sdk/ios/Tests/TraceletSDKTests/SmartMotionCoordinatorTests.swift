import XCTest
@testable import TraceletSDK

class SmartMotionCoordinatorTests: XCTestCase {

    var sdk: TraceletSdk!
    var coordinator: SmartMotionCoordinator!

    override func setUp() {
        super.setUp()
        // Initialize an isolated SDK instance for the test
        sdk = TraceletSdk.shared
        // Reset state so it's clean for each test
        sdk.reset()
        
        let config: [String: Any] = [
            "motion": [
                "motionDetectionMode": "smart",
                "stationaryTrackingMode": "periodic"
            ]
        ]
        sdk.ready(config: config)
        
        coordinator = sdk.smartMotionCoordinator
    }

    override func tearDown() {
        sdk.reset()
        super.tearDown()
    }

    func testInitialStateIsAccelFalseSpeedTrue() {
        XCTAssertFalse(coordinator.isAccelMoving)
        XCTAssertTrue(coordinator.isSpeedMoving)
    }

    func testOnAccelStateChangeToTrueSwitchesToContinuous() {
        // Initial state is trackingMode=disabled in stateManager because we didn't start.
        // We will mock starting it in periodic mode to see if it switches to continuous
        sdk.startPeriodic()
        XCTAssertEqual(sdk.stateManager.trackingMode, .periodic)
        
        coordinator.onAccelStateChange(isMoving: true)
        
        XCTAssertTrue(coordinator.isAccelMoving)
        // Check if tracking mode switched to continuous
        XCTAssertEqual(sdk.stateManager.trackingMode, .continuous)
        XCTAssertTrue(sdk.stateManager.isMoving)
    }

    func testBothSensorsFalseSwitchesToStationary() {
        sdk.start() // starts in continuous mode
        XCTAssertEqual(sdk.stateManager.trackingMode, .continuous)
        XCTAssertTrue(sdk.stateManager.isMoving)

        coordinator.onSpeedStateChange(isMoving: false)
        
        XCTAssertFalse(coordinator.isSpeedMoving)
        XCTAssertFalse(coordinator.isAccelMoving)
        
        // Should switch to stationary (periodic)
        XCTAssertEqual(sdk.stateManager.trackingMode, .periodic)
        XCTAssertFalse(sdk.stateManager.isMoving)
    }
    
    func testOneSensorTruePreventsStationarySwitch() {
        sdk.start()
        XCTAssertEqual(sdk.stateManager.trackingMode, .continuous)
        
        // Accel is true, Speed becomes false
        coordinator.onAccelStateChange(isMoving: true)
        coordinator.onSpeedStateChange(isMoving: false)
        
        // Should stay in CONTINUOUS
        XCTAssertEqual(sdk.stateManager.trackingMode, .continuous)
        XCTAssertTrue(sdk.stateManager.isMoving)
    }
}
