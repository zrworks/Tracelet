import type { State } from './State';
import type { ProviderChangeEvent } from './Events';
import type { AuthorizationStatus, MotionAuthorizationStatus } from './Enums';

/** Detected hardware sensors. */
export interface Sensors {
  hasAccelerometer: boolean;
  hasGyroscope: boolean;
  hasMagnetometer: boolean;
  hasBarometer: boolean;
  hasProximity: boolean;
  hasAmbientLight: boolean;
  hasStepCounter: boolean;
  hasSignificantMotion: boolean;
}

/** Device hardware/software info. */
export interface DeviceInfo {
  manufacturer: string;
  model: string;
  osVersion: string;
  buildNumber?: string | null;
  isVirtualDevice: boolean;
  isDeveloperModeEnabled: boolean;
  isPhysicalDevice: boolean;
}

/** A single persisted log entry. */
export interface LogEntry {
  id: number;
  /** ISO8601 timestamp. */
  timestamp: string;
  level: string;
  message: string;
}

/** Comprehensive diagnostic snapshot from {@link Tracelet.getHealth}. */
export interface HealthCheck {
  state: State;
  provider: ProviderChangeEvent;
  settingsHealth: Record<string, unknown>;
  sensors: Sensors;
  deviceInfo: DeviceInfo;
  isPowerSave: boolean;
  isIgnoringBatteryOptimizations: boolean;
  locationPermission: AuthorizationStatus;
  motionPermission: MotionAuthorizationStatus;
  dbCount: number;
  warnings: string[];
}
