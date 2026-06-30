import type { Location } from './Location';
import type { Geofence } from './Geofence';
import type {
  LocationActivityType,
  GeofenceAction,
  AuthorizationStatus,
  AccuracyAuthorization,
  DesiredAccuracy,
  CrashModelStatus,
} from './Enums';

/** Activity-change event. */
export interface ActivityChangeEvent {
  activity: LocationActivityType;
  confidence: number;
}

/** Location-provider state-change event. */
export interface ProviderChangeEvent {
  enabled: boolean;
  gps: boolean;
  network: boolean;
  status: AuthorizationStatus;
  accuracyAuthorization?: AccuracyAuthorization | null;
}

/** Geofence transition event. */
export interface GeofenceEvent {
  identifier: string;
  action: GeofenceAction;
  location: Location;
  extras: Record<string, unknown>;
}

/** Geofences set-change event (monitoring started/stopped). */
export interface GeofencesChangeEvent {
  on?: Geofence[] | null;
  off?: Geofence[] | null;
}

/** Periodic heartbeat event. */
export interface HeartbeatEvent {
  location: Location;
}

/** HTTP sync result event. */
export interface HttpEvent {
  success: boolean;
  status: number;
  responseText?: string | null;
}

/** Speed-based motion change event. */
export interface SpeedMotionEvent {
  isMoving: boolean;
  location: Location;
}

/** Network connectivity change event. */
export interface ConnectivityChangeEvent {
  connected: boolean;
}

/** Location authorization change event. */
export interface AuthorizationEvent {
  success: boolean;
  status: number;
  response?: string | null;
}

/** Driving-behaviour (telematics) event. */
export interface DrivingEvent {
  /** Event type, e.g. `harsh_braking`, `harsh_acceleration`, `harsh_cornering`, `speeding`. */
  type: string;
  speed: number;
  severity: number;
  location: Location;
  /** ISO8601 timestamp. */
  timestamp: string;
}

/** Crash / fall impact event. */
export interface ImpactEvent {
  /** Candidate id; pass to {@link Tracelet.confirmImpact}/{@link Tracelet.cancelImpact}. */
  id: number;
  /** `potential_crash` | `crash` | `potential_fall` | `fall`. */
  kind: string;
  /** Whether this is a pending (potential) candidate awaiting confirmation. */
  isPotential: boolean;
  location: Location;
  /** ISO8601 timestamp. */
  timestamp: string;
  extras: Record<string, unknown>;
}

/** Transport-mode change event. */
export interface ModeChangeEvent {
  /** `car` | `bike` | `foot` | `unknown`. */
  mode: string;
  location: Location;
}

/** AI crash-model lifecycle status event. */
export interface CrashModelStatusEvent {
  status: CrashModelStatus;
}

/** Trip-end event. */
export interface TripEvent {
  identifier: string;
  distance: number;
  duration: number;
  startLocation: Location;
  stopLocation: Location;
  waypoints: Location[];
  /** ISO8601 timestamp. */
  startTime: string;
  /** ISO8601 timestamp. */
  stopTime: string;
}

/** Battery-budget adaptive-adjustment event. */
export interface BudgetAdjustmentEvent {
  currentBatteryDrain: number;
  newDistanceFilter: number;
  newDesiredAccuracy: DesiredAccuracy;
  newPeriodicInterval?: number | null;
}

/** Headless background event payload (Android terminated-app delivery). */
export interface HeadlessEvent {
  name: string;
  event: Record<string, unknown>;
}
