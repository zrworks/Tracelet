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
        let config = TraceletGeofenceConfig(geofenceInitialTriggerEntry: false, geofenceInitialTrigger: true, geofenceProximityRadius: 5000)
        let map = config.toMap()
        XCTAssertEqual(map["geofenceProximityRadius"] as? Int, 5000)
        
        let restored = TraceletGeofenceConfig.fromMap(map)
        XCTAssertEqual(restored.geofenceProximityRadius, 5000)
        XCTAssertEqual(restored.geofenceInitialTriggerEntry, false)
    }

    func testPersistenceConfig() {
        let config = TraceletPersistenceConfig(maxDaysToPersist: 14, maxRecordsToPersist: 5000, persistMode: .location, disableProviderChangeRecord: true)
        let map = config.toMap()
        XCTAssertEqual(map["maxDaysToPersist"] as? Int, 14)
        XCTAssertEqual(map["persistMode"] as? Int, TraceletPersistMode.location.rawValue)
        
        let restored = TraceletPersistenceConfig.fromMap(map)
        XCTAssertEqual(restored.maxDaysToPersist, 14)
        XCTAssertEqual(restored.persistMode, .location)
    }

    func testAuditConfig() {
        let config = TraceletAuditConfig(enabled: true, hashAlgorithm: .sha512, includeExtrasInHash: true)
        let map = config.toMap()
        XCTAssertEqual(map["enabled"] as? Bool, true)
        XCTAssertEqual(map["hashAlgorithm"] as? Int, TraceletHashAlgorithm.sha512.rawValue)
        XCTAssertEqual(map["includeExtrasInHash"] as? Bool, true)
        
        let restored = TraceletAuditConfig.fromMap(map)
        XCTAssertEqual(restored.enabled, true)
        XCTAssertEqual(restored.hashAlgorithm, .sha512)
        XCTAssertEqual(restored.includeExtrasInHash, true)
    }

    func testPrivacyZoneConfig() {
        let config = TraceletPrivacyZoneConfig(enabled: true)
        let map = config.toMap()
        XCTAssertEqual(map["enabled"] as? Bool, true)
        
        let restored = TraceletPrivacyZoneConfig.fromMap(map)
        XCTAssertEqual(restored.enabled, true)
    }

    func testAttestationConfig() {
        let config = TraceletAttestationConfig(enabled: true, refreshInterval: 7200, verificationUrl: "https://test")
        let map = config.toMap()
        XCTAssertEqual(map["enabled"] as? Bool, true)
        
        let restored = TraceletAttestationConfig.fromMap(map)
        XCTAssertEqual(restored.enabled, true)
        XCTAssertEqual(restored.refreshInterval, 7200)
    }

    func testConfigFromMapWithNSNumberValues() {
        // Construct maps where all integer and floating point fields are explicit NSNumbers.
        // This simulates the behavior of Pigeon decoding numbers from Dart into Swift.
        let geoMap: [String: Any] = [
            "desiredAccuracy": NSNumber(value: 0), // high
            "distanceFilter": NSNumber(value: 15.0),
            "stationaryRadius": NSNumber(value: 25.0),
            "locationTimeout": NSNumber(value: 60),
            "elasticityMultiplier": NSNumber(value: 1.0),
            "stopAfterElapsedMinutes": NSNumber(value: -1),
            "maxMonitoredGeofences": NSNumber(value: -1),
            "periodicLocationInterval": NSNumber(value: 900),
            "periodicDesiredAccuracy": NSNumber(value: 1), // medium
            "sparseDistanceThreshold": NSNumber(value: 50.0),
            "sparseMaxIdleSeconds": NSNumber(value: 300),
            "deadReckoningActivationDelay": NSNumber(value: 10),
            "deadReckoningMaxDuration": NSNumber(value: 120),
            "batteryBudgetPerHour": NSNumber(value: 0.0)
        ]
        
        let appMap: [String: Any] = [
            "stopOnTerminate": true,
            "startOnBoot": false,
            "heartbeatInterval": NSNumber(value: 45),
            "remoteConfigTimeout": NSNumber(value: 5000),
            "remoteConfigRefreshInterval": NSNumber(value: 0)
        ]
        
        let androidMap: [String: Any] = [
            "locationUpdateInterval": NSNumber(value: 2000),
            "fastestLocationUpdateInterval": NSNumber(value: 1000),
            "deferTime": NSNumber(value: 5000)
        ]
        
        let iosMap: [String: Any] = [
            "activityType": NSNumber(value: 1) // automotiveNavigation
        ]
        
        let motionMap: [String: Any] = [
            "stopTimeout": NSNumber(value: 10),
            "motionTriggerDelay": NSNumber(value: 5),
            "activityRecognitionInterval": NSNumber(value: 30),
            "minimumActivityRecognitionConfidence": NSNumber(value: 75),
            "stopDetectionDelay": NSNumber(value: 120)
        ]
        
        let geoConfig = TraceletGeoConfig.fromMap(geoMap)
        XCTAssertEqual(geoConfig.desiredAccuracy, .high)
        XCTAssertEqual(geoConfig.distanceFilter, 15.0)
        XCTAssertEqual(geoConfig.stationaryRadius, 25.0)
        XCTAssertEqual(geoConfig.locationTimeout, 60)
        XCTAssertEqual(geoConfig.periodicDesiredAccuracy, .medium)
        
        let appConfig = TraceletAppConfig.fromMap(appMap)
        XCTAssertEqual(appConfig.heartbeatInterval, 45)
        XCTAssertEqual(appConfig.remoteConfigTimeout, 5000)
        XCTAssertEqual(appConfig.remoteConfigRefreshInterval, 0)
        
        let androidConfig = TraceletAndroidConfig.fromMap(androidMap)
        XCTAssertEqual(androidConfig.locationUpdateInterval, 2000)
        XCTAssertEqual(androidConfig.fastestLocationUpdateInterval, 1000)
        XCTAssertEqual(androidConfig.deferTime, 5000)
        
        let iosConfig = TraceletIosConfig.fromMap(iosMap)
        XCTAssertEqual(iosConfig.activityType, .automotiveNavigation)
        
        let motionConfig = TraceletMotionConfig.fromMap(motionMap)
        XCTAssertEqual(motionConfig.stopTimeout, 10)
        XCTAssertEqual(motionConfig.motionTriggerDelay, 5)
        XCTAssertEqual(motionConfig.activityRecognitionInterval, 30)
        XCTAssertEqual(motionConfig.minimumActivityRecognitionConfidence, 75)
        XCTAssertEqual(motionConfig.stopDetectionDelay, 120)
    }
}

