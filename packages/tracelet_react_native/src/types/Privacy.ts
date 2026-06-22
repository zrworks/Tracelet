import type { PrivacyZoneAction } from './Enums';

/** A privacy zone. Locations inside are excluded, degraded, or event-only. */
export interface PrivacyZone {
  identifier: string;
  latitude: number;
  longitude: number;
  radius: number;
  action?: PrivacyZoneAction;
  degradedAccuracyMeters?: number;
  extras?: Record<string, unknown>;
}

/** Per-request route/trip context attached to synced locations. */
export interface RouteContext {
  taskId?: string;
  driverId?: string;
  trackingSessionId?: string;
  extras?: Record<string, unknown>;
}
