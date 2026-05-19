import 'package:meta/meta.dart';
import 'package:tracelet_platform_interface/tracelet_platform_interface.dart';

import '_helpers.dart';
import 'android_config.dart';
import 'ios_config.dart';
import 'attestation_config.dart';
import 'audit_config.dart';
import 'privacy_zone_config.dart';
import 'security_config.dart';

export 'android_config.dart';
export 'ios_config.dart';

/// Top-level compound configuration for Tracelet.
///
/// Organizes settings into logical sub-configs:
/// - [geo] — Shared location accuracy, distance filter, and sampling
/// - [app] — Shared lifecycle behavior, heartbeat, and scheduling
/// - [android] — **Android-only** tuning (foreground service, alarms, intervals)
/// - [ios] — **iOS-only** tuning (activity types, background sessions, suspend protection)
/// - [http] — Server sync settings
/// - [logger] — Logging level and retention
/// - [motion] — Motion detection sensitivity
/// - [geofence] — Geofence proximity and trigger rules
/// - [persistence] — Database retention
/// - [audit] — Tamper-proof location audit trail (Enterprise)
/// - [privacyZone] — Geographic privacy zone controls (Enterprise)
/// - [security] — At-rest database encryption (Enterprise)
/// - [attestation] — Device integrity attestation (Enterprise)
@immutable
class Config {
  /// Creates a new [Config] with optional sub-configs.
  const Config({
    this.geo = const GeoConfig(),
    this.app = const AppConfig(),
    this.android = const AndroidConfig(),
    this.ios = const IosConfig(),
    this.http = const HttpConfig(),
    this.logger = const LoggerConfig(),
    this.motion = const MotionConfig(),
    this.geofence = const GeofenceConfig(),
    this.persistence = const PersistenceConfig(),
    this.audit = const AuditConfig(),
    this.privacyZone = const PrivacyZoneConfig(),
    this.security = const SecurityConfig(),
    this.attestation = const AttestationConfig(),
  });

  /// Shared location accuracy and sampling settings.
  final GeoConfig geo;

  /// Shared application lifecycle and scheduling settings.
  final AppConfig app;

  /// **Android-specific** tuning and foreground service settings.
  final AndroidConfig android;

  /// **iOS-specific** tuning and background session settings.
  final IosConfig ios;

  /// HTTP sync settings.
  final HttpConfig http;

  /// Logger settings.
  final LoggerConfig logger;

  /// Motion detection settings.
  final MotionConfig motion;

  /// Geofencing settings.
  final GeofenceConfig geofence;

  /// Data persistence and database settings.
  final PersistenceConfig persistence;

  /// **Enterprise** — Tamper-proof location audit trail settings.
  final AuditConfig audit;

  /// **Enterprise** — Privacy zone controls.
  final PrivacyZoneConfig privacyZone;

  /// **Enterprise** — At-rest database encryption.
  final SecurityConfig security;

  /// **Enterprise** — Device integrity attestation.
  final AttestationConfig attestation;

  /// Creates a [Config] from a map. Supports both nested and flat formats.
  factory Config.fromMap(Map<String, Object?> map) {
    final geoMap = safeMap(map['geo']);
    final appMap = safeMap(map['app']);
    final androidMap = safeMap(map['android']);
    final iosMap = safeMap(map['ios']);
    final httpMap = safeMap(map['http']);
    final loggerMap = safeMap(map['logger']);
    final motionMap = safeMap(map['motion']);
    final geofenceMap = safeMap(map['geofence']);
    final persistenceMap = safeMap(map['persistence']);
    final auditMap = safeMap(map['audit']);
    final privacyMap = safeMap(map['privacyZone']);
    final securityMap = safeMap(map['security']);
    final attestMap = safeMap(map['attestation']);

    return Config(
      geo: GeoConfig.fromMap(geoMap ?? map),
      app: AppConfig.fromMap(appMap ?? map),
      android: AndroidConfig.fromMap(androidMap ?? map),
      ios: IosConfig.fromMap(iosMap ?? map),
      http: HttpConfig.fromMap(httpMap ?? map),
      logger: LoggerConfig.fromMap(loggerMap ?? map),
      motion: MotionConfig.fromMap(motionMap ?? map),
      geofence: GeofenceConfig.fromMap(geofenceMap ?? map),
      persistence: PersistenceConfig.fromMap(persistenceMap ?? map),
      audit: AuditConfig.fromMap(auditMap ?? map),
      privacyZone: PrivacyZoneConfig.fromMap(privacyMap ?? map),
      security: SecurityConfig.fromMap(securityMap ?? map),
      attestation: AttestationConfig.fromMap(attestMap ?? map),
    );
  }

  /// Converts this [Config] to a Pigeon-generated [TlConfig].
  TlConfig toTlConfig() => TlConfig(
    geo: geo.toTlConfig(),
    app: app.toTlConfig(),
    android: android.toTlConfig(),
    ios: ios.toTlConfig(),
    http: http.toTlConfig(),
    logger: logger.toTlConfig(),
    motion: motion.toTlConfig(),
    geofence: geofence.toTlConfig(),
    persistence: persistence.toTlConfig(),
    audit: audit.toTlConfig(),
    privacyZone: privacyZone.toTlConfig(),
    security: security.toTlConfig(),
    attestation: attestation.toTlConfig(),
  );

  /// Serializes to a nested map suitable for platform channel transmission.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'geo': geo.toMap(),
      'app': app.toMap(),
      'android': android.toMap(),
      'ios': ios.toMap(),
      'http': http.toMap(),
      'logger': logger.toMap(),
      'motion': motion.toMap(),
      'geofence': geofence.toMap(),
      'persistence': persistence.toMap(),
      'audit': audit.toMap(),
      'privacyZone': privacyZone.toMap(),
      'security': security.toMap(),
      'attestation': attestation.toMap(),
    };
  }

  @override
  String toString() =>
      'Config(geo: $geo, app: $app, android: $android, ios: $ios, http: $http, '
      'logger: $logger, motion: $motion, geofence: $geofence, '
      'persistence: $persistence, audit: $audit, privacyZone: $privacyZone, '
      'security: $security, attestation: $attestation)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Config &&
          runtimeType == other.runtimeType &&
          geo == other.geo &&
          app == other.app &&
          android == other.android &&
          ios == other.ios &&
          http == other.http &&
          logger == other.logger &&
          motion == other.motion &&
          geofence == other.geofence &&
          persistence == other.persistence &&
          audit == other.audit &&
          privacyZone == other.privacyZone &&
          security == other.security &&
          attestation == other.attestation;

  @override
  int get hashCode => Object.hashAll([
    geo,
    app,
    android,
    ios,
    http,
    logger,
    motion,
    geofence,
    persistence,
    audit,
    privacyZone,
    security,
    attestation,
  ]);
}

/// GPS filtering and smoothing options.
@immutable
class LocationFilter {
  const LocationFilter({
    this.trackingAccuracyThreshold = 100,
    this.maxImpliedSpeed = 80,
    this.odometerAccuracyThreshold = 50,
    this.policy = LocationFilterPolicy.adjust,
    this.rejectMockLocations = false,
    this.mockDetectionLevel = 1,
    this.useKalmanFilter = false,
  });

  /// Reject locations with accuracy worse than this value (meters).
  final int trackingAccuracyThreshold;

  /// Reject locations that imply a speed greater than this value (m/s).
  final int maxImpliedSpeed;

  /// Only count locations with accuracy better than this value toward odometer.
  final int odometerAccuracyThreshold;

  /// How to handle rejected locations.
  final LocationFilterPolicy policy;

  /// Reject locations flagged as mock by the OS.
  final bool rejectMockLocations;

  /// Sensitivity level for custom mock detection.
  final int mockDetectionLevel;

  /// Whether the Kalman filter is currently enabled for GPS smoothing.
  final bool useKalmanFilter;

  factory LocationFilter.fromMap(Map<String, Object?> map) {
    return LocationFilter(
      trackingAccuracyThreshold: ensureInt(
        map['trackingAccuracyThreshold'],
        fallback: 100,
      ),
      maxImpliedSpeed: ensureInt(map['maxImpliedSpeed'], fallback: 80),
      odometerAccuracyThreshold: ensureInt(
        map['odometerAccuracyThreshold'],
        fallback: 50,
      ),
      policy:
          LocationFilterPolicy.values[ensureInt(
            map['policy'],
            fallback: 0,
          ).clamp(0, LocationFilterPolicy.values.length - 1)],
      rejectMockLocations: ensureBool(
        map['rejectMockLocations'],
        fallback: false,
      ),
      mockDetectionLevel: ensureInt(map['mockDetectionLevel'], fallback: 1),
      useKalmanFilter: ensureBool(map['useKalmanFilter'], fallback: false),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'trackingAccuracyThreshold': trackingAccuracyThreshold,
      'maxImpliedSpeed': maxImpliedSpeed,
      'odometerAccuracyThreshold': odometerAccuracyThreshold,
      'policy': policy.index,
      'rejectMockLocations': rejectMockLocations,
      'mockDetectionLevel': mockDetectionLevel,
      'useKalmanFilter': useKalmanFilter,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationFilter &&
          runtimeType == other.runtimeType &&
          trackingAccuracyThreshold == other.trackingAccuracyThreshold &&
          maxImpliedSpeed == other.maxImpliedSpeed &&
          odometerAccuracyThreshold == other.odometerAccuracyThreshold &&
          policy == other.policy &&
          rejectMockLocations == other.rejectMockLocations &&
          mockDetectionLevel == other.mockDetectionLevel &&
          useKalmanFilter == other.useKalmanFilter;

  @override
  int get hashCode => Object.hash(
    trackingAccuracyThreshold,
    maxImpliedSpeed,
    odometerAccuracyThreshold,
    policy,
    rejectMockLocations,
    mockDetectionLevel,
    useKalmanFilter,
  );
}

/// Shared location accuracy and sampling settings.
@immutable
class GeoConfig {
  const GeoConfig({
    this.desiredAccuracy = DesiredAccuracy.high,
    this.distanceFilter = 10.0,
    this.stationaryRadius = 25.0,
    this.locationTimeout = 60,
    this.disableElasticity = false,
    this.elasticityMultiplier = 1.0,
    this.stopAfterElapsedMinutes = -1,
    this.maxMonitoredGeofences = -1,
    this.enableTimestampMeta = false,
    this.enableAdaptiveMode = false,
    this.periodicLocationInterval = 900,
    this.periodicDesiredAccuracy = DesiredAccuracy.medium,
    this.enableSparseUpdates = false,
    this.sparseDistanceThreshold = 50.0,
    this.sparseMaxIdleSeconds = 300,
    this.batteryBudgetPerHour = 0.0,
    this.enableDeadReckoning = false,
    this.deadReckoningActivationDelay = 0,
    this.deadReckoningMaxDuration = 0,
    this.filter = const LocationFilter(),
  });

  final DesiredAccuracy desiredAccuracy;
  final double distanceFilter;
  final double stationaryRadius;
  final int locationTimeout;
  final bool disableElasticity;
  final double elasticityMultiplier;
  final int stopAfterElapsedMinutes;
  final int maxMonitoredGeofences;
  final bool enableTimestampMeta;
  final bool enableAdaptiveMode;
  final int periodicLocationInterval;
  final DesiredAccuracy periodicDesiredAccuracy;
  final bool enableSparseUpdates;
  final double sparseDistanceThreshold;
  final int sparseMaxIdleSeconds;
  final double batteryBudgetPerHour;
  final bool enableDeadReckoning;
  final int deadReckoningActivationDelay;
  final int deadReckoningMaxDuration;
  final LocationFilter filter;

  factory GeoConfig.fromMap(Map<String, Object?> map) {
    return GeoConfig(
      desiredAccuracy:
          DesiredAccuracy.values[ensureInt(
            map['desiredAccuracy'],
            fallback: 0,
          ).clamp(0, DesiredAccuracy.values.length - 1)],
      distanceFilter: ensureDouble(map['distanceFilter'], fallback: 10.0),
      stationaryRadius: ensureDouble(map['stationaryRadius'], fallback: 25.0),
      locationTimeout: ensureInt(map['locationTimeout'], fallback: 60),
      disableElasticity: ensureBool(map['disableElasticity'], fallback: false),
      elasticityMultiplier: ensureDouble(
        map['elasticityMultiplier'],
        fallback: 1.0,
      ),
      stopAfterElapsedMinutes: ensureInt(
        map['stopAfterElapsedMinutes'],
        fallback: -1,
      ),
      maxMonitoredGeofences: ensureInt(
        map['maxMonitoredGeofences'],
        fallback: -1,
      ),
      enableTimestampMeta: ensureBool(
        map['enableTimestampMeta'],
        fallback: false,
      ),
      enableAdaptiveMode: ensureBool(
        map['enableAdaptiveMode'],
        fallback: false,
      ),
      periodicLocationInterval: ensureInt(
        map['periodicLocationInterval'],
        fallback: 900,
      ),
      periodicDesiredAccuracy:
          DesiredAccuracy.values[ensureInt(
            map['periodicDesiredAccuracy'],
            fallback: 1, // medium
          ).clamp(0, DesiredAccuracy.values.length - 1)],
      enableSparseUpdates: ensureBool(
        map['enableSparseUpdates'],
        fallback: false,
      ),
      sparseDistanceThreshold: ensureDouble(
        map['sparseDistanceThreshold'],
        fallback: 50.0,
      ),
      sparseMaxIdleSeconds: ensureInt(
        map['sparseMaxIdleSeconds'],
        fallback: 300,
      ),
      batteryBudgetPerHour: ensureDouble(
        map['batteryBudgetPerHour'],
        fallback: 0.0,
      ),
      enableDeadReckoning: ensureBool(
        map['enableDeadReckoning'],
        fallback: false,
      ),
      deadReckoningActivationDelay: ensureInt(
        map['deadReckoningActivationDelay'],
        fallback: 0,
      ),
      deadReckoningMaxDuration: ensureInt(
        map['deadReckoningMaxDuration'],
        fallback: 0,
      ),
      filter: LocationFilter.fromMap(safeMap(map['filter']) ?? map),
    );
  }

  /// Converts to Pigeon [TlGeoConfig].
  TlGeoConfig toTlConfig() => TlGeoConfig(
    desiredAccuracy: TlDesiredAccuracy.values[desiredAccuracy.index],
    distanceFilter: distanceFilter,
    stationaryRadius: stationaryRadius,
    locationTimeout: locationTimeout,
    disableElasticity: disableElasticity,
    elasticityMultiplier: elasticityMultiplier,
    stopAfterElapsedMinutes: stopAfterElapsedMinutes,
    maxMonitoredGeofences: maxMonitoredGeofences,
    enableTimestampMeta: enableTimestampMeta,
    enableAdaptiveMode: enableAdaptiveMode,
    periodicLocationInterval: periodicLocationInterval,
    periodicDesiredAccuracy:
        TlDesiredAccuracy.values[periodicDesiredAccuracy.index],
    enableSparseUpdates: enableSparseUpdates,
    sparseDistanceThreshold: sparseDistanceThreshold,
    sparseMaxIdleSeconds: sparseMaxIdleSeconds,
    batteryBudgetPerHour: batteryBudgetPerHour,
    enableDeadReckoning: enableDeadReckoning,
    deadReckoningActivationDelay: deadReckoningActivationDelay,
    deadReckoningMaxDuration: deadReckoningMaxDuration,
  );

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'desiredAccuracy': desiredAccuracy.index,
      'distanceFilter': distanceFilter,
      'stationaryRadius': stationaryRadius,
      'locationTimeout': locationTimeout,
      'disableElasticity': disableElasticity,
      'elasticityMultiplier': elasticityMultiplier,
      'stopAfterElapsedMinutes': stopAfterElapsedMinutes,
      'maxMonitoredGeofences': maxMonitoredGeofences,
      'enableTimestampMeta': enableTimestampMeta,
      'enableAdaptiveMode': enableAdaptiveMode,
      'periodicLocationInterval': periodicLocationInterval,
      'periodicDesiredAccuracy': periodicDesiredAccuracy.index,
      'enableSparseUpdates': enableSparseUpdates,
      'sparseDistanceThreshold': sparseDistanceThreshold,
      'sparseMaxIdleSeconds': sparseMaxIdleSeconds,
      'batteryBudgetPerHour': batteryBudgetPerHour,
      'enableDeadReckoning': enableDeadReckoning,
      'deadReckoningActivationDelay': deadReckoningActivationDelay,
      'deadReckoningMaxDuration': deadReckoningMaxDuration,
      'filter': filter.toMap(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoConfig &&
          runtimeType == other.runtimeType &&
          desiredAccuracy == other.desiredAccuracy &&
          distanceFilter == other.distanceFilter &&
          stationaryRadius == other.stationaryRadius &&
          locationTimeout == other.locationTimeout &&
          disableElasticity == other.disableElasticity &&
          elasticityMultiplier == other.elasticityMultiplier &&
          stopAfterElapsedMinutes == other.stopAfterElapsedMinutes &&
          maxMonitoredGeofences == other.maxMonitoredGeofences &&
          enableTimestampMeta == other.enableTimestampMeta &&
          enableAdaptiveMode == other.enableAdaptiveMode &&
          periodicLocationInterval == other.periodicLocationInterval &&
          periodicDesiredAccuracy == other.periodicDesiredAccuracy &&
          enableSparseUpdates == other.enableSparseUpdates &&
          sparseDistanceThreshold == other.sparseDistanceThreshold &&
          sparseMaxIdleSeconds == other.sparseMaxIdleSeconds &&
          batteryBudgetPerHour == other.batteryBudgetPerHour &&
          enableDeadReckoning == other.enableDeadReckoning &&
          deadReckoningActivationDelay == other.deadReckoningActivationDelay &&
          deadReckoningMaxDuration == other.deadReckoningMaxDuration &&
          filter == other.filter;

  @override
  int get hashCode => Object.hashAll([
    desiredAccuracy,
    distanceFilter,
    stationaryRadius,
    locationTimeout,
    disableElasticity,
    elasticityMultiplier,
    stopAfterElapsedMinutes,
    maxMonitoredGeofences,
    enableTimestampMeta,
    enableAdaptiveMode,
    periodicLocationInterval,
    periodicDesiredAccuracy,
    enableSparseUpdates,
    sparseDistanceThreshold,
    sparseMaxIdleSeconds,
    batteryBudgetPerHour,
    enableDeadReckoning,
    deadReckoningActivationDelay,
    deadReckoningMaxDuration,
    filter,
  ]);
}

/// Shared application lifecycle and scheduling settings.
@immutable
class AppConfig {
  const AppConfig({
    this.stopOnTerminate = true,
    this.startOnBoot = false,
    this.heartbeatInterval = 60,
    this.schedule = const <String>[],
    this.remoteConfigUrl,
    this.remoteConfigHeaders,
    this.remoteConfigTimeout = 60000,
    this.remoteConfigRefreshInterval = 1440,
  });

  final bool stopOnTerminate;
  final bool startOnBoot;
  final int heartbeatInterval;
  final List<String> schedule;
  final String? remoteConfigUrl;
  final Map<String, String>? remoteConfigHeaders;
  final int remoteConfigTimeout;
  final int remoteConfigRefreshInterval;

  factory AppConfig.fromMap(Map<String, Object?> map) {
    final rawSchedule = map['schedule'];
    final scheduleList = <String>[];
    if (rawSchedule is List) {
      for (final item in rawSchedule) {
        if (item is String) scheduleList.add(item);
      }
    }
    return AppConfig(
      stopOnTerminate: ensureBool(map['stopOnTerminate'], fallback: true),
      startOnBoot: ensureBool(map['startOnBoot'], fallback: false),
      heartbeatInterval: ensureInt(map['heartbeatInterval'], fallback: 60),
      schedule: scheduleList,
      remoteConfigUrl: map['remoteConfigUrl'] as String?,
      remoteConfigHeaders: (map['remoteConfigHeaders'] as Map?)
          ?.cast<String, String>(),
      remoteConfigTimeout: ensureInt(
        map['remoteConfigTimeout'],
        fallback: 60000,
      ),
      remoteConfigRefreshInterval: ensureInt(
        map['remoteConfigRefreshInterval'],
        fallback: 1440,
      ),
    );
  }

  /// Converts to Pigeon [TlAppConfig].
  TlAppConfig toTlConfig() => TlAppConfig(
    stopOnTerminate: stopOnTerminate,
    startOnBoot: startOnBoot,
    heartbeatInterval: heartbeatInterval,
    schedule: schedule,
    remoteConfigUrl: remoteConfigUrl,
    remoteConfigHeaders: remoteConfigHeaders,
    remoteConfigTimeout: remoteConfigTimeout,
    remoteConfigRefreshInterval: remoteConfigRefreshInterval,
  );

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'stopOnTerminate': stopOnTerminate,
      'startOnBoot': startOnBoot,
      'heartbeatInterval': heartbeatInterval,
      'schedule': schedule,
      'remoteConfigUrl': remoteConfigUrl,
      'remoteConfigHeaders': remoteConfigHeaders,
      'remoteConfigTimeout': remoteConfigTimeout,
      'remoteConfigRefreshInterval': remoteConfigRefreshInterval,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppConfig &&
          runtimeType == other.runtimeType &&
          stopOnTerminate == other.stopOnTerminate &&
          startOnBoot == other.startOnBoot &&
          heartbeatInterval == other.heartbeatInterval &&
          schedule == other.schedule &&
          remoteConfigUrl == other.remoteConfigUrl &&
          remoteConfigHeaders == other.remoteConfigHeaders &&
          remoteConfigTimeout == other.remoteConfigTimeout &&
          remoteConfigRefreshInterval == other.remoteConfigRefreshInterval;

  @override
  int get hashCode => Object.hash(
    stopOnTerminate,
    startOnBoot,
    heartbeatInterval,
    schedule,
    remoteConfigUrl,
    remoteConfigHeaders,
    remoteConfigTimeout,
    remoteConfigRefreshInterval,
  );
}

/// HTTP sync settings.
@immutable
class HttpConfig {
  const HttpConfig({
    this.url,
    this.method = HttpMethod.post,
    this.headers,
    this.params,
    this.autoSync = true,
    this.batchSync = false,
    this.maxBatchSize = 250,
    this.autoSyncThreshold = 0,
    this.httpTimeout = 60000,
    this.locationsOrderDirection = LocationOrderDirection.ascending,
    this.disableAutoSyncOnCellular = false,
    this.maxRetries = 3,
    this.retryBackoffBase = 1,
    this.retryBackoffCap = 60,
    this.enableDeltaCompression = false,
    this.deltaCoordinatePrecision = 5,
  });

  final String? url;
  final HttpMethod method;
  final Map<String, String>? headers;
  final Map<String, Object?>? params;
  final bool autoSync;
  final bool batchSync;
  final int maxBatchSize;
  final int autoSyncThreshold;
  final int httpTimeout;
  final LocationOrderDirection locationsOrderDirection;
  final bool disableAutoSyncOnCellular;
  final int maxRetries;
  final int retryBackoffBase;
  final int retryBackoffCap;
  final bool enableDeltaCompression;
  final int deltaCoordinatePrecision;

  factory HttpConfig.fromMap(Map<String, Object?> map) {
    return HttpConfig(
      url: map['url'] as String?,
      method:
          HttpMethod.values[ensureInt(
            map['method'],
            fallback: 0,
          ).clamp(0, HttpMethod.values.length - 1)],
      headers: (map['headers'] as Map?)?.cast<String, String>(),
      params: (map['params'] as Map?)?.cast<String, Object?>(),
      autoSync: ensureBool(map['autoSync'], fallback: true),
      batchSync: ensureBool(map['batchSync'], fallback: false),
      maxBatchSize: ensureInt(map['maxBatchSize'], fallback: 250),
      autoSyncThreshold: ensureInt(map['autoSyncThreshold'], fallback: 0),
      httpTimeout: ensureInt(map['httpTimeout'], fallback: 60000),
      locationsOrderDirection:
          LocationOrderDirection.values[ensureInt(
            map['locationsOrderDirection'],
            fallback: 0,
          ).clamp(0, LocationOrderDirection.values.length - 1)],
      disableAutoSyncOnCellular: ensureBool(
        map['disableAutoSyncOnCellular'],
        fallback: false,
      ),
      maxRetries: ensureInt(map['maxRetries'], fallback: 3),
      retryBackoffBase: ensureInt(map['retryBackoffBase'], fallback: 1),
      retryBackoffCap: ensureInt(map['retryBackoffCap'], fallback: 60),
      enableDeltaCompression: ensureBool(
        map['enableDeltaCompression'],
        fallback: false,
      ),
      deltaCoordinatePrecision: ensureInt(
        map['deltaCoordinatePrecision'],
        fallback: 5,
      ),
    );
  }

  /// Converts to Pigeon [TlHttpConfig].
  TlHttpConfig toTlConfig() => TlHttpConfig(
    url: url,
    method: TlHttpMethod.values[method.index],
    headers: headers,
    params: params,
    autoSync: autoSync,
    batchSync: batchSync,
    maxBatchSize: maxBatchSize,
    autoSyncThreshold: autoSyncThreshold,
    httpTimeout: httpTimeout,
    locationsOrderDirection:
        TlLocationOrderDirection.values[locationsOrderDirection.index],
    disableAutoSyncOnCellular: disableAutoSyncOnCellular,
    maxRetries: maxRetries,
    retryBackoffBase: retryBackoffBase,
    retryBackoffCap: retryBackoffCap,
    enableDeltaCompression: enableDeltaCompression,
    deltaCoordinatePrecision: deltaCoordinatePrecision,
  );

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'url': url,
      'method': method.index,
      'headers': headers,
      'params': params,
      'autoSync': autoSync,
      'batchSync': batchSync,
      'maxBatchSize': maxBatchSize,
      'autoSyncThreshold': autoSyncThreshold,
      'httpTimeout': httpTimeout,
      'locationsOrderDirection': locationsOrderDirection.index,
      'disableAutoSyncOnCellular': disableAutoSyncOnCellular,
      'maxRetries': maxRetries,
      'retryBackoffBase': retryBackoffBase,
      'retryBackoffCap': retryBackoffCap,
      'enableDeltaCompression': enableDeltaCompression,
      'deltaCoordinatePrecision': deltaCoordinatePrecision,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HttpConfig &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          method == other.method &&
          headers == other.headers &&
          params == other.params &&
          autoSync == other.autoSync &&
          batchSync == other.batchSync &&
          maxBatchSize == other.maxBatchSize &&
          autoSyncThreshold == other.autoSyncThreshold &&
          httpTimeout == other.httpTimeout &&
          locationsOrderDirection == other.locationsOrderDirection &&
          disableAutoSyncOnCellular == other.disableAutoSyncOnCellular &&
          maxRetries == other.maxRetries &&
          retryBackoffBase == other.retryBackoffBase &&
          retryBackoffCap == other.retryBackoffCap &&
          enableDeltaCompression == other.enableDeltaCompression &&
          deltaCoordinatePrecision == other.deltaCoordinatePrecision;

  @override
  int get hashCode => Object.hash(
    url,
    method,
    headers,
    params,
    autoSync,
    batchSync,
    maxBatchSize,
    autoSyncThreshold,
    httpTimeout,
    locationsOrderDirection,
    disableAutoSyncOnCellular,
    maxRetries,
    retryBackoffBase,
    retryBackoffCap,
    enableDeltaCompression,
    deltaCoordinatePrecision,
  );
}

// NOTE: Sub-configs like LoggerConfig, MotionConfig, etc. are omitted for brevity
// but would follow the same pattern (fromMap, toMap, and ideally toTlConfig if needed).
// For now, only the core configs are mapped to TlConfig in Pigeon.

@immutable
class LoggerConfig {
  const LoggerConfig({
    this.logLevel = LogLevel.info,
    this.logMaxDays = 3,
    this.debug = false,
  });

  final LogLevel logLevel;
  final int logMaxDays;
  final bool debug;

  factory LoggerConfig.fromMap(Map<String, Object?> map) {
    return LoggerConfig(
      logLevel:
          LogLevel.values[ensureInt(
            map['logLevel'],
            fallback: 2,
          ).clamp(0, LogLevel.values.length - 1)],
      logMaxDays: ensureInt(map['logMaxDays'], fallback: 3),
      debug: ensureBool(map['debug'], fallback: false),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'logLevel': logLevel.index,
      'logMaxDays': logMaxDays,
      'debug': debug,
    };
  }

  TlLoggerConfig toTlConfig() => TlLoggerConfig(
    logLevel: TlLogLevel.values[logLevel.index],
    logMaxDays: logMaxDays,
    debug: debug,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoggerConfig &&
          runtimeType == other.runtimeType &&
          logLevel == other.logLevel &&
          logMaxDays == other.logMaxDays &&
          debug == other.debug;

  @override
  int get hashCode => Object.hash(logLevel, logMaxDays, debug);
}

@immutable
class MotionConfig {
  const MotionConfig({
    this.stopTimeout = 5,
    this.motionTriggerDelay = 0,
    this.disableMotionActivityUpdates = false,
    this.isMoving = false,
    this.activityRecognitionInterval = 1000,
    this.minimumActivityRecognitionConfidence = 75,
    this.disableStopDetection = false,
    this.stopDetectionDelay = 0,
    this.stopOnStationary = false,
    this.activityTypes,
    this.stationaryRadius = 25.0,
    this.useSignificantChangesOnly = false,
    this.shakeThreshold = 2.5,
    this.stillThreshold = 0.4,
    this.stillSampleCount = 25,
  });

  final int stopTimeout;
  final int motionTriggerDelay;
  final bool disableMotionActivityUpdates;
  final bool isMoving;
  final int activityRecognitionInterval;
  final int minimumActivityRecognitionConfidence;
  final bool disableStopDetection;
  final int stopDetectionDelay;
  final bool stopOnStationary;
  final List<LocationActivityType>? activityTypes;
  final double stationaryRadius;
  final bool useSignificantChangesOnly;
  final double shakeThreshold;
  final double stillThreshold;
  final int stillSampleCount;

  factory MotionConfig.fromMap(Map<String, Object?> map) {
    // Parse activityTypes from the map if present.
    final rawActivityTypes = map['activityTypes'];
    List<LocationActivityType>? activityTypesList;
    if (rawActivityTypes is List) {
      activityTypesList = <LocationActivityType>[];
      for (final item in rawActivityTypes) {
        final index = item is int ? item : int.tryParse(item.toString());
        if (index != null &&
            index >= 0 &&
            index < LocationActivityType.values.length) {
          activityTypesList.add(LocationActivityType.values[index]);
        }
      }
      if (activityTypesList.isEmpty) activityTypesList = null;
    }
    return MotionConfig(
      stopTimeout: ensureInt(map['stopTimeout'], fallback: 5),
      motionTriggerDelay: ensureInt(map['motionTriggerDelay'], fallback: 0),
      disableMotionActivityUpdates: ensureBool(
        map['disableMotionActivityUpdates'],
        fallback: false,
      ),
      isMoving: ensureBool(map['isMoving'], fallback: false),
      activityRecognitionInterval: ensureInt(
        map['activityRecognitionInterval'],
        fallback: 1000,
      ),
      minimumActivityRecognitionConfidence: ensureInt(
        map['minimumActivityRecognitionConfidence'],
        fallback: 75,
      ),
      disableStopDetection: ensureBool(
        map['disableStopDetection'],
        fallback: false,
      ),
      stopDetectionDelay: ensureInt(map['stopDetectionDelay'], fallback: 0),
      stopOnStationary: ensureBool(map['stopOnStationary'], fallback: false),
      activityTypes: activityTypesList,
      stationaryRadius: ensureDouble(map['stationaryRadius'], fallback: 25.0),
      useSignificantChangesOnly: ensureBool(
        map['useSignificantChangesOnly'],
        fallback: false,
      ),
      shakeThreshold: ensureDouble(map['shakeThreshold'], fallback: 2.5),
      stillThreshold: ensureDouble(map['stillThreshold'], fallback: 0.4),
      stillSampleCount: ensureInt(map['stillSampleCount'], fallback: 25),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'stopTimeout': stopTimeout,
      'motionTriggerDelay': motionTriggerDelay,
      'disableMotionActivityUpdates': disableMotionActivityUpdates,
      'isMoving': isMoving,
      'activityRecognitionInterval': activityRecognitionInterval,
      'minimumActivityRecognitionConfidence':
          minimumActivityRecognitionConfidence,
      'disableStopDetection': disableStopDetection,
      'stopDetectionDelay': stopDetectionDelay,
      'stopOnStationary': stopOnStationary,
      if (activityTypes != null)
        'activityTypes': activityTypes!.map((e) => e.index).toList(),
      'stationaryRadius': stationaryRadius,
      'useSignificantChangesOnly': useSignificantChangesOnly,
      'shakeThreshold': shakeThreshold,
      'stillThreshold': stillThreshold,
      'stillSampleCount': stillSampleCount,
    };
  }

  TlMotionConfig toTlConfig() => TlMotionConfig(
    stopTimeout: stopTimeout,
    motionTriggerDelay: motionTriggerDelay,
    disableMotionActivityUpdates: disableMotionActivityUpdates,
    isMoving: isMoving,
    activityRecognitionInterval: activityRecognitionInterval,
    minimumActivityRecognitionConfidence: minimumActivityRecognitionConfidence,
    disableStopDetection: disableStopDetection,
    stopDetectionDelay: stopDetectionDelay,
    stopOnStationary: stopOnStationary,
    stationaryRadius: stationaryRadius,
    useSignificantChangesOnly: useSignificantChangesOnly,
    shakeThreshold: shakeThreshold,
    stillThreshold: stillThreshold,
    stillSampleCount: stillSampleCount,
    activityTypes: activityTypes
        ?.map((e) => TlLocationActivityType.values[e.index])
        .toList(),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MotionConfig &&
          runtimeType == other.runtimeType &&
          stopTimeout == other.stopTimeout &&
          motionTriggerDelay == other.motionTriggerDelay &&
          disableMotionActivityUpdates == other.disableMotionActivityUpdates &&
          isMoving == other.isMoving &&
          activityRecognitionInterval == other.activityRecognitionInterval &&
          minimumActivityRecognitionConfidence ==
              other.minimumActivityRecognitionConfidence &&
          disableStopDetection == other.disableStopDetection &&
          stopDetectionDelay == other.stopDetectionDelay &&
          stopOnStationary == other.stopOnStationary &&
          activityTypes == other.activityTypes &&
          stationaryRadius == other.stationaryRadius &&
          useSignificantChangesOnly == other.useSignificantChangesOnly &&
          shakeThreshold == other.shakeThreshold &&
          stillThreshold == other.stillThreshold &&
          stillSampleCount == other.stillSampleCount;

  @override
  int get hashCode => Object.hash(
    stopTimeout,
    motionTriggerDelay,
    disableMotionActivityUpdates,
    isMoving,
    activityRecognitionInterval,
    minimumActivityRecognitionConfidence,
    disableStopDetection,
    stopDetectionDelay,
    stopOnStationary,
    activityTypes,
    stationaryRadius,
    useSignificantChangesOnly,
    shakeThreshold,
    stillThreshold,
    stillSampleCount,
  );
}

@immutable
class GeofenceConfig {
  const GeofenceConfig({
    this.geofenceModeHighAccuracy = false,
    this.geofenceInitialTriggerEntry = true,
    this.geofenceProximityRadius = 1000,
  });

  final bool geofenceModeHighAccuracy;
  final bool geofenceInitialTriggerEntry;
  final int geofenceProximityRadius;

  factory GeofenceConfig.fromMap(Map<String, Object?> map) {
    return GeofenceConfig(
      geofenceModeHighAccuracy: ensureBool(
        map['geofenceModeHighAccuracy'],
        fallback: false,
      ),
      geofenceInitialTriggerEntry: ensureBool(
        map['geofenceInitialTriggerEntry'],
        fallback: true,
      ),
      geofenceProximityRadius: ensureInt(
        map['geofenceProximityRadius'],
        fallback: 1000,
      ),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'geofenceModeHighAccuracy': geofenceModeHighAccuracy,
      'geofenceInitialTriggerEntry': geofenceInitialTriggerEntry,
      'geofenceProximityRadius': geofenceProximityRadius,
    };
  }

  TlGeofenceConfig toTlConfig() => TlGeofenceConfig(
    geofenceModeHighAccuracy: geofenceModeHighAccuracy,
    geofenceInitialTriggerEntry: geofenceInitialTriggerEntry,
    geofenceProximityRadius: geofenceProximityRadius,
    geofenceInitialTrigger: true,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeofenceConfig &&
          runtimeType == other.runtimeType &&
          geofenceModeHighAccuracy == other.geofenceModeHighAccuracy &&
          geofenceInitialTriggerEntry == other.geofenceInitialTriggerEntry &&
          geofenceProximityRadius == other.geofenceProximityRadius;

  @override
  int get hashCode => Object.hash(
    geofenceModeHighAccuracy,
    geofenceInitialTriggerEntry,
    geofenceProximityRadius,
  );
}

@immutable
class PersistenceConfig {
  const PersistenceConfig({
    this.maxDaysToPersist = 1,
    this.maxRecordsToPersist = -1,
    this.persistMode = PersistMode.all,
    this.disableProviderChangeRecord = false,
  });

  final int maxDaysToPersist;
  final int maxRecordsToPersist;
  final PersistMode persistMode;
  final bool disableProviderChangeRecord;

  factory PersistenceConfig.fromMap(Map<String, Object?> map) {
    return PersistenceConfig(
      maxDaysToPersist: ensureInt(map['maxDaysToPersist'], fallback: 1),
      maxRecordsToPersist: ensureInt(map['maxRecordsToPersist'], fallback: -1),
      persistMode:
          PersistMode.values[ensureInt(
            map['persistMode'],
            fallback: 0,
          ).clamp(0, PersistMode.values.length - 1)],
      disableProviderChangeRecord: ensureBool(
        map['disableProviderChangeRecord'],
        fallback: false,
      ),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'maxDaysToPersist': maxDaysToPersist,
      'maxRecordsToPersist': maxRecordsToPersist,
      'persistMode': persistMode.index,
      'disableProviderChangeRecord': disableProviderChangeRecord,
    };
  }

  TlPersistenceConfig toTlConfig() => TlPersistenceConfig(
    persistMode: TlPersistMode.values[persistMode.index],
    maxDaysToPersist: maxDaysToPersist,
    maxRecordsToPersist: maxRecordsToPersist,
    disableProviderChangeRecord: disableProviderChangeRecord,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersistenceConfig &&
          runtimeType == other.runtimeType &&
          maxDaysToPersist == other.maxDaysToPersist &&
          maxRecordsToPersist == other.maxRecordsToPersist &&
          persistMode == other.persistMode &&
          disableProviderChangeRecord == other.disableProviderChangeRecord;

  @override
  int get hashCode => Object.hash(
    maxDaysToPersist,
    maxRecordsToPersist,
    persistMode,
    disableProviderChangeRecord,
  );
}
