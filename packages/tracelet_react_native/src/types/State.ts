import type { Config } from './Config';
import type { TrackingMode } from './Enums';

/** Snapshot of the plugin's current state. */
export interface State {
  enabled: boolean;
  isMoving: boolean;
  trackingMode: TrackingMode;
  schedulerEnabled: boolean;
  odometer: number;
  lastLocationTimestamp?: number | null;
  config?: Config | null;
}
