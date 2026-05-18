import XCTest
@testable import TraceletSDK

final class TraceletConfigTests: XCTestCase {

    func testTraceletConfigToMap() {
        let config = TraceletConfig()
        let map = config.toMap()
        
        XCTAssertNotNil(map["geo"])
        XCTAssertNotNil(map["app"])
        XCTAssertNotNil(map["android"])
        XCTAssertNotNil(map["ios"])
        XCTAssertNotNil(map["http"])
        XCTAssertNotNil(map["logger"])
        XCTAssertNotNil(map["motion"])
        XCTAssertNotNil(map["geofence"])
        XCTAssertNotNil(map["persistence"])
        XCTAssertNotNil(map["audit"])
        XCTAssertNotNil(map["privacyZone"])
        XCTAssertNotNil(map["security"])
        XCTAssertNotNil(map["attestation"])
    }

    func testGeoConfig() {
        let config = TraceletGeoConfig(desiredAccuracy: .high, distanceFilter: 15.0)
        let map = config.toMap()
        XCTAssertEqual(map["desiredAccuracy"] as? Int, TraceletDesiredAccuracy.high.rawValue)
        XCTAssertEqual(map["distanceFilter"] as? Double, 15.0)
        
        let restored = TraceletGeoConfig.fromMap(map)
        XCTAssertEqual(restored.desiredAccuracy, .high)
        XCTAssertEqual(restored.distanceFilter, 15.0)
    }

    func testAppConfig() {
        let config = TraceletAppConfig(stopOnTerminate: false)
        let map = config.toMap()
        XCTAssertEqual(map["stopOnTerminate"] as? Bool, false)
        
        let restored = TraceletAppConfig.fromMap(map)
        XCTAssertEqual(restored.stopOnTerminate, false)
    }
    
    func testAndroidConfig() {
        let config = TraceletAndroidConfig(locationUpdateInterval: 2000, deferTime: 5000)
        let map = config.toMap()
        XCTAssertEqual(map["locationUpdateInterval"] as? Int, 2000)
        XCTAssertEqual(map["deferTime"] as? Int, 5000)
        
        let restored = TraceletAndroidConfig.fromMap(map)
        XCTAssertEqual(restored.locationUpdateInterval, 2000)
        XCTAssertEqual(restored.deferTime, 5000)
    }
    
    func testIosConfig() {
        let config = TraceletIosConfig(locationAuthorizationRequest: .whenInUse, preventSuspend: true)
        let map = config.toMap()
        XCTAssertEqual(map["locationAuthorizationRequest"] as? String, "WhenInUse")
        XCTAssertEqual(map["preventSuspend"] as? Bool, true)
        
        let restored = TraceletIosConfig.fromMap(map)
        XCTAssertEqual(restored.preventSuspend, true)
    }

    func testMotionConfig() {
        let config = TraceletMotionConfig(stopTimeout: 10, activityTypes: [.onFoot, .inVehicle])
        let map = config.toMap()
        XCTAssertEqual(map["stopTimeout"] as? Int, 10)
        
        let restored = TraceletMotionConfig.fromMap(map)
        XCTAssertEqual(restored.stopTimeout, 10)
        XCTAssertEqual(restored.activityTypes.count, 2)
        XCTAssertTrue(restored.activityTypes.contains(.onFoot))
    }

    func testGeofenceConfig() {
        let config = TraceletGeofenceConfig(geofenceInitialTriggerEntry: false, geofenceProximityRadius: 5000)
        let map = config.toMap()
        XCTAssertEqual(map["geofenceProximityRadius"] as? Int, 5000)
        
        let restored = TraceletGeofenceConfig.fromMap(map)
        XCTAssertEqual(restored.geofenceProximityRadius, 5000)
        XCTAssertEqual(restored.geofenceInitialTriggerEntry, false)
    }

    func testPersistenceConfig() {
        let config = TraceletPersistenceConfig(maxDaysToPersist: 14, maxRecordsToPersist: 5000, persistMode: .location)
        let map = config.toMap()
        XCTAssertEqual(map["maxDaysToPersist"] as? Int, 14)
        XCTAssertEqual(map["persistMode"] as? Int, TraceletPersistMode.location.rawValue)
        
        let restored = TraceletPersistenceConfig.fromMap(map)
        XCTAssertEqual(restored.maxDaysToPersist, 14)
        XCTAssertEqual(restored.persistMode, .location)
    }

    func testAuditConfig() {
        let config = TraceletAuditConfig(enableAuditTrail: true, auditHashAlgorithm: .sha512)
        let map = config.toMap()
        XCTAssertEqual(map["enableAuditTrail"] as? Bool, true)
        XCTAssertEqual(map["auditHashAlgorithm"] as? Int, TraceletHashAlgorithm.sha512.rawValue)
        
        let restored = TraceletAuditConfig.fromMap(map)
        XCTAssertEqual(restored.enableAuditTrail, true)
        XCTAssertEqual(restored.auditHashAlgorithm, .sha512)
    }

    func testPrivacyZoneConfig() {
        let config = TraceletPrivacyZoneConfig(enablePrivacyZones: true)
        let map = config.toMap()
        XCTAssertEqual(map["enablePrivacyZones"] as? Bool, true)
        
        let restored = TraceletPrivacyZoneConfig.fromMap(map)
        XCTAssertEqual(restored.enablePrivacyZones, true)
    }

    func testAttestationConfig() {
        let config = TraceletAttestationConfig(enableDeviceAttestation: true)
        let map = config.toMap()
        XCTAssertEqual(map["enableDeviceAttestation"] as? Bool, true)
        
        let restored = TraceletAttestationConfig.fromMap(map)
        XCTAssertEqual(restored.enableDeviceAttestation, true)
    }
}
