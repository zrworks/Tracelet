import type {
  DesiredAccuracy,
  MotionDetectionMode,
  StationaryTrackingMode,
  HttpMethod,
  LocationOrderDirection,
  LocationFilterPolicy,
  LogLevel,
  PersistMode,
  HashAlgorithm,
  PrivacyZoneAction,
  AttestationProvider,
  LocationActivityType,
} from './Enums';

/** GPS filtering / smoothing options. */
export interface LocationFilter {
  trackingAccuracyThreshold?: number;
  maxImpliedSpeed?: number;
  odometerAccuracyThreshold?: number;
  policy?: LocationFilterPolicy;
  rejectMockLocations?: boolean;
  /** 0 = disabled, 1 = basic, 2 = heuristic. */
  mockDetectionLevel?: number;
  /** Enable the Extended Kalman Filter. */
  useKalmanFilter?: boolean;
}

/** Location engine & accuracy configuration. */
export interface GeoConfig {
  desiredAccuracy?: DesiredAccuracy;
  distanceFilter?: number;
  stationaryRadius?: number;
  locationTimeout?: number;
  disableElasticity?: boolean;
  elasticityMultiplier?: number;
  stopAfterElapsedMinutes?: number;
  maxMonitoredGeofences?: number;
  enableTimestampMeta?: boolean;
  enableAdaptiveMode?: boolean;
  periodicLocationInterval?: number;
  periodicDesiredAccuracy?: DesiredAccuracy;
  enableSparseUpdates?: boolean;
  sparseDistanceThreshold?: number;
  sparseMaxIdleSeconds?: number;
  /** Battery-budget mode target, in %/hour. */
  batteryBudgetPerHour?: number;
  enableDeadReckoning?: boolean;
  deadReckoningActivationDelay?: number;
  deadReckoningMaxDuration?: number;
  filter?: LocationFilter;
  /** Reverse-geocode each fix into an Address. */
  resolveAddress?: boolean;
}

/** App lifecycle & remote-config scheduling. */
export interface AppConfig {
  stopOnTerminate?: boolean;
  startOnBoot?: boolean;
  heartbeatInterval?: number;
  schedule?: string[];
  remoteConfigUrl?: string;
  remoteConfigHeaders?: Record<string, string>;
  remoteConfigTimeout?: number;
  remoteConfigRefreshInterval?: number;
}

/** HTTP sync configuration. */
export interface HttpConfig {
  url?: string;
  method?: HttpMethod;
  headers?: Record<string, string>;
  params?: Record<string, unknown>;
  extras?: Record<string, unknown>;
  httpRootProperty?: string;
  autoSync?: boolean;
  batchSync?: boolean;
  maxBatchSize?: number;
  autoSyncThreshold?: number;
  autoSyncDelay?: number;
  syncInterval?: number;
  httpTimeout?: number;
  locationsOrderDirection?: LocationOrderDirection;
  disableAutoSyncOnCellular?: boolean;
  maxRetries?: number;
  retryBackoffBase?: number;
  retryBackoffCap?: number;
  enableDeltaCompression?: boolean;
  deltaCoordinatePrecision?: number;
  sslPinningFingerprints?: string[];
  sslPinningCertificates?: string[];
  syncTelematics?: boolean;
  telematicsUrl?: string;
}

/** Logger configuration. */
export interface LoggerConfig {
  logLevel?: LogLevel;
  logMaxDays?: number;
  debug?: boolean;
}

/** Motion / activity detection configuration. */
export interface MotionConfig {
  stopTimeout?: number;
  motionTriggerDelay?: number;
  /** Accelerometer-only fallback (no Activity-Recognition permission needed). */
  disableMotionActivityUpdates?: boolean;
  isMoving?: boolean;
  activityRecognitionInterval?: number;
  minimumActivityRecognitionConfidence?: number;
  disableStopDetection?: boolean;
  stopDetectionDelay?: number;
  stopOnStationary?: boolean;
  activityTypes?: LocationActivityType[];
  stationaryRadius?: number;
  useSignificantChangesOnly?: boolean;
  shakeThreshold?: number;
  stillThreshold?: number;
  stillSampleCount?: number;
  motionDetectionMode?: MotionDetectionMode;
  speedMovingThreshold?: number;
  speedStationaryDelay?: number;
  stationaryTrackingMode?: StationaryTrackingMode;
  stationaryPeriodicInterval?: number;
  stationaryPeriodicAccuracy?: DesiredAccuracy;
  speedWakeConfirmCount?: number;
}

/** Geofence transition defaults. */
export interface GeofenceConfig {
  proximity?: number;
  notifyOnEntry?: boolean;
  notifyOnExit?: boolean;
  notifyOnDwell?: boolean;
  loiteringDelay?: number;
}

/** Database persistence/retention configuration. */
export interface PersistenceConfig {
  maxDaysToPersist?: number;
  maxRecordsToPersist?: number;
  persistMode?: PersistMode;
}

/** Android foreground-service notification configuration. */
export interface ForegroundServiceConfig {
  title?: string;
  text?: string;
  largeIcon?: string;
  smallIcon?: string;
  color?: string;
  enableWhenLocked?: boolean;
  notificationId?: number;
}

/** Android-specific configuration. */
export interface AndroidConfig {
  locationUpdateInterval?: number;
  fastestLocationUpdateInterval?: number;
  deferTime?: number;
  geofenceModeHighAccuracy?: boolean;
  foregroundService?: ForegroundServiceConfig;
  periodicUseForegroundService?: boolean;
  periodicUseExactAlarms?: boolean;
}

/** iOS Live Activity (iOS 16.1+) configuration. */
export interface LiveActivityConfig {
  enabled?: boolean;
  title?: string;
}

/** iOS-specific configuration. */
export interface IosConfig {
  pausesLocationUpdatesAutomatically?: boolean;
  activityTypes?: string[];
  showsBackgroundLocationIndicator?: boolean;
  supportsBackgroundLocationUpdates?: boolean;
  liveActivity?: LiveActivityConfig;
}

/** Enterprise: tamper-evident audit trail. */
export interface AuditConfig {
  enabled?: boolean;
  algorithm?: HashAlgorithm;
}

/** Enterprise: privacy-zone behaviour. */
export interface PrivacyZoneConfig {
  enabled?: boolean;
  action?: PrivacyZoneAction;
  degradedAccuracyMeters?: number;
}

/** Enterprise: at-rest database encryption. */
export interface SecurityConfig {
  enabled?: boolean;
  passphrase?: string;
}

/** Enterprise: device attestation. */
export interface AttestationConfig {
  enabled?: boolean;
  provider?: AttestationProvider;
}

/** Driving-behaviour / telematics configuration. */
export interface TelematicsConfig {
  enableDrivingEvents?: boolean;
  enableCrashDetection?: boolean;
  enableFallDetection?: boolean;
  speedThreshold?: number;
  harshAccelerationThreshold?: number;
  harshBrakingThreshold?: number;
  harshCorneringThreshold?: number;
}

/** Transport-mode classifier configuration. */
export interface ClassifierConfig {
  enableFusedClassifier?: boolean;
}

/** Crash & fall detection configuration. */
export interface ImpactConfig {
  enableCrashDetection?: boolean;
  enableFallDetection?: boolean;
  useMlModel?: boolean;
  confirmationWindow?: number;
  autoConfirmAfterTimeout?: boolean;
  /** Optional URL used to unlock the encrypted AI crash model. */
  crashModelUnlockUrl?: string;
  /** Optional license key for the AI crash model. */
  crashModelLicenseKey?: string;
  /** Decision threshold for the ML crash model (0..1). */
  crashModelThreshold?: number;
}

/** Root configuration object passed to {@link Tracelet.ready}. */
export interface Config {
  geo?: GeoConfig;
  app?: AppConfig;
  android?: AndroidConfig;
  ios?: IosConfig;
  http?: HttpConfig;
  logger?: LoggerConfig;
  motion?: MotionConfig;
  geofence?: GeofenceConfig;
  persistence?: PersistenceConfig;
  audit?: AuditConfig;
  privacyZone?: PrivacyZoneConfig;
  security?: SecurityConfig;
  attestation?: AttestationConfig;
  telematics?: TelematicsConfig;
  classifier?: ClassifierConfig;
  impact?: ImpactConfig;
}
