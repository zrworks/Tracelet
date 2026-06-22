import type { DesiredAccuracy, LocationActivityType } from './Enums';

/** Geographic coordinates and movement attributes. */
export interface Coords {
  latitude: number;
  longitude: number;
  accuracy: number;
  speed: number;
  heading: number;
  altitude: number;
  altitudeAccuracy: number;
  speedAccuracy: number;
  headingAccuracy: number;
  floor?: number | null;
}

/** Detected activity attached to a location. */
export interface LocationActivity {
  activity: LocationActivityType;
  confidence: number;
}

/** Battery snapshot attached to a location. */
export interface LocationBattery {
  level: number;
  isCharging: boolean;
}

/** Reverse-geocoded address (only present when `geo.resolveAddress` is enabled). */
export interface Address {
  street?: string | null;
  city?: string | null;
  province?: string | null;
  country?: string | null;
  postalCode?: string | null;
}

/** A single location fix. */
export interface Location {
  coords: Coords;
  /** ISO8601 timestamp. */
  timestamp: string;
  isMoving: boolean;
  uuid: string;
  odometer: number;
  locationSource: string;
  reducedAccuracy: boolean;
  isMock: boolean;
  mockHeuristics?: Record<string, unknown> | null;
  activity: LocationActivity;
  battery: LocationBattery;
  extras: Record<string, unknown>;
  event?: string | null;
  auditHash?: string | null;
  auditPreviousHash?: string | null;
  auditChainIndex?: number | null;
  address?: Address | null;
}

/** Options for {@link Tracelet.getCurrentPosition}. */
export interface CurrentPositionOptions {
  desiredAccuracy?: DesiredAccuracy;
  timeout?: number;
  maximumAge?: number;
  persist?: boolean;
  samples?: number;
  extras?: Record<string, unknown>;
}

/** Options for {@link Tracelet.getLastKnownLocation}. */
export interface LastKnownLocationOptions {
  persist?: boolean;
  extras?: Record<string, unknown>;
}

/** Options for {@link Tracelet.watchPosition}. */
export interface WatchPositionOptions {
  interval?: number;
  desiredAccuracy?: DesiredAccuracy;
  extras?: Record<string, unknown>;
}

/** SQL query window for reading stored locations. */
export interface SQLQuery {
  /** Milliseconds since epoch. */
  start?: number;
  /** Milliseconds since epoch. */
  end?: number;
  limit?: number;
  offset?: number;
  order?: 'ascending' | 'descending';
}
