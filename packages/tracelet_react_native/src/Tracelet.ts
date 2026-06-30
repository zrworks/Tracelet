import Native from './NativeTracelet';
import { addEventListener, TraceletEvents, type Subscription } from './events';

import type { Config } from './types/Config';
import type {
  Location,
  CurrentPositionOptions,
  LastKnownLocationOptions,
  WatchPositionOptions,
  SQLQuery,
} from './types/Location';
import type { Geofence } from './types/Geofence';
import type { State } from './types/State';
import type {
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
} from './types/Events';
import type {
  TelematicsRecord,
  SimulateTelematicsOptions,
  CrashModelInferenceOptions,
} from './types/Telematics';
import type { PrivacyZone, RouteContext } from './types/Privacy';
import type {
  AuditVerification,
  AuditProof,
  AttestationToken,
  ComplianceReport,
} from './types/Audit';
import type {
  Sensors,
  DeviceInfo,
  LogEntry,
  HealthCheck,
} from './types/Health';
import {
  AuthorizationStatus,
  MotionAuthorizationStatus,
  NotificationAuthorizationStatus,
  FullAccuracyStatus,
} from './types/Enums';

/**
 * Production-grade background geolocation for React Native.
 *
 * Mirrors the Tracelet Dart public API 1:1 and is backed by the same native
 * SDKs (`com.ikolvi:tracelet-sdk`, `TraceletSDK`) and shared Rust core.
 */
export class Tracelet {
  private constructor() {}

  /** Last config passed to {@link ready}/{@link setConfig}; used by composed reports. */
  private static activeConfig: Config = {};

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  static ready(config: Config): Promise<State> {
    Tracelet.activeConfig = config;
    return Native.ready(config) as Promise<State>;
  }

  static start(): Promise<State> {
    return Native.start() as Promise<State>;
  }

  static stop(): Promise<State> {
    return Native.stop() as Promise<State>;
  }

  static startGeofences(): Promise<State> {
    return Native.startGeofences() as Promise<State>;
  }

  static startPeriodic(): Promise<State> {
    return Native.startPeriodic() as Promise<State>;
  }

  static getState(): Promise<State> {
    return Native.getState() as Promise<State>;
  }

  static getHealth(): Promise<HealthCheck> {
    return Promise.all([
      Native.getState(),
      Native.getProviderState(),
      Native.getSettingsHealth(),
      Native.getSensors(),
      Native.getDeviceInfo(),
      Native.isPowerSaveMode(),
      Native.isIgnoringBatteryOptimizations(),
      Native.getPermissionStatus(),
      Native.getMotionPermissionStatus(),
      Native.getCount(null),
    ]).then(
      ([
        state,
        provider,
        settingsHealth,
        sensors,
        deviceInfo,
        isPowerSave,
        isIgnoringBatteryOptimizations,
        locationPermission,
        motionPermission,
        dbCount,
      ]) =>
        ({
          state,
          provider,
          settingsHealth,
          sensors,
          deviceInfo,
          isPowerSave,
          isIgnoringBatteryOptimizations,
          locationPermission,
          motionPermission,
          dbCount,
          warnings: [],
        }) as unknown as HealthCheck
    );
  }

  static setConfig(config: Config): Promise<State> {
    Tracelet.activeConfig = config;
    return Native.setConfig(config) as Promise<State>;
  }

  static reset(config?: Config): Promise<State> {
    return Native.reset(config ?? null) as Promise<State>;
  }

  // ---------------------------------------------------------------------------
  // Location
  // ---------------------------------------------------------------------------

  static async getCurrentPosition(
    options: CurrentPositionOptions = {}
  ): Promise<Location> {
    const loc = await Native.getCurrentPosition(options);
    return Tracelet.normalizeLocation(loc);
  }

  static async getLastKnownLocation(
    options: LastKnownLocationOptions = {}
  ): Promise<Location | null> {
    const loc = await Native.getLastKnownLocation(options);
    return Tracelet.normalizeLocation(loc);
  }

  static async watchPosition(
    callback: (location: Location) => void,
    options: WatchPositionOptions = {}
  ): Promise<number> {
    const sub = addEventListener<Location>(
      TraceletEvents.watchPosition,
      (payload: any) => callback(Tracelet.normalizeLocation(payload))
    );
    const watchId = await Native.watchPosition(options);
    Tracelet.watchSubscriptions.set(watchId, sub);
    return watchId;
  }

  static async stopWatchPosition(watchId: number): Promise<boolean> {
    Tracelet.watchSubscriptions.get(watchId)?.remove();
    Tracelet.watchSubscriptions.delete(watchId);
    return Native.stopWatchPosition(watchId);
  }

  static changePace(isMoving: boolean): Promise<boolean> {
    return Native.changePace(isMoving);
  }

  static getOdometer(): Promise<number> {
    return Native.getOdometer();
  }

  static setOdometer(value: number): Promise<Location> {
    return Native.setOdometer(value).then(Tracelet.normalizeLocation) as Promise<Location>;
  }

  // ---------------------------------------------------------------------------
  // Geofencing (circular + polygon)
  // ---------------------------------------------------------------------------

  static addGeofence(geofence: Geofence): Promise<boolean> {
    return Native.addGeofence(geofence);
  }

  static addGeofences(geofences: Geofence[]): Promise<boolean> {
    return Native.addGeofences(geofences);
  }

  static removeGeofence(identifier: string): Promise<boolean> {
    return Native.removeGeofence(identifier);
  }

  static removeGeofences(): Promise<boolean> {
    return Native.removeGeofences();
  }

  static getGeofences(): Promise<Geofence[]> {
    return Native.getGeofences() as Promise<Geofence[]>;
  }

  static getGeofence(identifier: string): Promise<Geofence | null> {
    return Native.getGeofence(identifier) as Promise<Geofence | null>;
  }

  static geofenceExists(identifier: string): Promise<boolean> {
    return Native.geofenceExists(identifier);
  }

  // ---------------------------------------------------------------------------
  // Persistence / DB / Logs
  // ---------------------------------------------------------------------------

  static getLocations(query?: SQLQuery): Promise<Location[]> {
    return Native.getLocations(query ?? null).then((locations: any[]) => locations.map(Tracelet.normalizeLocation)) as Promise<Location[]>;
  }

  static getCount(query?: SQLQuery): Promise<number> {
    return Native.getCount(query ?? null);
  }

  /** Locations captured but not yet synced (alias of {@link getLocations}). */
  static getPendingLocations(query?: SQLQuery): Promise<Location[]> {
    return Native.getLocations(query ?? null).then((locations: any[]) => locations.map(Tracelet.normalizeLocation)) as Promise<Location[]>;
  }

  /** Count of locations pending sync (alias of {@link getCount}). */
  static getPendingLocationCount(query?: SQLQuery): Promise<number> {
    return Native.getCount(query ?? null);
  }

  static destroyLocations(): Promise<boolean> {
    return Native.destroyLocations();
  }

  static destroySyncedLocations(): Promise<number> {
    return Native.destroySyncedLocations();
  }

  static destroyLocation(uuid: string): Promise<boolean> {
    return Native.destroyLocation(uuid);
  }

  static insertLocation(params: Record<string, unknown>): Promise<string> {
    return Native.insertLocation(params);
  }

  static getLogs(limit: number): Promise<LogEntry[]> {
    return Native.getLogs(limit) as Promise<LogEntry[]>;
  }

  static clearLogs(): Promise<void> {
    return Native.clearLogs();
  }

  static getLog(query?: SQLQuery): Promise<string> {
    return Native.getLog(query ?? null);
  }

  static destroyLog(): Promise<boolean> {
    return Native.destroyLog();
  }

  static emailLog(email: string): Promise<boolean> {
    return Native.emailLog(email);
  }

  static log(level: string, message: string): Promise<boolean> {
    return Native.log(level, message);
  }

  // ---------------------------------------------------------------------------
  // HTTP sync
  // ---------------------------------------------------------------------------

  static sync(): Promise<Location[]> {
    return Native.sync().then((locations: any[]) => locations.map(Tracelet.normalizeLocation)) as Promise<Location[]>;
  }

  static setDynamicHeaders(headers: Record<string, string>): Promise<boolean> {
    return Native.setDynamicHeaders(headers);
  }

  static refreshHeaders(force = false): Promise<boolean> {
    return Native.refreshHeaders(force);
  }

  static setRouteContext(context: RouteContext): Promise<boolean> {
    return Native.setRouteContext(context);
  }

  static clearRouteContext(): Promise<boolean> {
    return Native.clearRouteContext();
  }

  // ---------------------------------------------------------------------------
  // Telematics / crash & fall
  // ---------------------------------------------------------------------------

  static getTelematicsEvents(limit: number): Promise<TelematicsRecord[]> {
    return Native.getTelematicsEvents(limit) as Promise<TelematicsRecord[]>;
  }

  static destroyTelematicsEvents(): Promise<boolean> {
    return Native.destroyTelematicsEvents();
  }

  static simulateTelematicsEvent(
    options: SimulateTelematicsOptions
  ): Promise<boolean> {
    return Native.simulateTelematicsEvent(
      options.eventType,
      options.severity,
      options.latitude,
      options.longitude
    );
  }

  static debugRunCrashModelInference(
    options: CrashModelInferenceOptions = {}
  ): Promise<Record<string, unknown>> {
    return Native.debugRunCrashModelInference(options) as Promise<
      Record<string, unknown>
    >;
  }

  static confirmImpact(id: number): Promise<boolean> {
    return Native.confirmImpact(id);
  }

  static cancelImpact(id: number): Promise<boolean> {
    return Native.cancelImpact(id);
  }

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  static async getLocationAuthorization(): Promise<AuthorizationStatus> {
    return (await Native.getPermissionStatus()) as AuthorizationStatus;
  }

  static async requestLocationAuthorization(): Promise<AuthorizationStatus> {
    const { Platform, PermissionsAndroid } = require('react-native');
    if (Platform.OS === 'android') {
      try {
        const fg = await PermissionsAndroid.requestMultiple([
          PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION,
          PermissionsAndroid.PERMISSIONS.ACCESS_COARSE_LOCATION,
        ]);
        
        let deniedForever = false;
        if (fg[PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION] === 'never_ask_again') {
          deniedForever = true;
        }

        if (Platform.Version >= 29 && 
           (fg[PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION] === 'granted' || 
            fg[PermissionsAndroid.PERMISSIONS.ACCESS_COARSE_LOCATION] === 'granted')) {
          const bg = await PermissionsAndroid.request(PermissionsAndroid.PERMISSIONS.ACCESS_BACKGROUND_LOCATION);
          if (bg === 'never_ask_again') deniedForever = true;
        }
        
        const status = await Native.getPermissionStatus();
        if (deniedForever && status === 0 /* NOT_DETERMINED */) {
          return 4 /* DENIED_FOREVER */ as AuthorizationStatus;
        }
        return status as AuthorizationStatus;
      } catch (e) {
        console.warn(e);
      }
    }
    return (await Native.requestPermission()) as AuthorizationStatus;
  }

  static async getMotionAuthorization(): Promise<MotionAuthorizationStatus> {
    return (await Native.getMotionPermissionStatus()) as MotionAuthorizationStatus;
  }

  static async requestMotionAuthorization(): Promise<MotionAuthorizationStatus> {
    const { Platform, PermissionsAndroid } = require('react-native');
    if (Platform.OS === 'android' && Platform.Version >= 29) {
      try {
        const result = await PermissionsAndroid.request(PermissionsAndroid.PERMISSIONS.ACTIVITY_RECOGNITION);
        const status = await Native.getMotionPermissionStatus();
        if (result === 'never_ask_again' && status === 3 /* NOT_DETERMINED */) {
          return 1 /* DENIED_FOREVER mapped to 1 in MotionStatus */ as MotionAuthorizationStatus;
        }
        return status as MotionAuthorizationStatus;
      } catch (e) {
        console.warn(e);
      }
    }
    return (await Native.requestMotionPermission()) as MotionAuthorizationStatus;
  }

  static async getNotificationAuthorization(): Promise<NotificationAuthorizationStatus> {
    return (await Native.getNotificationPermissionStatus()) as NotificationAuthorizationStatus;
  }

  static async requestNotificationAuthorization(): Promise<NotificationAuthorizationStatus> {
    const { Platform, PermissionsAndroid } = require('react-native');
    if (Platform.OS === 'android' && Platform.Version >= 33) {
      try {
        await PermissionsAndroid.request(PermissionsAndroid.PERMISSIONS.POST_NOTIFICATIONS);
      } catch (e) {
        console.warn(e);
      }
      return (await Native.getNotificationPermissionStatus()) as NotificationAuthorizationStatus;
    }
    return (await Native.requestNotificationPermission()) as NotificationAuthorizationStatus;
  }

  static canScheduleExactAlarms(): Promise<boolean> {
    return Native.canScheduleExactAlarms();
  }

  static openExactAlarmSettings(): Promise<boolean> {
    return Native.openExactAlarmSettings();
  }

  static get hasBackgroundPermission(): Promise<boolean> {
    return Native.hasBackgroundPermission();
  }

  static async requestTemporaryFullAccuracyAuthorization(
    purpose: string
  ): Promise<FullAccuracyStatus> {
    return (await Native.requestTemporaryFullAccuracy(
      purpose
    )) as FullAccuracyStatus;
  }

  // ---------------------------------------------------------------------------
  // Device / diagnostics
  // ---------------------------------------------------------------------------

  static getProviderState(): Promise<ProviderChangeEvent> {
    return Native.getProviderState() as Promise<ProviderChangeEvent>;
  }

  static getSensors(): Promise<Sensors> {
    return Native.getSensors() as Promise<Sensors>;
  }

  static getDeviceInfo(): Promise<DeviceInfo> {
    return Native.getDeviceInfo() as Promise<DeviceInfo>;
  }

  static get isPowerSaveMode(): Promise<boolean> {
    return Native.isPowerSaveMode();
  }

  static isIgnoringBatteryOptimizations(): Promise<boolean> {
    return Native.isIgnoringBatteryOptimizations();
  }

  static playSound(name: string): Promise<boolean> {
    return Native.playSound(name);
  }

  // ---------------------------------------------------------------------------
  // Settings / OEM
  // ---------------------------------------------------------------------------

  static requestSettings(action: string): Promise<boolean> {
    return Native.requestSettings(action);
  }

  static showSettings(action: string): Promise<boolean> {
    return Native.showSettings(action);
  }

  static openAppSettings(): Promise<boolean> {
    return Native.showSettings('app');
  }

  static openLocationSettings(): Promise<boolean> {
    return Native.showSettings('location');
  }

  static openBatterySettings(): Promise<boolean> {
    return Native.showSettings('battery');
  }

  static getSettingsHealth(): Promise<Record<string, unknown>> {
    return Native.getSettingsHealth() as Promise<Record<string, unknown>>;
  }

  static openOemSettings(label: string): Promise<boolean> {
    return Native.openOemSettings(label);
  }

  static showPowerManager(): Promise<boolean> {
    return Native.showPowerManager();
  }

  // ---------------------------------------------------------------------------
  // Background / scheduling
  // ---------------------------------------------------------------------------

  static startBackgroundTask(): Promise<number> {
    return Native.startBackgroundTask();
  }

  static stopBackgroundTask(taskId: number): Promise<number> {
    return Native.stopBackgroundTask(taskId);
  }

  static startSchedule(): Promise<State> {
    return Native.startSchedule() as Promise<State>;
  }

  static stopSchedule(): Promise<State> {
    return Native.stopSchedule() as Promise<State>;
  }

  // ---------------------------------------------------------------------------
  // Enterprise
  // ---------------------------------------------------------------------------

  static verifyAuditTrail(): Promise<AuditVerification> {
    return Native.verifyAuditTrail() as Promise<AuditVerification>;
  }

  static getAuditProof(uuid: string): Promise<AuditProof | null> {
    return Native.getAuditProof(uuid) as Promise<AuditProof | null>;
  }

  static addPrivacyZone(zone: PrivacyZone): Promise<boolean> {
    return Native.addPrivacyZone(zone);
  }

  static addPrivacyZones(zones: PrivacyZone[]): Promise<boolean> {
    return Native.addPrivacyZones(zones);
  }

  static removePrivacyZone(identifier: string): Promise<boolean> {
    return Native.removePrivacyZone(identifier);
  }

  static removePrivacyZones(): Promise<boolean> {
    return Native.removePrivacyZones();
  }

  static getPrivacyZones(): Promise<PrivacyZone[]> {
    return Native.getPrivacyZones() as Promise<PrivacyZone[]>;
  }

  static isDatabaseEncrypted(): Promise<boolean> {
    return Native.isDatabaseEncrypted();
  }

  static encryptDatabase(): Promise<boolean> {
    return Native.encryptDatabase();
  }

  static getAttestationToken(): Promise<AttestationToken | null> {
    return Native.getAttestationToken() as Promise<AttestationToken | null>;
  }

  static getDeadReckoningState(): Promise<Record<string, unknown> | null> {
    return Native.getDeadReckoningState() as Promise<Record<
      string,
      unknown
    > | null>;
  }

  static getCarbonReport(
    query?: Record<string, unknown>
  ): Promise<Record<string, unknown>> {
    return Native.getCarbonReport(query ?? null) as Promise<
      Record<string, unknown>
    >;
  }

  static async generateComplianceReport(): Promise<ComplianceReport> {
    const [
      state,
      count,
      locationPerm,
      motionPerm,
      zones,
      oldest,
      newest,
      dbEncrypted,
    ] = await Promise.all([
      Native.getState() as Promise<State>,
      Native.getCount(null),
      Native.getPermissionStatus(),
      Native.getMotionPermissionStatus(),
      Native.getPrivacyZones() as Promise<PrivacyZone[]>,
      Native.getLocations({ limit: 1, order: 0 }).then((l: any[]) => l.map(Tracelet.normalizeLocation)) as Promise<Location[]>,
      Native.getLocations({ limit: 1, order: 1 }).then((l: any[]) => l.map(Tracelet.normalizeLocation)) as Promise<Location[]>,
      Native.isDatabaseEncrypted(),
    ]);

    const cfg = Tracelet.activeConfig;
    return {
      generatedAt: new Date().toISOString(),
      totalLocationsStored: count,
      totalLocationsSynced: 0,
      maxDaysToPersist: cfg.persistence?.maxDaysToPersist ?? 0,
      maxRecordsToPersist: cfg.persistence?.maxRecordsToPersist ?? 0,
      oldestRecord: oldest[0]?.timestamp ?? null,
      newestRecord: newest[0]?.timestamp ?? null,
      databaseEncrypted: dbEncrypted,
      activePrivacyZones: zones.length,
      privacyZoneIdentifiers: zones.map((z) => z.identifier),
      httpSyncUrl: cfg.http?.url ?? null,
      autoSyncEnabled: cfg.http?.autoSync ?? false,
      auditTrailEnabled: cfg.audit?.enabled ?? false,
      locationPermissionStatus: locationPerm,
      motionPermissionStatus: motionPerm,
      sparseUpdatesEnabled: cfg.geo?.enableSparseUpdates ?? false,
      kalmanFilterEnabled: cfg.geo?.filter?.useKalmanFilter ?? false,
      deltaCompressionEnabled: cfg.http?.enableDeltaCompression ?? false,
      trackingEnabled: state.enabled,
      trackingMode: String(state.trackingMode),
    };
  }

  // ---------------------------------------------------------------------------
  // Event listeners
  // ---------------------------------------------------------------------------

  private static watchSubscriptions = new Map<number, Subscription>();

  private static normalizeLocation(payload: any): Location {
    if (!payload) return payload;
    return {
      ...payload,
      isMoving: payload.isMoving ?? payload.is_moving ?? false,
      isMock: payload.isMock ?? payload.mock ?? false,
    } as Location;
  }

  static onLocation(cb: (location: Location) => void): Subscription {
    return addEventListener(TraceletEvents.location, (payload: any) => cb(Tracelet.normalizeLocation(payload)));
  }

  static onMotionChange(cb: (location: Location) => void): Subscription {
    return addEventListener(TraceletEvents.motionChange, (payload: any) => cb(Tracelet.normalizeLocation(payload)));
  }

  static onSpeedMotionChange(cb: (event: SpeedMotionEvent) => void): Subscription {
    return addEventListener(TraceletEvents.speedMotionChange, cb);
  }

  static onActivityChange(cb: (event: ActivityChangeEvent) => void): Subscription {
    return addEventListener(TraceletEvents.activityChange, cb);
  }

  static onProviderChange(cb: (event: ProviderChangeEvent) => void): Subscription {
    return addEventListener(TraceletEvents.providerChange, cb);
  }

  static onGeofence(cb: (event: GeofenceEvent) => void): Subscription {
    return addEventListener(TraceletEvents.geofence, cb);
  }

  static onGeofencesChange(
    cb: (event: GeofencesChangeEvent) => void
  ): Subscription {
    return addEventListener(TraceletEvents.geofencesChange, cb);
  }

  static onHeartbeat(cb: (event: HeartbeatEvent) => void): Subscription {
    return addEventListener(TraceletEvents.heartbeat, cb);
  }

  static onHttp(cb: (event: HttpEvent) => void): Subscription {
    return addEventListener(TraceletEvents.http, cb);
  }

  static onSchedule(cb: (state: State) => void): Subscription {
    return addEventListener(TraceletEvents.schedule, cb);
  }

  static onPowerSaveChange(cb: (isPowerSaveMode: boolean) => void): Subscription {
    return addEventListener(TraceletEvents.powerSaveChange, cb);
  }

  static onConnectivityChange(
    cb: (event: ConnectivityChangeEvent) => void
  ): Subscription {
    return addEventListener(TraceletEvents.connectivityChange, cb);
  }

  static onEnabledChange(cb: (enabled: boolean) => void): Subscription {
    return addEventListener(TraceletEvents.enabledChange, cb);
  }

  static onNotificationAction(cb: (action: string) => void): Subscription {
    return addEventListener(TraceletEvents.notificationAction, cb);
  }

  static onAuthorization(cb: (event: AuthorizationEvent) => void): Subscription {
    return addEventListener(TraceletEvents.authorization, cb);
  }

  static onDrivingEvent(cb: (event: DrivingEvent) => void): Subscription {
    return addEventListener(TraceletEvents.drivingEvent, cb);
  }

  static onImpact(cb: (event: ImpactEvent) => void): Subscription {
    return addEventListener(TraceletEvents.impact, cb);
  }

  static onModeChange(cb: (event: ModeChangeEvent) => void): Subscription {
    return addEventListener(TraceletEvents.modeChange, cb);
  }

  static onCrashModelStatus(
    cb: (event: CrashModelStatusEvent) => void
  ): Subscription {
    return addEventListener(TraceletEvents.crashModelStatus, cb);
  }

  static onTrip(cb: (event: TripEvent) => void): Subscription {
    return addEventListener(TraceletEvents.trip, cb);
  }

  static onBudgetAdjustment(
    cb: (event: BudgetAdjustmentEvent) => void
  ): Subscription {
    return addEventListener(TraceletEvents.budgetAdjustment, cb);
  }
}
