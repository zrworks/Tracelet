// Enums mirroring the Tracelet Dart public API.
// Numeric values match the native SDK / Pigeon contract where the Dart enum is index-based.

/** Desired location accuracy. Lower battery as the value increases. */
export enum DesiredAccuracy {
  high = 0,
  medium = 1,
  low = 2,
  veryLow = 3,
  passive = 4,
}

/** Active tracking mode reported in {@link State}. */
export enum TrackingMode {
  location = 'location',
  geofence = 'geofence',
  periodic = 'periodic',
  none = 'none',
}

/** How motion (moving vs. stationary) is detected. */
export enum MotionDetectionMode {
  accelerometer = 'accelerometer',
  activityRecognition = 'activityRecognition',
  speed = 'speed',
}

/** What the tracker does while stationary. */
export enum StationaryTrackingMode {
  periodic = 'periodic',
  geofence = 'geofence',
  none = 'none',
}

/** Location permission authorization status. */
export enum AuthorizationStatus {
  notDetermined = 0,
  whenInUse = 1,
  denied = 2,
  always = 3,
  deniedForever = 4,
}

/** Motion & Fitness / Activity Recognition permission status. */
export enum MotionAuthorizationStatus {
  authorized = 0,
  denied = 1,
  restricted = 2,
  notDetermined = 3,
}

/** Notification permission status. */
export enum NotificationAuthorizationStatus {
  authorized = 'authorized',
  provisional = 'provisional',
  denied = 'denied',
  ephemeral = 'ephemeral',
}

/** iOS accuracy authorization (full vs. reduced). */
export enum AccuracyAuthorization {
  full = 'full',
  reduced = 'reduced',
}

/** Result of requesting temporary full accuracy (iOS 14+). */
export enum FullAccuracyStatus {
  fullAccuracyGranted = 0,
  fullAccuracyDenied = 1,
  notDetermined = 2,
}

/** Geofence transition type. */
export enum GeofenceAction {
  enter = 'enter',
  exit = 'exit',
  dwell = 'dwell',
}

/** What happens to a fix inside a privacy zone. */
export enum PrivacyZoneAction {
  exclude = 'exclude',
  degrade = 'degrade',
  eventOnly = 'eventOnly',
}

/** HTTP method used for sync. */
export enum HttpMethod {
  post = 'post',
  put = 'put',
}

/** Order used when reading/uploading stored locations. */
export enum LocationOrderDirection {
  ascending = 'ascending',
  descending = 'descending',
}

/** How rejected/low-quality fixes are handled by the GPS filter. */
export enum LocationFilterPolicy {
  adjust = 'adjust',
  ignore = 'ignore',
  discard = 'discard',
}

/** Logger verbosity. */
export enum LogLevel {
  off = 'off',
  error = 'error',
  warn = 'warn',
  info = 'info',
  debug = 'debug',
  verbose = 'verbose',
}

/** Which record kinds are written to the database. */
export enum PersistMode {
  all = 'all',
  location = 'location',
  geofence = 'geofence',
  none = 'none',
}

/** Audit-trail hash algorithm. */
export enum HashAlgorithm {
  sha256 = 'sha256',
  sha512 = 'sha512',
}

/** Device attestation provider. */
export enum AttestationProvider {
  google = 'google',
  apple = 'apple',
}

/** Detected on-device activity type. */
export enum LocationActivityType {
  still = 'still',
  walking = 'walking',
  running = 'running',
  onFoot = 'on_foot',
  inVehicle = 'in_vehicle',
  onBicycle = 'on_bicycle',
  unknown = 'unknown',
}

/** Lifecycle status of the optional AI crash model. */
export enum CrashModelStatus {
  unlocking = 'unlocking',
  downloading = 'downloading',
  decrypting = 'decrypting',
  ready = 'ready',
  failed = 'failed',
  disabled = 'disabled',
}

/** Android notification priority. */
export enum NotificationPriority {
  min = 'min',
  low = 'low',
  default = 'default',
  high = 'high',
  max = 'max',
}
