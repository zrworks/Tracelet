import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

/**
 * Low-level TurboModule spec. All complex payloads cross the bridge as plain
 * objects (the same map shape the native SDK already uses). Strong typing lives
 * in the {@link Tracelet} facade — this interface is intentionally map-based to
 * satisfy React Native codegen.
 */
export interface Spec extends TurboModule {
  // Lifecycle
  ready(config: Object): Promise<Object>;
  start(): Promise<Object>;
  stop(): Promise<Object>;
  startGeofences(): Promise<Object>;
  startPeriodic(): Promise<Object>;
  getState(): Promise<Object>;
  setConfig(config: Object): Promise<Object>;
  reset(config?: Object | null): Promise<Object>;

  // Location
  getCurrentPosition(options: Object): Promise<Object>;
  getLastKnownLocation(options?: Object | null): Promise<Object | null>;
  watchPosition(options: Object): Promise<number>;
  stopWatchPosition(watchId: number): Promise<boolean>;
  changePace(isMoving: boolean): Promise<boolean>;
  getOdometer(): Promise<number>;
  setOdometer(value: number): Promise<Object>;

  // Geofencing
  addGeofence(geofence: Object): Promise<boolean>;
  addGeofences(geofences: Object[]): Promise<boolean>;
  removeGeofence(identifier: string): Promise<boolean>;
  removeGeofences(): Promise<boolean>;
  getGeofences(): Promise<Object[]>;
  getGeofence(identifier: string): Promise<Object | null>;
  geofenceExists(identifier: string): Promise<boolean>;

  // Persistence / DB / Logs
  getLocations(query?: Object | null): Promise<Object[]>;
  getCount(query?: Object | null): Promise<number>;
  destroyLocations(): Promise<boolean>;
  destroySyncedLocations(): Promise<number>;
  destroyLocation(uuid: string): Promise<boolean>;
  insertLocation(params: Object): Promise<string>;
  getLogs(limit: number): Promise<Object[]>;
  clearLogs(): Promise<void>;
  getLog(query?: Object | null): Promise<string>;
  destroyLog(): Promise<boolean>;
  emailLog(email: string): Promise<boolean>;
  log(level: string, message: string): Promise<boolean>;

  // HTTP sync
  sync(): Promise<Object[]>;
  setDynamicHeaders(headers: Object): Promise<boolean>;
  refreshHeaders(force: boolean): Promise<boolean>;
  setRouteContext(context: Object): Promise<boolean>;
  clearRouteContext(): Promise<boolean>;
  setSyncBodyResponse(body: Object): Promise<void>;
  registerHeadlessSyncBodyBuilder(callbackIds: number[]): Promise<boolean>;
  registerHeadlessHeadersCallback(callbackIds: number[]): Promise<boolean>;

  // Telematics / crash / fall
  getTelematicsEvents(limit: number): Promise<Object[]>;
  destroyTelematicsEvents(): Promise<boolean>;
  simulateTelematicsEvent(
    eventType: string,
    severity: number,
    latitude: number,
    longitude: number
  ): Promise<boolean>;
  debugRunCrashModelInference(options: Object): Promise<Object>;
  confirmImpact(id: number): Promise<boolean>;
  cancelImpact(id: number): Promise<boolean>;

  // Motion / permissions
  getMotionPermissionStatus(): Promise<number>;
  requestMotionPermission(): Promise<number>;
  getPermissionStatus(): Promise<number>;
  requestPermission(): Promise<number>;
  getNotificationPermissionStatus(): Promise<string>;
  requestNotificationPermission(): Promise<string>;
  canScheduleExactAlarms(): Promise<boolean>;
  openExactAlarmSettings(): Promise<boolean>;
  requestTemporaryFullAccuracy(purpose: string): Promise<number>;
  hasBackgroundPermission(): Promise<boolean>;

  // Device / diagnostics
  getProviderState(): Promise<Object>;
  getSensors(): Promise<Object>;
  getDeviceInfo(): Promise<Object>;
  isPowerSaveMode(): Promise<boolean>;
  isIgnoringBatteryOptimizations(): Promise<boolean>;
  playSound(name: string): Promise<boolean>;

  // Settings / OEM
  requestSettings(action: string): Promise<boolean>;
  showSettings(action: string): Promise<boolean>;
  getSettingsHealth(): Promise<Object>;
  openOemSettings(label: string): Promise<boolean>;
  showPowerManager(): Promise<boolean>;

  // Background / scheduling / headless
  startBackgroundTask(): Promise<number>;
  stopBackgroundTask(taskId: number): Promise<number>;
  registerHeadlessTask(callbackIds: number[]): Promise<boolean>;
  startSchedule(): Promise<Object>;
  stopSchedule(): Promise<Object>;

  // Enterprise: audit / privacy / encryption / attestation / dead-reckoning / carbon / compliance
  verifyAuditTrail(): Promise<Object>;
  getAuditProof(uuid: string): Promise<Object | null>;
  addPrivacyZone(zone: Object): Promise<boolean>;
  addPrivacyZones(zones: Object[]): Promise<boolean>;
  removePrivacyZone(identifier: string): Promise<boolean>;
  removePrivacyZones(): Promise<boolean>;
  getPrivacyZones(): Promise<Object[]>;
  isDatabaseEncrypted(): Promise<boolean>;
  encryptDatabase(): Promise<boolean>;
  getAttestationToken(): Promise<Object | null>;
  getDeadReckoningState(): Promise<Object | null>;
  getCarbonReport(query?: Object | null): Promise<Object>;

  // Event emitter plumbing (required by RN codegen for event-emitting modules)
  addListener(eventName: string): void;
  removeListeners(count: number): void;
}

export default TurboModuleRegistry.getEnforcing<Spec>('TraceletReactNative');
