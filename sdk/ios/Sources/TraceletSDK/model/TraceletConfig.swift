import Foundation

// MARK: - Enums

public enum TraceletDesiredAccuracy: Int {
    case high = 0, medium = 1, low = 2, veryLow = 3, passive = 4
}

public enum TraceletLogLevel: Int {
    case verbose = 0, debug = 1, info = 2, warn = 3, error = 4
}

public enum TraceletHttpMethod: Int {
    case post = 0, put = 1
}

public enum TraceletPersistMode: Int {
    case all = 0, location = 1, geofence = 2, none = 3
}

public enum TraceletLocationFilterPolicy: Int {
    case adjust = 0, ignore = 1, discard = 2
}

public enum TraceletMockDetectionLevel: Int {
    case disabled = 0, basic = 1, heuristic = 2
}

public enum TraceletActivityType: Int {
    case other = 0, automotiveNavigation = 1, fitness = 2, otherNavigation = 3, airborne = 4
}

public enum TraceletAuthorizationRequest {
    case always, whenInUse
}

public enum TraceletNotificationPriority: Int {
    case min = -2, low = -1, `default` = 0, high = 1, max = 2
}

public enum TraceletLocationOrder: Int {
    case asc = 0, desc = 1
}

public enum TraceletMotionActivityType: String {
    case still, onFoot = "on_foot", walking, running, onBicycle = "on_bicycle", inVehicle = "in_vehicle", unknown
}

public enum TraceletHashAlgorithm: Int {
    case sha256 = 0, sha512 = 1
}

// MARK: - TraceletConfig

public struct TraceletConfig {
    public let geo: TraceletGeoConfig
    public let app: TraceletAppConfig
    public let android: TraceletAndroidConfig
    public let ios: TraceletIosConfig
    public let http: TraceletHttpConfig
    public let logger: TraceletLoggerConfig
    public let motion: TraceletMotionConfig
    public let geofence: TraceletGeofenceConfig
    public let persistence: TraceletPersistenceConfig
    public let audit: TraceletAuditConfig
    public let privacyZone: TraceletPrivacyZoneConfig
    public let security: TraceletSecurityConfig
    public let attestation: TraceletAttestationConfig

    public init(
        geo: TraceletGeoConfig = .init(),
        app: TraceletAppConfig = .init(),
        android: TraceletAndroidConfig = .init(),
        ios: TraceletIosConfig = .init(),
        http: TraceletHttpConfig = .init(),
        logger: TraceletLoggerConfig = .init(),
        motion: TraceletMotionConfig = .init(),
        geofence: TraceletGeofenceConfig = .init(),
        persistence: TraceletPersistenceConfig = .init(),
        audit: TraceletAuditConfig = .init(),
        privacyZone: TraceletPrivacyZoneConfig = .init(),
        security: TraceletSecurityConfig = .init(),
        attestation: TraceletAttestationConfig = .init()
    ) {
        self.geo = geo
        self.app = app
        self.android = android
        self.ios = ios
        self.http = http
        self.logger = logger
        self.motion = motion
        self.geofence = geofence
        self.persistence = persistence
        self.audit = audit
        self.privacyZone = privacyZone
        self.security = security
        self.attestation = attestation
    }

    public func toMap() -> [String: Any] {
        [
            "geo": geo.toMap(),
            "app": app.toMap(),
            "android": android.toMap(),
            "ios": ios.toMap(),
            "http": http.toMap(),
            "logger": logger.toMap(),
            "motion": motion.toMap(),
            "geofence": geofence.toMap(),
            "persistence": persistence.toMap(),
            "audit": audit.toMap(),
            "privacyZone": privacyZone.toMap(),
            "security": security.toMap(),
            "attestation": attestation.toMap(),
        ]
    }

    public static func fromMap(_ map: [String: Any]) -> TraceletConfig {
        TraceletConfig(
            geo: (map["geo"] as? [String: Any]).map { TraceletGeoConfig.fromMap($0) } ?? TraceletGeoConfig.fromMap(map),
            app: (map["app"] as? [String: Any]).map { TraceletAppConfig.fromMap($0) } ?? TraceletAppConfig.fromMap(map),
            android: (map["android"] as? [String: Any]).map { TraceletAndroidConfig.fromMap($0) } ?? TraceletAndroidConfig.fromMap(map),
            ios: (map["ios"] as? [String: Any]).map { TraceletIosConfig.fromMap($0) } ?? TraceletIosConfig.fromMap(map),
            http: (map["http"] as? [String: Any]).map { TraceletHttpConfig.fromMap($0) } ?? TraceletHttpConfig.fromMap(map),
            logger: (map["logger"] as? [String: Any]).map { TraceletLoggerConfig.fromMap($0) } ?? TraceletLoggerConfig.fromMap(map),
            motion: (map["motion"] as? [String: Any]).map { TraceletMotionConfig.fromMap($0) } ?? TraceletMotionConfig.fromMap(map),
            geofence: (map["geofence"] as? [String: Any]).map { TraceletGeofenceConfig.fromMap($0) } ?? TraceletGeofenceConfig.fromMap(map),
            persistence: (map["persistence"] as? [String: Any]).map { TraceletPersistenceConfig.fromMap($0) } ?? TraceletPersistenceConfig.fromMap(map),
            audit: (map["audit"] as? [String: Any]).map { TraceletAuditConfig.fromMap($0) } ?? TraceletAuditConfig.fromMap(map),
            privacyZone: (map["privacyZone"] as? [String: Any]).map { TraceletPrivacyZoneConfig.fromMap($0) } ?? TraceletPrivacyZoneConfig.fromMap(map),
            security: (map["security"] as? [String: Any]).map { TraceletSecurityConfig.fromMap($0) } ?? TraceletSecurityConfig.fromMap(map),
            attestation: (map["attestation"] as? [String: Any]).map { TraceletAttestationConfig.fromMap($0) } ?? TraceletAttestationConfig.fromMap(map)
        )
    }
}

// MARK: - GeoConfig

public struct TraceletGeoConfig {
    public let desiredAccuracy: TraceletDesiredAccuracy
    public let distanceFilter: Double
    public let stationaryRadius: Double
    public let locationTimeout: Int
    public let disableElasticity: Bool
    public let elasticityMultiplier: Double
    public let stopAfterElapsedMinutes: Int
    public let maxMonitoredGeofences: Int
    public let enableTimestampMeta: Bool
    public let enableAdaptiveMode: Bool
    public let periodicLocationInterval: Int
    public let periodicDesiredAccuracy: TraceletDesiredAccuracy
    public let enableSparseUpdates: Bool
    public let sparseDistanceThreshold: Double
    public let sparseMaxIdleSeconds: Int
    public let enableDeadReckoning: Bool
    public let deadReckoningActivationDelay: Int
    public let deadReckoningMaxDuration: Int
    public let batteryBudgetPerHour: Double
    public let filter: TraceletLocationFilter?

    public init(
        desiredAccuracy: TraceletDesiredAccuracy = .high,
        distanceFilter: Double = 10.0,
        stationaryRadius: Double = 25.0,
        locationTimeout: Int = 60,
        disableElasticity: Bool = false,
        elasticityMultiplier: Double = 1.0,
        stopAfterElapsedMinutes: Int = -1,
        maxMonitoredGeofences: Int = -1,
        enableTimestampMeta: Bool = false,
        enableAdaptiveMode: Bool = false,
        periodicLocationInterval: Int = 900,
        periodicDesiredAccuracy: TraceletDesiredAccuracy = .medium,
        enableSparseUpdates: Bool = false,
        sparseDistanceThreshold: Double = 50.0,
        sparseMaxIdleSeconds: Int = 300,
        enableDeadReckoning: Bool = false,
        deadReckoningActivationDelay: Int = 10,
        deadReckoningMaxDuration: Int = 120,
        batteryBudgetPerHour: Double = 0.0,
        filter: TraceletLocationFilter? = nil
    ) {
        self.desiredAccuracy = desiredAccuracy
        self.distanceFilter = distanceFilter
        self.stationaryRadius = stationaryRadius
        self.locationTimeout = locationTimeout
        self.disableElasticity = disableElasticity
        self.elasticityMultiplier = elasticityMultiplier
        self.stopAfterElapsedMinutes = stopAfterElapsedMinutes
        self.maxMonitoredGeofences = maxMonitoredGeofences
        self.enableTimestampMeta = enableTimestampMeta
        self.enableAdaptiveMode = enableAdaptiveMode
        self.periodicLocationInterval = periodicLocationInterval
        self.periodicDesiredAccuracy = periodicDesiredAccuracy
        self.enableSparseUpdates = enableSparseUpdates
        self.sparseDistanceThreshold = sparseDistanceThreshold
        self.sparseMaxIdleSeconds = sparseMaxIdleSeconds
        self.enableDeadReckoning = enableDeadReckoning
        self.deadReckoningActivationDelay = deadReckoningActivationDelay
        self.deadReckoningMaxDuration = deadReckoningMaxDuration
        self.batteryBudgetPerHour = batteryBudgetPerHour
        self.filter = filter
    }

    public func toMap() -> [String: Any] {
        var map: [String: Any] = [
            "desiredAccuracy": desiredAccuracy.rawValue,
            "distanceFilter": distanceFilter,
            "stationaryRadius": stationaryRadius,
            "locationTimeout": locationTimeout,
            "disableElasticity": disableElasticity,
            "elasticityMultiplier": elasticityMultiplier,
            "stopAfterElapsedMinutes": stopAfterElapsedMinutes,
            "maxMonitoredGeofences": maxMonitoredGeofences,
            "enableTimestampMeta": enableTimestampMeta,
            "enableAdaptiveMode": enableAdaptiveMode,
            "periodicLocationInterval": periodicLocationInterval,
            "periodicDesiredAccuracy": periodicDesiredAccuracy.rawValue,
            "enableSparseUpdates": enableSparseUpdates,
            "sparseDistanceThreshold": sparseDistanceThreshold,
            "sparseMaxIdleSeconds": sparseMaxIdleSeconds,
            "enableDeadReckoning": enableDeadReckoning,
            "deadReckoningActivationDelay": deadReckoningActivationDelay,
            "deadReckoningMaxDuration": deadReckoningMaxDuration,
            "batteryBudgetPerHour": batteryBudgetPerHour,
        ]
        if let filter = filter { map["filter"] = filter.toMap() }
        return map
    }

    public static func fromMap(_ map: [String: Any]) -> TraceletGeoConfig {
        TraceletGeoConfig(
            desiredAccuracy: TraceletDesiredAccuracy(rawValue: map["desiredAccuracy"] as? Int ?? 0) ?? .high,
            distanceFilter: (map["distanceFilter"] as? NSNumber)?.doubleValue ?? 10.0,
            stationaryRadius: (map["stationaryRadius"] as? NSNumber)?.doubleValue ?? 25.0,
            locationTimeout: map["locationTimeout"] as? Int ?? 60,
            disableElasticity: map["disableElasticity"] as? Bool ?? false,
            elasticityMultiplier: (map["elasticityMultiplier"] as? NSNumber)?.doubleValue ?? 1.0,
            stopAfterElapsedMinutes: map["stopAfterElapsedMinutes"] as? Int ?? -1,
            maxMonitoredGeofences: map["maxMonitoredGeofences"] as? Int ?? -1,
            enableTimestampMeta: map["enableTimestampMeta"] as? Bool ?? false,
            enableAdaptiveMode: map["enableAdaptiveMode"] as? Bool ?? false,
            periodicLocationInterval: map["periodicLocationInterval"] as? Int ?? 900,
            periodicDesiredAccuracy: TraceletDesiredAccuracy(rawValue: map["periodicDesiredAccuracy"] as? Int ?? 1) ?? .medium,
            enableSparseUpdates: map["enableSparseUpdates"] as? Bool ?? false,
            sparseDistanceThreshold: (map["sparseDistanceThreshold"] as? NSNumber)?.doubleValue ?? 50.0,
            sparseMaxIdleSeconds: map["sparseMaxIdleSeconds"] as? Int ?? 300,
            enableDeadReckoning: map["enableDeadReckoning"] as? Bool ?? false,
            deadReckoningActivationDelay: map["deadReckoningActivationDelay"] as? Int ?? 10,
            deadReckoningMaxDuration: map["deadReckoningMaxDuration"] as? Int ?? 120,
            batteryBudgetPerHour: (map["batteryBudgetPerHour"] as? NSNumber)?.doubleValue ?? 0.0,
            filter: (map["filter"] as? [String: Any]).map { TraceletLocationFilter.fromMap($0) }
        )
    }
}

// MARK: - AndroidConfig

public struct TraceletAndroidConfig {
    public let locationUpdateInterval: Int
    public let fastestLocationUpdateInterval: Int
    public let deferTime: Int
    public let allowIdenticalLocations: Bool
    public let geofenceModeHighAccuracy: Bool
    public let periodicUseForegroundService: Bool
    public let periodicUseExactAlarms: Bool
    public let scheduleUseAlarmManager: Bool
    public let foregroundService: TraceletForegroundServiceConfig

    public init(
        locationUpdateInterval: Int = 1000,
        fastestLocationUpdateInterval: Int = 500,
        deferTime: Int = 0,
        allowIdenticalLocations: Bool = false,
        geofenceModeHighAccuracy: Bool = false,
        periodicUseForegroundService: Bool = false,
        periodicUseExactAlarms: Bool = false,
        scheduleUseAlarmManager: Bool = false,
        foregroundService: TraceletForegroundServiceConfig = .init()
    ) {
        self.locationUpdateInterval = locationUpdateInterval
        self.fastestLocationUpdateInterval = fastestLocationUpdateInterval
        self.deferTime = deferTime
        self.allowIdenticalLocations = allowIdenticalLocations
        self.geofenceModeHighAccuracy = geofenceModeHighAccuracy
        self.periodicUseForegroundService = periodicUseForegroundService
        self.periodicUseExactAlarms = periodicUseExactAlarms
        self.scheduleUseAlarmManager = scheduleUseAlarmManager
        self.foregroundService = foregroundService
    }

    public func toMap() -> [String: Any] {
        [
            "locationUpdateInterval": locationUpdateInterval,
            "fastestLocationUpdateInterval": fastestLocationUpdateInterval,
            "deferTime": deferTime,
            "allowIdenticalLocations": allowIdenticalLocations,
            "geofenceModeHighAccuracy": geofenceModeHighAccuracy,
            "periodicUseForegroundService": periodicUseForegroundService,
            "periodicUseExactAlarms": periodicUseExactAlarms,
            "scheduleUseAlarmManager": scheduleUseAlarmManager,
            "foregroundService": foregroundService.toMap()
        ]
    }

    public static func fromMap(_ map: [String: Any]) -> TraceletAndroidConfig {
        TraceletAndroidConfig(
            locationUpdateInterval: map["locationUpdateInterval"] as? Int ?? 1000,
            fastestLocationUpdateInterval: map["fastestLocationUpdateInterval"] as? Int ?? 500,
            deferTime: map["deferTime"] as? Int ?? 0,
            allowIdenticalLocations: map["allowIdenticalLocations"] as? Bool ?? false,
            geofenceModeHighAccuracy: map["geofenceModeHighAccuracy"] as? Bool ?? false,
            periodicUseForegroundService: map["periodicUseForegroundService"] as? Bool ?? false,
            periodicUseExactAlarms: map["periodicUseExactAlarms"] as? Bool ?? false,
            scheduleUseAlarmManager: map["scheduleUseAlarmManager"] as? Bool ?? false,
            foregroundService: (map["foregroundService"] as? [String: Any]).map { TraceletForegroundServiceConfig.fromMap($0) } ?? .init()
        )
    }
}

// MARK: - IosConfig

public struct TraceletIosConfig {
    public let activityType: TraceletActivityType
    public let useSignificantChangesOnly: Bool
    public let showsBackgroundLocationIndicator: Bool
    public let pausesLocationUpdatesAutomatically: Bool
    public let locationAuthorizationRequest: TraceletAuthorizationRequest
    public let disableLocationAuthorizationAlert: Bool
    public let preventSuspend: Bool

    public init(
        activityType: TraceletActivityType = .other,
        useSignificantChangesOnly: Bool = false,
        showsBackgroundLocationIndicator: Bool = false,
        pausesLocationUpdatesAutomatically: Bool = false,
        locationAuthorizationRequest: TraceletAuthorizationRequest = .always,
        disableLocationAuthorizationAlert: Bool = false,
        preventSuspend: Bool = false
    ) {
        self.activityType = activityType
        self.useSignificantChangesOnly = useSignificantChangesOnly
        self.showsBackgroundLocationIndicator = showsBackgroundLocationIndicator
        self.pausesLocationUpdatesAutomatically = pausesLocationUpdatesAutomatically
        self.locationAuthorizationRequest = locationAuthorizationRequest
        self.disableLocationAuthorizationAlert = disableLocationAuthorizationAlert
        self.preventSuspend = preventSuspend
    }

    public func toMap() -> [String: Any] {
        [
            "activityType": activityType.rawValue,
            "useSignificantChangesOnly": useSignificantChangesOnly,
            "showsBackgroundLocationIndicator": showsBackgroundLocationIndicator,
            "pausesLocationUpdatesAutomatically": pausesLocationUpdatesAutomatically,
            "locationAuthorizationRequest": locationAuthorizationRequest == .always ? "Always" : "WhenInUse",
            "disableLocationAuthorizationAlert": disableLocationAuthorizationAlert,
            "preventSuspend": preventSuspend
        ]
    }

    public static func fromMap(_ map: [String: Any]) -> TraceletIosConfig {
        TraceletIosConfig(
            activityType: TraceletActivityType(rawValue: map["activityType"] as? Int ?? 0) ?? .other,
            useSignificantChangesOnly: map["useSignificantChangesOnly"] as? Bool ?? false,
            showsBackgroundLocationIndicator: map["showsBackgroundLocationIndicator"] as? Bool ?? false,
            pausesLocationUpdatesAutomatically: map["pausesLocationUpdatesAutomatically"] as? Bool ?? false,
            locationAuthorizationRequest: (map["locationAuthorizationRequest"] as? String) == "WhenInUse" ? .whenInUse : .always,
            disableLocationAuthorizationAlert: map["disableLocationAuthorizationAlert"] as? Bool ?? false,
            preventSuspend: map["preventSuspend"] as? Bool ?? false
        )
    }
}

// MARK: - TraceletLocationFilter
public struct TraceletLocationFilter {
    public let policy: TraceletLocationFilterPolicy
    public let maxImpliedSpeed: Int, odometerAccuracyThreshold: Int, trackingAccuracyThreshold: Int
    public let useKalmanFilter: Bool, rejectMockLocations: Bool
    public let mockDetectionLevel: TraceletMockDetectionLevel
    public init(policy: TraceletLocationFilterPolicy = .adjust, maxImpliedSpeed: Int = 0, odometerAccuracyThreshold: Int = 0, trackingAccuracyThreshold: Int = 0, useKalmanFilter: Bool = false, rejectMockLocations: Bool = false, mockDetectionLevel: TraceletMockDetectionLevel = .disabled) { self.policy = policy; self.maxImpliedSpeed = maxImpliedSpeed; self.odometerAccuracyThreshold = odometerAccuracyThreshold; self.trackingAccuracyThreshold = trackingAccuracyThreshold; self.useKalmanFilter = useKalmanFilter; self.rejectMockLocations = rejectMockLocations; self.mockDetectionLevel = mockDetectionLevel }
    public func toMap() -> [String: Any] { ["policy": policy.rawValue, "maxImpliedSpeed": maxImpliedSpeed, "odometerAccuracyThreshold": odometerAccuracyThreshold, "trackingAccuracyThreshold": trackingAccuracyThreshold, "useKalmanFilter": useKalmanFilter, "rejectMockLocations": rejectMockLocations, "mockDetectionLevel": mockDetectionLevel.rawValue] }
    public static func fromMap(_ map: [String: Any]) -> TraceletLocationFilter { TraceletLocationFilter(policy: TraceletLocationFilterPolicy(rawValue: map["policy"] as? Int ?? 0) ?? .adjust, maxImpliedSpeed: map["maxImpliedSpeed"] as? Int ?? 0, odometerAccuracyThreshold: map["odometerAccuracyThreshold"] as? Int ?? 0, trackingAccuracyThreshold: map["trackingAccuracyThreshold"] as? Int ?? 0, useKalmanFilter: map["useKalmanFilter"] as? Bool ?? false, rejectMockLocations: map["rejectMockLocations"] as? Bool ?? false, mockDetectionLevel: TraceletMockDetectionLevel(rawValue: map["mockDetectionLevel"] as? Int ?? 0) ?? .disabled) }
}

// MARK: - TraceletAppConfig
public struct TraceletAppConfig {
    public let stopOnTerminate: Bool, startOnBoot: Bool
    public let heartbeatInterval: Int
    public let schedule: [String]
    public let remoteConfigUrl: String?
    public let remoteConfigHeaders: [String: String]
    public let remoteConfigTimeout: Int, remoteConfigRefreshInterval: Int
    public init(stopOnTerminate: Bool = true, startOnBoot: Bool = false, heartbeatInterval: Int = 60, schedule: [String] = [], remoteConfigUrl: String? = nil, remoteConfigHeaders: [String: String] = [:], remoteConfigTimeout: Int = 10000, remoteConfigRefreshInterval: Int = 0) { self.stopOnTerminate = stopOnTerminate; self.startOnBoot = startOnBoot; self.heartbeatInterval = heartbeatInterval; self.schedule = schedule; self.remoteConfigUrl = remoteConfigUrl; self.remoteConfigHeaders = remoteConfigHeaders; self.remoteConfigTimeout = remoteConfigTimeout; self.remoteConfigRefreshInterval = remoteConfigRefreshInterval }
    public func toMap() -> [String: Any] { var map: [String: Any] = ["stopOnTerminate": stopOnTerminate, "startOnBoot": startOnBoot, "heartbeatInterval": heartbeatInterval, "schedule": schedule, "remoteConfigHeaders": remoteConfigHeaders, "remoteConfigTimeout": remoteConfigTimeout, "remoteConfigRefreshInterval": remoteConfigRefreshInterval]; if let url = remoteConfigUrl { map["remoteConfigUrl"] = url }; return map }
    public static func fromMap(_ map: [String: Any]) -> TraceletAppConfig { TraceletAppConfig(stopOnTerminate: map["stopOnTerminate"] as? Bool ?? true, startOnBoot: map["startOnBoot"] as? Bool ?? false, heartbeatInterval: map["heartbeatInterval"] as? Int ?? 60, schedule: map["schedule"] as? [String] ?? [], remoteConfigUrl: map["remoteConfigUrl"] as? String, remoteConfigHeaders: map["remoteConfigHeaders"] as? [String: String] ?? [:], remoteConfigTimeout: map["remoteConfigTimeout"] as? Int ?? 10000, remoteConfigRefreshInterval: map["remoteConfigRefreshInterval"] as? Int ?? 0) }
}

// MARK: - TraceletForegroundServiceConfig
public struct TraceletForegroundServiceConfig {
    public let enabled: Bool; public let channelId: String, channelName: String, notificationTitle: String, notificationText: String
    public let notificationColor: String?, notificationSmallIcon: String?, notificationLargeIcon: String?
    public let notificationPriority: TraceletNotificationPriority; public let notificationOngoing: Bool; public let actions: [String]
    public init(enabled: Bool = true, channelId: String = "tracelet_channel", channelName: String = "Tracelet", notificationTitle: String = "Tracelet", notificationText: String = "Tracking location in background", notificationColor: String? = nil, notificationSmallIcon: String? = nil, notificationLargeIcon: String? = nil, notificationPriority: TraceletNotificationPriority = .default, notificationOngoing: Bool = true, actions: [String] = []) { self.enabled = enabled; self.channelId = channelId; self.channelName = channelName; self.notificationTitle = notificationTitle; self.notificationText = notificationText; self.notificationColor = notificationColor; self.notificationSmallIcon = notificationSmallIcon; self.notificationLargeIcon = notificationLargeIcon; self.notificationPriority = notificationPriority; self.notificationOngoing = notificationOngoing; self.actions = actions }
    public func toMap() -> [String: Any] { var map: [String: Any] = ["enabled": enabled, "channelId": channelId, "channelName": channelName, "notificationTitle": notificationTitle, "notificationText": notificationText, "notificationPriority": notificationPriority.rawValue, "notificationOngoing": notificationOngoing, "actions": actions]; if let color = notificationColor { map["notificationColor"] = color }; if let small = notificationSmallIcon { map["notificationSmallIcon"] = small }; if let large = notificationLargeIcon { map["notificationLargeIcon"] = large }; return map }
    public static func fromMap(_ map: [String: Any]) -> TraceletForegroundServiceConfig { TraceletForegroundServiceConfig(enabled: map["enabled"] as? Bool ?? true, channelId: map["channelId"] as? String ?? "tracelet_channel", channelName: map["channelName"] as? String ?? "Tracelet", notificationTitle: map["notificationTitle"] as? String ?? "Tracelet", notificationText: map["notificationText"] as? String ?? "Tracking location in background", notificationColor: map["notificationColor"] as? String, notificationSmallIcon: map["notificationSmallIcon"] as? String, notificationLargeIcon: map["notificationLargeIcon"] as? String, notificationPriority: TraceletNotificationPriority(rawValue: map["notificationPriority"] as? Int ?? 0) ?? .default, notificationOngoing: map["notificationOngoing"] as? Bool ?? true, actions: map["actions"] as? [String] ?? []) }
}

// MARK: - TraceletHttpConfig
public struct TraceletHttpConfig {
    public let url: String?
    public let method: TraceletHttpMethod
    public let headers: [String: String]
    public let httpRootProperty: String
    public let batchSync: Bool, maxBatchSize: Int, autoSync: Bool, autoSyncThreshold: Int, httpTimeout: Int
    public let params: [String: Any]
    public let locationsOrderDirection: TraceletLocationOrder
    public let extras: [String: Any]
    public let disableAutoSyncOnCellular: Bool
    public let maxRetries: Int, retryBackoffBase: Int, retryBackoffCap: Int
    public let enableDeltaCompression: Bool, deltaCoordinatePrecision: Int
    public let sslPinningCertificates: [String], sslPinningFingerprints: [String]
    public init(url: String? = nil, method: TraceletHttpMethod = .post, headers: [String: String] = [:], httpRootProperty: String = "location", batchSync: Bool = false, maxBatchSize: Int = 250, autoSync: Bool = true, autoSyncThreshold: Int = 0, httpTimeout: Int = 60000, params: [String: Any] = [:], locationsOrderDirection: TraceletLocationOrder = .asc, extras: [String: Any] = [:], disableAutoSyncOnCellular: Bool = false, maxRetries: Int = 10, retryBackoffBase: Int = 1000, retryBackoffCap: Int = 300000, enableDeltaCompression: Bool = false, deltaCoordinatePrecision: Int = 6, sslPinningCertificates: [String] = [], sslPinningFingerprints: [String] = []) { self.url = url; self.method = method; self.headers = headers; self.httpRootProperty = httpRootProperty; self.batchSync = batchSync; self.maxBatchSize = maxBatchSize; self.autoSync = autoSync; self.autoSyncThreshold = autoSyncThreshold; self.httpTimeout = httpTimeout; self.params = params; self.locationsOrderDirection = locationsOrderDirection; self.extras = extras; self.disableAutoSyncOnCellular = disableAutoSyncOnCellular; self.maxRetries = maxRetries; self.retryBackoffBase = retryBackoffBase; self.retryBackoffCap = retryBackoffCap; self.enableDeltaCompression = enableDeltaCompression; self.deltaCoordinatePrecision = deltaCoordinatePrecision; self.sslPinningCertificates = sslPinningCertificates; self.sslPinningFingerprints = sslPinningFingerprints }
    public func toMap() -> [String: Any] { var map: [String: Any] = ["method": method.rawValue, "headers": headers, "httpRootProperty": httpRootProperty, "batchSync": batchSync, "maxBatchSize": maxBatchSize, "autoSync": autoSync, "autoSyncThreshold": autoSyncThreshold, "httpTimeout": httpTimeout, "params": params, "locationsOrderDirection": locationsOrderDirection.rawValue, "httpExtras": extras, "disableAutoSyncOnCellular": disableAutoSyncOnCellular, "maxRetries": maxRetries, "retryBackoffBase": retryBackoffBase, "retryBackoffCap": retryBackoffCap, "enableDeltaCompression": enableDeltaCompression, "deltaCoordinatePrecision": deltaCoordinatePrecision, "sslPinningCertificates": sslPinningCertificates, "sslPinningFingerprints": sslPinningFingerprints]; if let url = url { map["url"] = url }; return map }
    public static func fromMap(_ map: [String: Any]) -> TraceletHttpConfig { TraceletHttpConfig(url: map["url"] as? String, method: TraceletHttpMethod(rawValue: map["method"] as? Int ?? 0) ?? .post, headers: map["headers"] as? [String: String] ?? [:], httpRootProperty: map["httpRootProperty"] as? String ?? "location", batchSync: map["batchSync"] as? Bool ?? false, maxBatchSize: map["maxBatchSize"] as? Int ?? 250, autoSync: map["autoSync"] as? Bool ?? true, autoSyncThreshold: map["autoSyncThreshold"] as? Int ?? 0, httpTimeout: map["httpTimeout"] as? Int ?? 60000, params: map["params"] as? [String: Any] ?? [:], locationsOrderDirection: TraceletLocationOrder(rawValue: map["locationsOrderDirection"] as? Int ?? 0) ?? .asc, extras: map["httpExtras"] as? [String: Any] ?? [:], disableAutoSyncOnCellular: map["disableAutoSyncOnCellular"] as? Bool ?? false, maxRetries: map["maxRetries"] as? Int ?? 10, retryBackoffBase: map["retryBackoffBase"] as? Int ?? 1000, retryBackoffCap: map["retryBackoffCap"] as? Int ?? 300000, enableDeltaCompression: map["enableDeltaCompression"] as? Bool ?? false, deltaCoordinatePrecision: map["deltaCoordinatePrecision"] as? Int ?? 6, sslPinningCertificates: map["sslPinningCertificates"] as? [String] ?? [], sslPinningFingerprints: map["sslPinningFingerprints"] as? [String] ?? []) }
}

// MARK: - TraceletLoggerConfig
public struct TraceletLoggerConfig {
    public let logLevel: TraceletLogLevel, logMaxDays: Int, debug: Bool
    public init(logLevel: TraceletLogLevel = .info, logMaxDays: Int = 3, debug: Bool = false) { self.logLevel = logLevel; self.logMaxDays = logMaxDays; self.debug = debug }
    public func toMap() -> [String: Any] { ["logLevel": logLevel.rawValue, "logMaxDays": logMaxDays, "debug": debug] }
    public static func fromMap(_ map: [String: Any]) -> TraceletLoggerConfig { TraceletLoggerConfig(logLevel: TraceletLogLevel(rawValue: map["logLevel"] as? Int ?? 2) ?? .info, logMaxDays: map["logMaxDays"] as? Int ?? 3, debug: map["debug"] as? Bool ?? false) }
}

// MARK: - TraceletMotionConfig
public struct TraceletMotionConfig {
    public let stopTimeout: Int, motionTriggerDelay: Int, disableMotionActivityUpdates: Bool, isMoving: Bool
    public let activityRecognitionInterval: Int, minimumActivityRecognitionConfidence: Int, disableStopDetection: Bool, stopDetectionDelay: Int, stopOnStationary: Bool
    public let activityTypes: [TraceletMotionActivityType]
    public init(stopTimeout: Int = 5, motionTriggerDelay: Int = 0, disableMotionActivityUpdates: Bool = false, isMoving: Bool = false, activityRecognitionInterval: Int = 10000, minimumActivityRecognitionConfidence: Int = 75, disableStopDetection: Bool = false, stopDetectionDelay: Int = 0, stopOnStationary: Bool = false, activityTypes: [TraceletMotionActivityType] = [.still, .onFoot, .walking, .running, .onBicycle, .inVehicle]) { self.stopTimeout = stopTimeout; self.motionTriggerDelay = motionTriggerDelay; self.disableMotionActivityUpdates = disableMotionActivityUpdates; self.isMoving = isMoving; self.activityRecognitionInterval = activityRecognitionInterval; self.minimumActivityRecognitionConfidence = minimumActivityRecognitionConfidence; self.disableStopDetection = disableStopDetection; self.stopDetectionDelay = stopDetectionDelay; self.stopOnStationary = stopOnStationary; self.activityTypes = activityTypes }
    public func toMap() -> [String: Any] { ["stopTimeout": stopTimeout, "motionTriggerDelay": motionTriggerDelay, "disableMotionActivityUpdates": disableMotionActivityUpdates, "isMoving": isMoving, "activityRecognitionInterval": activityRecognitionInterval, "minimumActivityRecognitionConfidence": minimumActivityRecognitionConfidence, "disableStopDetection": disableStopDetection, "stopDetectionDelay": stopDetectionDelay, "stopOnStationary": stopOnStationary, "activityTypes": activityTypes.map { $0.rawValue }] }
    public static func fromMap(_ map: [String: Any]) -> TraceletMotionConfig { TraceletMotionConfig(stopTimeout: map["stopTimeout"] as? Int ?? 5, motionTriggerDelay: map["motionTriggerDelay"] as? Int ?? 0, disableMotionActivityUpdates: map["disableMotionActivityUpdates"] as? Bool ?? false, isMoving: map["isMoving"] as? Bool ?? false, activityRecognitionInterval: map["activityRecognitionInterval"] as? Int ?? 10000, minimumActivityRecognitionConfidence: map["minimumActivityRecognitionConfidence"] as? Int ?? 75, disableStopDetection: map["disableStopDetection"] as? Bool ?? false, stopDetectionDelay: map["stopDetectionDelay"] as? Int ?? 0, stopOnStationary: map["stopOnStationary"] as? Bool ?? false, activityTypes: (map["activityTypes"] as? [String] ?? []).compactMap { TraceletMotionActivityType(rawValue: $0) }) }
}

// MARK: - TraceletGeofenceConfig
public struct TraceletGeofenceConfig {
    public let geofenceModeHighAccuracy: Bool, geofenceInitialTriggerEntry: Bool, geofenceProximityRadius: Int
    public init(geofenceModeHighAccuracy: Bool = false, geofenceInitialTriggerEntry: Bool = true, geofenceProximityRadius: Int = 1000) { self.geofenceModeHighAccuracy = geofenceModeHighAccuracy; self.geofenceInitialTriggerEntry = geofenceInitialTriggerEntry; self.geofenceProximityRadius = geofenceProximityRadius }
    public func toMap() -> [String: Any] { ["geofenceModeHighAccuracy": geofenceModeHighAccuracy, "geofenceInitialTriggerEntry": geofenceInitialTriggerEntry, "geofenceProximityRadius": geofenceProximityRadius] }
    public static func fromMap(_ map: [String: Any]) -> TraceletGeofenceConfig { TraceletGeofenceConfig(geofenceModeHighAccuracy: map["geofenceModeHighAccuracy"] as? Bool ?? false, geofenceInitialTriggerEntry: map["geofenceInitialTriggerEntry"] as? Bool ?? true, geofenceProximityRadius: map["geofenceProximityRadius"] as? Int ?? 1000) }
}

// MARK: - TraceletPersistenceConfig
public struct TraceletPersistenceConfig {
    public let maxDaysToPersist: Int, maxRecordsToPersist: Int, persistMode: TraceletPersistMode
    public init(maxDaysToPersist: Int = 1, maxRecordsToPersist: Int = -1, persistMode: TraceletPersistMode = .all) { self.maxDaysToPersist = maxDaysToPersist; self.maxRecordsToPersist = maxRecordsToPersist; self.persistMode = persistMode }
    public func toMap() -> [String: Any] { ["maxDaysToPersist": maxDaysToPersist, "maxRecordsToPersist": maxRecordsToPersist, "persistMode": persistMode.rawValue] }
    public static func fromMap(_ map: [String: Any]) -> TraceletPersistenceConfig { TraceletPersistenceConfig(maxDaysToPersist: map["maxDaysToPersist"] as? Int ?? 1, maxRecordsToPersist: map["maxRecordsToPersist"] as? Int ?? -1, persistMode: TraceletPersistMode(rawValue: map["persistMode"] as? Int ?? 0) ?? .all) }
}

// MARK: - TraceletAuditConfig
public struct TraceletAuditConfig {
    public let enableAuditTrail: Bool, auditHashAlgorithm: TraceletHashAlgorithm
    public init(enableAuditTrail: Bool = false, auditHashAlgorithm: TraceletHashAlgorithm = .sha256) { self.enableAuditTrail = enableAuditTrail; self.auditHashAlgorithm = auditHashAlgorithm }
    public func toMap() -> [String: Any] { ["enableAuditTrail": enableAuditTrail, "auditHashAlgorithm": auditHashAlgorithm.rawValue] }
    public static func fromMap(_ map: [String: Any]) -> TraceletAuditConfig { TraceletAuditConfig(enableAuditTrail: map["enableAuditTrail"] as? Bool ?? false, auditHashAlgorithm: TraceletHashAlgorithm(rawValue: map["auditHashAlgorithm"] as? Int ?? 0) ?? .sha256) }
}

// MARK: - TraceletPrivacyZoneConfig
public struct TraceletPrivacyZoneConfig {
    public let enablePrivacyZones: Bool
    public init(enablePrivacyZones: Bool = false) { self.enablePrivacyZones = enablePrivacyZones }
    public func toMap() -> [String: Any] { ["enablePrivacyZones": enablePrivacyZones] }
    public static func fromMap(_ map: [String: Any]) -> TraceletPrivacyZoneConfig { TraceletPrivacyZoneConfig(enablePrivacyZones: map["enablePrivacyZones"] as? Bool ?? false) }
}

// MARK: - TraceletSecurityConfig
public struct TraceletSecurityConfig {
    public let encryptDatabase: Bool
    public init(encryptDatabase: Bool = false) { self.encryptDatabase = encryptDatabase }
    public func toMap() -> [String: Any] { ["encryptDatabase": encryptDatabase] }
    public static func fromMap(_ map: [String: Any]) -> TraceletSecurityConfig { TraceletSecurityConfig(encryptDatabase: map["encryptDatabase"] as? Bool ?? false) }
}

// MARK: - TraceletAttestationConfig
public struct TraceletAttestationConfig {
    public let enableDeviceAttestation: Bool, attestationVendor: String?, attestationProject: String?
    public init(enableDeviceAttestation: Bool = false, attestationVendor: String? = nil, attestationProject: String? = nil) { self.enableDeviceAttestation = enableDeviceAttestation; self.attestationVendor = attestationVendor; self.attestationProject = attestationProject }
    public func toMap() -> [String: Any] { var map: [String: Any] = ["enableDeviceAttestation": enableDeviceAttestation]; if let v = attestationVendor { map["attestationVendor"] = v }; if let p = attestationProject { map["attestationProject"] = p }; return map }
    public static func fromMap(_ map: [String: Any]) -> TraceletAttestationConfig { TraceletAttestationConfig(enableDeviceAttestation: map["enableDeviceAttestation"] as? Bool ?? false, attestationVendor: map["attestationVendor"] as? String, attestationProject: map["attestationProject"] as? String) }
}
