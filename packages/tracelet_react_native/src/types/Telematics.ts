import type { Location } from './Location';

/** A persisted telematics record. */
export interface TelematicsRecord {
  id: number;
  eventType: string;
  severity: number;
  location: Location;
  /** ISO8601 timestamp. */
  timestamp: string;
  synced: boolean;
}

/** Options for {@link Tracelet.simulateTelematicsEvent}. */
export interface SimulateTelematicsOptions {
  eventType: string;
  severity: number;
  latitude: number;
  longitude: number;
}

/** Options for {@link Tracelet.debugRunCrashModelInference}. */
export interface CrashModelInferenceOptions {
  peakG?: number;
  speedKmh?: number;
  crashLike?: boolean;
}
