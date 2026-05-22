import Foundation
import CoreLocation

/// Persists plugin configuration via UserDefaults.
///
/// Stores the complete Config map as a JSON blob. Provides typed getters
/// matching all Dart Config fields across sub-configs: GeoConfig, AppConfig,
/// HttpConfig, LoggerConfig, MotionConfig, GeofenceConfig, ForegroundServiceConfig.
public final class ConfigManager {
    private let defaults: UserDefaults
    private let key = "com.tracelet.config"
    private var cache: [String: Any] = [:]

    public init() {
        defaults = UserDefaults.standard
        loadFromDisk()
    }

    // MARK: - Persistence

    public func setConfig(_ config: [String: Any]) -> [String: Any] {
        // Dart sends a nested structure: {geo: {...}, app: {...}, http: {...}, ...}
        // Flatten known section sub-maps into the top level first.
        let sectionKeys: Set<String> = ["geo", "app", "http", "logger", "motion", "geofence", "persistence", "audit", "privacyZone"]
        var flat: [String: Any] = [:]
        for (key, value) in config {
            if sectionKeys.contains(key), let sub = value as? [String: Any] {
                flat.merge(sub) { _, new in new }
            } else {
                flat[key] = value
            }
        }
        // Filter out NSNull / nil values — a partial setConfig() must not
        // overwrite existing non-null config with defaults.  E.g. calling
        // setConfig({app: {heartbeatInterval: -1}}) must not wipe the
        // HTTP URL that was set during ready().
        let filtered = flat.filter { !($0.value is NSNull) }
        cache.merge(filtered) { _, new in new }
        saveToDisk()
        return cache
    }

    public func getConfig() -> [String: Any] {
        return cache
    }

    /// Returns `true` if a config has been persisted at least once.
    public func hasConfig() -> Bool {
        return defaults.data(forKey: key) != nil
    }

    public func reset(_ newConfig: [String: Any]?) {
        cache = defaultConfig()
        if let c = newConfig {
            let _ = setConfig(c)
        }
        saveToDisk()
    }

    private func loadFromDisk() {
        if let data = defaults.data(forKey: key),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            cache = json
        } else {
            cache = defaultConfig()
        }
    }

    private func saveToDisk() {
        if let data = try? JSONSerialization.data(withJSONObject: cache) {
            defaults.set(data, forKey: key)
        }
    }

    // MARK: - Typed Getters

    // GeoConfig
    public func getDesiredAccuracy() -> Int { (cache["desiredAccuracy"] as? NSNumber)?.intValue ?? -1 }
    public func getDistanceFilter() -> Double { cache["distanceFilter"] as? Double ?? 10.0 }
    public func getLocationTimeout() -> Int { (cache["locationTimeout"] as? NSNumber)?.intValue ?? 60 }
    public func getStationaryRadius() -> Double { cache["stationaryRadius"] as? Double ?? 25.0 }
    public func getGeofenceProximityRadius() -> Double { cache["geofenceProximityRadius"] as? Double ?? 1000.0 }
    public func getMaxDaysToPersist() -> Int { (cache["maxDaysToPersist"] as? NSNumber)?.intValue ?? -1 }
    public func getMaxRecordsToPersist() -> Int { (cache["maxRecordsToPersist"] as? NSNumber)?.intValue ?? -1 }
    public func getLocationUpdateInterval() -> Int { (cache["locationUpdateInterval"] as? NSNumber)?.intValue ?? 1000 }
    public func getFastestLocationUpdateInterval() -> Int { (cache["fastestLocationUpdateInterval"] as? NSNumber)?.intValue ?? -1 }
    public func getDeferTime() -> Int { (cache["deferTime"] as? NSNumber)?.intValue ?? 0 }
    public func getAllowIdenticalLocations() -> Bool { cache["allowIdenticalLocations"] as? Bool ?? false }
    public func getUseSignificantChangesOnly() -> Bool { cache["useSignificantChangesOnly"] as? Bool ?? false }
    public func getShowsBackgroundLocationIndicator() -> Bool { cache["showsBackgroundLocationIndicator"] as? Bool ?? false }
    public func getPausesLocationUpdatesAutomatically() -> Bool { cache["pausesLocationUpdatesAutomatically"] as? Bool ?? true }
    public func getDisableLocationAuthorizationAlert() -> Bool { cache["disableLocationAuthorizationAlert"] as? Bool ?? false }
    public func getLocationAuthorizationRequest() -> String { cache["locationAuthorizationRequest"] as? String ?? "Always" }
    public func getStopAfterElapsedMinutes() -> Int { (cache["stopAfterElapsedMinutes"] as? NSNumber)?.intValue ?? -1 }
    public func getMaxMonitoredGeofences() -> Int { (cache["maxMonitoredGeofences"] as? NSNumber)?.intValue ?? -1 }
    public func getEnableTimestampMeta() -> Bool { cache["enableTimestampMeta"] as? Bool ?? false }

    /// Maps the `activityType` config string to a `CLActivityType` (I-M2).
    public func getActivityType() -> CLActivityType {
        let value = cache["activityType"] as? String ?? "other"
        switch value {
        case "automotiveNavigation": return .automotiveNavigation
        case "fitness": return .fitness
        case "otherNavigation": return .otherNavigation
        case "airborne":
            if #available(iOS 12.0, *) { return .airborne }
            return .otherNavigation
        default: return .otherNavigation
        }
    }
    // Periodic mode config
    public func getPeriodicLocationInterval() -> Int { (cache["periodicLocationInterval"] as? NSNumber)?.intValue ?? 900 }
    public func getPeriodicDesiredAccuracy() -> Int { (cache["periodicDesiredAccuracy"] as? NSNumber)?.intValue ?? 1 }
    public func getPeriodicUseForegroundService() -> Bool { cache["periodicUseForegroundService"] as? Bool ?? false }
    public func getPeriodicUseExactAlarms() -> Bool { cache["periodicUseExactAlarms"] as? Bool ?? false }
    // LocationFilter
    public func getOdometerAccuracyThreshold() -> Int { (cache["odometerAccuracyThreshold"] as? NSNumber)?.intValue ?? 0 }
    public func getRejectMockLocations() -> Bool { cache["rejectMockLocations"] as? Bool ?? false }
    public func getMockDetectionLevel() -> Int { (cache["mockDetectionLevel"] as? NSNumber)?.intValue ?? 1 }

    // Dead Reckoning
    public func getEnableDeadReckoning() -> Bool { cache["enableDeadReckoning"] as? Bool ?? false }
    public func getDeadReckoningActivationDelay() -> Int { (cache["deadReckoningActivationDelay"] as? NSNumber)?.intValue ?? 10 }
    public func getDeadReckoningMaxDuration() -> Int { (cache["deadReckoningMaxDuration"] as? NSNumber)?.intValue ?? 120 }

    // AppConfig
    public func isDebug() -> Bool { cache["debug"] as? Bool ?? false }
    public func getLogLevel() -> Int { (cache["logLevel"] as? NSNumber)?.intValue ?? 5 }
    public func getStopOnTerminate() -> Bool { cache["stopOnTerminate"] as? Bool ?? true }
    public func getStartOnBoot() -> Bool { cache["startOnBoot"] as? Bool ?? false }
    public func getHeartbeatInterval() -> Int { (cache["heartbeatInterval"] as? NSNumber)?.intValue ?? 60 }
    public func getSchedule() -> [String] { cache["schedule"] as? [String] ?? [] }
    public func getPreventSuspend() -> Bool { cache["preventSuspend"] as? Bool ?? false }

    // MotionConfig
    public func getIsMoving() -> Bool { cache["isMoving"] as? Bool ?? false }
    public func getStopTimeout() -> Int { (cache["stopTimeout"] as? NSNumber)?.intValue ?? 5 }
    public func getMotionTriggerDelay() -> Int { (cache["motionTriggerDelay"] as? NSNumber)?.intValue ?? 0 }
    public func getStopDetectionDelay() -> Int { (cache["stopDetectionDelay"] as? NSNumber)?.intValue ?? 0 }
    public func getDisableMotionActivityUpdates() -> Bool { cache["disableMotionActivityUpdates"] as? Bool ?? false }
    public func getDisableStopDetection() -> Bool { cache["disableStopDetection"] as? Bool ?? false }
    public func getActivityRecognitionInterval() -> Int { (cache["activityRecognitionInterval"] as? NSNumber)?.intValue ?? 10000 }
    public func getMinimumActivityRecognitionConfidence() -> Int { (cache["minimumActivityRecognitionConfidence"] as? NSNumber)?.intValue ?? 75 }
    public func getStopOnStationary() -> Bool { cache["stopOnStationary"] as? Bool ?? false }
    public func getTriggerActivities() -> String { cache["triggerActivities"] as? String ?? "" }
    
    // Speed Motion Config
    public func getMotionDetectionMode() -> MotionDetectionMode {
        let val = cache["motionDetectionMode"] as? String ?? "activity"
        return val == "speed" ? .speed : .activity
    }
    public func getSpeedMovingThreshold() -> Double { cache["speedMovingThreshold"] as? Double ?? 1.5 }
    public func getSpeedStationaryDelay() -> Int { (cache["speedStationaryDelay"] as? NSNumber)?.intValue ?? 180 }
    public func getStationaryTrackingMode() -> StationaryTrackingMode {
        let val = cache["stationaryTrackingMode"] as? String ?? "periodic"
        return val == "geofences" ? .geofences : .periodic
    }
    public func getStationaryPeriodicInterval() -> Int { (cache["stationaryPeriodicInterval"] as? NSNumber)?.intValue ?? 120 }
    public func getSpeedWakeConfirmCount() -> Int { (cache["speedWakeConfirmCount"] as? NSNumber)?.intValue ?? 1 }

    /// Shake threshold (gravity-subtracted magnitude).
    ///
    /// iOS accelerometer data is processed as `sqrt(x²+y²+z²) - 1.0`,
    /// yielding gravity-subtracted values in g-force units.
    /// Default 0.35 is tuned for CoreMotion's clean, high-precision output.
    /// Do NOT divide by 9.81 — the handler already works in g-force space.
    public func getShakeThreshold() -> Double {
        cache["shakeThreshold"] as? Double ?? 0.35
    }
    /// Still threshold (gravity-subtracted magnitude).
    ///
    /// Samples with `abs(magnitude) < stillThreshold` count as "still".
    /// Default 0.15 is tuned for CoreMotion. Higher than Android's equivalent
    /// because we operate in g-force space directly.
    public func getStillThreshold() -> Double {
        cache["stillThreshold"] as? Double ?? 0.15
    }
    /// Consecutive still samples needed before triggering stillness.
    /// At 10 Hz, 30 samples ≈ 3 seconds of sustained stillness.
    public func getStillSampleCount() -> Int { (cache["stillSampleCount"] as? NSNumber)?.intValue ?? 30 }

    // GeofenceConfig
    public func getGeofenceInitialTriggerEntry() -> Bool { cache["geofenceInitialTriggerEntry"] as? Bool ?? true }
    public func getGeofenceModeKnockOut() -> Bool { cache["geofenceModeKnockOut"] as? Bool ?? false }
    public func getGeofenceModeHighAccuracy() -> Bool { cache["geofenceModeHighAccuracy"] as? Bool ?? false }

    // HttpConfig
    public func getUrl() -> String { cache["url"] as? String ?? "" }
    public func getAutoSync() -> Bool { cache["autoSync"] as? Bool ?? true }
    public func getAutoSyncThreshold() -> Int { (cache["autoSyncThreshold"] as? NSNumber)?.intValue ?? 0 }
    public func getSyncInterval() -> Int { (cache["syncInterval"] as? NSNumber)?.intValue ?? 0 }
    public func getBatchSync() -> Bool { cache["batchSync"] as? Bool ?? false }
    public func getMaxBatchSize() -> Int {
        let value = (cache["maxBatchSize"] as? NSNumber)?.intValue ?? 250
        return value < 0 ? 250 : value
    }
    public func getHttpRootProperty() -> String { cache["httpRootProperty"] as? String ?? "location" }
    public func getHttpHeaders() -> [String: String] {
        if let headers = cache["headers"] as? [String: String] {
            return headers
        }
        // Platform channel may deliver values as [String: Any] — coerce to strings.
        if let headers = cache["headers"] as? [String: Any] {
            return headers.mapValues { "\($0)" }
        }
        return [:]
    }
    public func getHttpMethod() -> String {
        // Dart serializes method as an Int (0 = POST, 1 = PUT).
        if let index = (cache["method"] as? NSNumber)?.intValue {
            return index == 1 ? "PUT" : "POST"
        }
        return cache["method"] as? String ?? "POST"
    }
    public func getHttpTimeout() -> Int { (cache["httpTimeout"] as? NSNumber)?.intValue ?? 60000 }
    public func getLocationsOrderDirection() -> String { cache["locationsOrderDirection"] as? String ?? "ASC" }
    public func getDisableAutoSyncOnCellular() -> Bool { cache["disableAutoSyncOnCellular"] as? Bool ?? false }
    public func getMaxRetries() -> Int { (cache["maxRetries"] as? NSNumber)?.intValue ?? 10 }
    public func getRetryBackoffBase() -> Int { (cache["retryBackoffBase"] as? NSNumber)?.intValue ?? 1000 }
    public func getRetryBackoffCap() -> Int { (cache["retryBackoffCap"] as? NSNumber)?.intValue ?? 300000 }
    public func getEnableDeltaCompression() -> Bool { cache["enableDeltaCompression"] as? Bool ?? false }
    public func getDeltaCoordinatePrecision() -> Int { (cache["deltaCoordinatePrecision"] as? NSNumber)?.intValue ?? 6 }

    // PersistenceConfig
    public func getPersistMode() -> Int { (cache["persistMode"] as? NSNumber)?.intValue ?? 0 }
    public func getLocationTemplate() -> String? { cache["locationTemplate"] as? String }
    public func getGeofenceTemplate() -> String? { cache["geofenceTemplate"] as? String }
    public func getDisableProviderChangeRecord() -> Bool { cache["disableProviderChangeRecord"] as? Bool ?? false }
    public func getPersistenceExtras() -> [String: Any] { cache["persistenceExtras"] as? [String: Any] ?? cache["extras"] as? [String: Any] ?? [:] }

    // LoggerConfig
    public func getLogMaxDays() -> Int { (cache["logMaxDays"] as? NSNumber)?.intValue ?? 3 }

    // AuditConfig (Enterprise)
    public func getAuditEnabled() -> Bool { cache["auditEnabled"] as? Bool ?? cache["enabled"] as? Bool ?? false }
    public func getAuditHashAlgorithm() -> String { cache["hashAlgorithm"] as? String ?? "SHA-256" }
    public func getAuditIncludeExtrasInHash() -> Bool { cache["includeExtrasInHash"] as? Bool ?? false }

    // PrivacyZoneConfig (Enterprise)
    public func getPrivacyZoneEnabled() -> Bool { cache["privacyZoneEnabled"] as? Bool ?? false }

    // SecurityConfig (Enterprise)
    public func getEncryptDatabase() -> Bool { cache["encryptDatabase"] as? Bool ?? false }
    public func getEncryptionKey() -> String? { cache["encryptionKey"] as? String }

    // AttestationConfig (Enterprise)
    public func getAttestationEnabled() -> Bool { cache["attestationEnabled"] as? Bool ?? false }
    public func getAttestationRefreshInterval() -> Int { (cache["attestationRefreshInterval"] as? NSNumber)?.intValue ?? 3600 }
    public func getAttestationVerificationUrl() -> String? { cache["attestationVerificationUrl"] as? String }

    // RemoteConfig (Enterprise)
    public func getRemoteConfigUrl() -> String? {
        let url = cache["remoteConfigUrl"] as? String
        return (url?.isEmpty == false) ? url : nil
    }
    public func getRemoteConfigHeaders() -> [String: String] {
        cache["remoteConfigHeaders"] as? [String: String] ?? [:]
    }
    public func getRemoteConfigTimeout() -> Int { (cache["remoteConfigTimeout"] as? NSNumber)?.intValue ?? 30000 }
    public func getRemoteConfigRefreshInterval() -> Int { (cache["remoteConfigRefreshInterval"] as? NSNumber)?.intValue ?? 3600 }

    // MARK: - Battery Budget
    public func getBatteryBudgetPerHour() -> Double { cache["batteryBudgetPerHour"] as? Double ?? 0.0 }

    // MARK: - SSL Pinning

    public func getSslPinningCertificates() -> [String] {
        if let certs = cache["sslPinningCertificates"] as? [String] {
            return certs
        }
        return []
    }

    public func getSslPinningFingerprints() -> [String] {
        if let fps = cache["sslPinningFingerprints"] as? [String] {
            return fps
        }
        return []
    }

    // MARK: - Dynamic Headers (volatile — not persisted)

    private var dynamicHeaders: [String: String] = [:]

    public func setDynamicHeaders(_ headers: [String: String]) {
        dynamicHeaders = headers
    }

    public func getDynamicHeaders() -> [String: String] { return dynamicHeaders }

    /// Merged headers: static config headers + dynamic headers (dynamic wins).
    public func getMergedHttpHeaders() -> [String: String] {
        let staticHeaders = getHttpHeaders()
        if dynamicHeaders.isEmpty { return staticHeaders }
        return staticHeaders.merging(dynamicHeaders) { _, new in new }
    }

    // MARK: - Route Context (volatile — not persisted)

    private var routeContext: [String: Any]? = nil

    public func setRouteContext(_ context: [String: Any]) {
        routeContext = context
    }

    public func clearRouteContext() {
        routeContext = nil
    }

    public func getRouteContext() -> [String: Any]? { return routeContext }

    // MARK: - Defaults
    private func defaultConfig() -> [String: Any] {
        return [
            "desiredAccuracy": -1,
            "distanceFilter": 10.0,
            "stationaryRadius": 25.0,
            "disableElasticity": false,
            "elasticityMultiplier": 1.0,
            "geofenceProximityRadius": 1000.0,
            "locationUpdateInterval": 1000,
            "fastestLocationUpdateInterval": -1,
            "deferTime": 0,
            "allowIdenticalLocations": false,
            "useSignificantChangesOnly": false,
            "showsBackgroundLocationIndicator": false,
            "pausesLocationUpdatesAutomatically": true,
            "disableLocationAuthorizationAlert": false,
            "locationAuthorizationRequest": "Always",
            "debug": false,
            "logLevel": 5,
            "stopOnTerminate": true,
            "startOnBoot": false,
            "heartbeatInterval": 60,
            "schedule": [] as [String],
            "preventSuspend": false,
            "isMoving": false,
            "stopTimeout": 5,
            "motionTriggerDelay": 0,
            "stopDetectionDelay": 0,
            "disableMotionActivityUpdates": false,
            "disableStopDetection": false,
            "activityRecognitionInterval": 10000,
            "minimumActivityRecognitionConfidence": 75,
            "stopOnStationary": false,
            "triggerActivities": "",
            "stopAfterElapsedMinutes": -1,
            "maxMonitoredGeofences": -1,
            "enableTimestampMeta": false,
            "geofenceInitialTriggerEntry": true,
            "geofenceModeKnockOut": false,
            "geofenceModeHighAccuracy": false,
            "url": "",
            "autoSync": true,
            "autoSyncThreshold": 0,
            "batchSync": false,
            "maxBatchSize": -1,
            "httpRootProperty": "location",
            "headers": [:] as [String: String],
            "method": "POST",
            "httpTimeout": 60000,
            "locationsOrderDirection": "ASC",
            "disableAutoSyncOnCellular": false,
            "persistMode": 0,
            "maxDaysToPersist": -1,
            "maxRecordsToPersist": -1,
            "disableProviderChangeRecord": false,
            "logMaxDays": 3,
        ]
    }
}
