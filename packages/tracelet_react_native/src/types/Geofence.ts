/** A geofence. Provide `radius` for circular, or `vertices` for polygon geofences. */
export interface Geofence {
  identifier: string;
  latitude: number;
  longitude: number;
  /** Radius in meters (circular geofence). */
  radius?: number;
  notifyOnEntry?: boolean;
  notifyOnExit?: boolean;
  notifyOnDwell?: boolean;
  loiteringDelay?: number;
  extras?: Record<string, unknown>;
  /** Polygon vertices as `[latitude, longitude]` pairs. Free, unlimited. */
  vertices?: Array<[number, number]>;
}
