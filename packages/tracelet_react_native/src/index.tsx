// @ikolvi/tracelet — Production-grade background geolocation for React Native.
// Mirrors the Tracelet Dart public API, backed by the shared native SDKs + Rust core.

export { Tracelet } from './Tracelet';
export type { Subscription } from './events';

// Config types
export type {
  Config,
  GeoConfig,
  AppConfig,
  HttpConfig,
  LoggerConfig,
  MotionConfig,
  GeofenceConfig,
  PersistenceConfig,
  AndroidConfig,
  ForegroundServiceConfig,
  IosConfig,
  LiveActivityConfig,
  AuditConfig,
  PrivacyZoneConfig,
  SecurityConfig,
  AttestationConfig,
  TelematicsConfig,
  ClassifierConfig,
  ImpactConfig,
  LocationFilter,
} from './types/Config';

// Location / model types
export type {
  Location,
  Coords,
  LocationActivity,
  LocationBattery,
  Address,
  CurrentPositionOptions,
  LastKnownLocationOptions,
  WatchPositionOptions,
  SQLQuery,
} from './types/Location';
export type { Geofence } from './types/Geofence';
export type { State } from './types/State';
export type { PrivacyZone, RouteContext } from './types/Privacy';
export type {
  TelematicsRecord,
  SimulateTelematicsOptions,
  CrashModelInferenceOptions,
} from './types/Telematics';
export type {
  AuditVerification,
  AuditProof,
  AttestationToken,
  ComplianceReport,
} from './types/Audit';
export type {
  Sensors,
  DeviceInfo,
  LogEntry,
  HealthCheck,
} from './types/Health';
export type {
  SyncBodyContext,
  SyncBodyBuilder,
  HeadersCallback,
} from './types/Sync';

// Event types
export type {
  ActivityChangeEvent,
  ProviderChangeEvent,
  GeofenceEvent,
  GeofencesChangeEvent,
  HeartbeatEvent,
  HttpEvent,
  SpeedMotionEvent,
  ConnectivityChangeEvent,
  AuthorizationEvent,
  DrivingEvent,
  ImpactEvent,
  ModeChangeEvent,
  CrashModelStatusEvent,
  TripEvent,
  BudgetAdjustmentEvent,
  HeadlessEvent,
} from './types/Events';

// Enums
export {
  DesiredAccuracy,
  TrackingMode,
  MotionDetectionMode,
  StationaryTrackingMode,
  AuthorizationStatus,
  MotionAuthorizationStatus,
  NotificationAuthorizationStatus,
  AccuracyAuthorization,
  FullAccuracyStatus,
  GeofenceAction,
  PrivacyZoneAction,
  HttpMethod,
  LocationOrderDirection,
  LocationFilterPolicy,
  LogLevel,
  PersistMode,
  HashAlgorithm,
  AttestationProvider,
  LocationActivityType,
  CrashModelStatus,
  NotificationPriority,
} from './types/Enums';

// Errors
export { TraceletError } from './types/Errors';

// Hooks
export { useLocation } from './hooks/useLocation';
export { useTraceletState } from './hooks/useTraceletState';
export { useGeofences } from './hooks/useGeofences';
