import Foundation
import React
import CoreMotion
import UIKit
import TraceletSDK

/// React Native bridge for Tracelet (iOS).
///
/// Contains **no business logic** — marshals JS objects to/from the
/// framework-agnostic `TraceletSdk` (dictionary API) and forwards the SDK's
/// event callbacks to JS via `RCTEventEmitter`.
@objc(TraceletModule)
public final class TraceletModule: RCTEventEmitter, TraceletEventSending {

  private let sdk = TraceletSdk.shared
  private var hasListeners = false
  private var initialized = false

  // MARK: - RCTEventEmitter plumbing

  public override static func requiresMainQueueSetup() -> Bool { true }

  public override func supportedEvents() -> [String] {
    return [
      E.location, E.motion, E.speedMotion, E.activity, E.provider, E.geofence,
      E.geofencesChange, E.heartbeat, E.http, E.schedule, E.powerSave,
      E.connectivity, E.enabled, E.notificationAction, E.authorization, E.watch,
      E.trip, E.budget, E.driving, E.impact, E.modeChange, E.crashModel,
    ]
  }

  public override func startObserving() { hasListeners = true }
  public override func stopObserving() { hasListeners = false }

  private func ensureInitialized() {
    guard !initialized else { return }
    sdk.setEventSender(self)
    sdk.initialize()
    initialized = true
  }

  private func emit(_ name: String, _ body: Any?) {
    guard hasListeners else { return }
    sendEvent(withName: name, body: body)
  }

  // MARK: - TraceletEventSending

  public func sendLocation(_ params: [String: Any]) { emit(E.location, params) }
  public func sendSpeedMotionEvent(_ params: [String: Any]) { emit(E.speedMotion, params) }
  public func sendMotionChange(_ params: [String: Any]) { emit(E.motion, params) }
  public func sendActivityChange(_ data: [String: Any]) { emit(E.activity, data) }
  public func sendProviderChange(_ data: [String: Any]) { emit(E.provider, data) }
  public func sendGeofence(_ data: [String: Any]) { emit(E.geofence, data) }
  public func sendGeofencesChange(_ data: [String: Any]) { emit(E.geofencesChange, data) }
  public func sendHeartbeat(_ data: [String: Any]) { emit(E.heartbeat, data) }
  public func sendHttp(_ data: [String: Any]) { emit(E.http, data) }
  public func sendSchedule(_ data: [String: Any]) { emit(E.schedule, data) }
  public func sendPowerSaveChange(_ isPowerSave: Bool) { emit(E.powerSave, isPowerSave) }
  public func sendConnectivityChange(_ data: [String: Any]) { emit(E.connectivity, data) }
  public func sendEnabledChange(_ enabled: Bool) { emit(E.enabled, enabled) }
  public func sendNotificationAction(_ data: [String: Any]) { emit(E.notificationAction, data) }
  public func sendAuthorization(_ data: [String: Any]) { emit(E.authorization, data) }
  public func sendWatchPosition(_ data: [String: Any]) { emit(E.watch, data) }
  public func sendRemoteConfigEvent(_ data: [String: Any]) { /* not exposed in v1 */ }
  public func sendTrip(_ data: [String: Any]) { emit(E.trip, data) }
  public func sendBudgetAdjustment(_ data: [String: Any]) { emit(E.budget, data) }
  public func sendDrivingEvent(_ data: [String: Any]) { emit(E.driving, data) }
  public func sendImpact(_ data: [String: Any]) { emit(E.impact, data) }
  public func sendModeChange(_ data: [String: Any]) { emit(E.modeChange, data) }
  public func sendCrashModelStatus(_ data: [String: Any]) { emit(E.crashModel, data) }
  public func hasListener(eventName: String) -> Bool { hasListeners }

  // MARK: - Lifecycle

  @objc(ready:resolve:reject:)
  func ready(_ config: NSDictionary, resolve: @escaping RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    ensureInitialized()
    resolve(sdk.ready(config: config.toDict()))
  }

  @objc(start:reject:)
  func start(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(sdk.start()) }

  @objc(stop:reject:)
  func stop(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(sdk.stop()) }

  @objc(startGeofences:reject:)
  func startGeofences(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(sdk.startGeofences()) }

  @objc(startPeriodic:reject:)
  func startPeriodic(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(sdk.startPeriodic()) }

  @objc(getState:reject:)
  func getState(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(sdk.getState()) }

  @objc(setConfig:resolve:reject:)
  func setConfig(_ config: NSDictionary, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    resolve(sdk.setConfig(config.toDict()))
  }

  @objc(reset:resolve:reject:)
  func reset(_ config: NSDictionary?, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    resolve(sdk.reset(config?.toDict()))
  }

  // MARK: - Location

  @objc(getCurrentPosition:resolve:reject:)
  func getCurrentPosition(_ options: NSDictionary, resolve: @escaping RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    sdk.getCurrentPosition(options: options.toDict()) { location in resolve(location) }
  }

  @objc(getLastKnownLocation:resolve:reject:)
  func getLastKnownLocation(_ options: NSDictionary?, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    resolve(sdk.getLastKnownLocation(options: options?.toDict() ?? [:]))
  }

  @objc(watchPosition:resolve:reject:)
  func watchPosition(_ options: NSDictionary, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    resolve(sdk.watchPosition(options: options.toDict()))
  }

  @objc(stopWatchPosition:resolve:reject:)
  func stopWatchPosition(_ watchId: NSNumber, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    resolve(sdk.stopWatchPosition(watchId.intValue))
  }

  @objc(changePace:resolve:reject:)
  func changePace(_ isMoving: Bool, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    resolve(sdk.changePace(isMoving))
  }

  @objc(getOdometer:reject:)
  func getOdometer(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(sdk.getOdometer()) }

  @objc(setOdometer:resolve:reject:)
  func setOdometer(_ value: Double, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    resolve(sdk.setOdometer(value))
  }

  // MARK: - Geofencing

  @objc(addGeofence:resolve:reject:)
  func addGeofence(_ geofence: NSDictionary, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    resolve(sdk.addGeofence(geofence.toDict()))
  }

  @objc(addGeofences:resolve:reject:)
  func addGeofences(_ geofences: NSArray, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    resolve(sdk.addGeofences(geofences.toDictArray()))
  }

  @objc(removeGeofence:resolve:reject:)
  func removeGeofence(_ identifier: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    resolve(sdk.removeGeofence(identifier))
  }

  @objc(removeGeofences:reject:)
  func removeGeofences(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(sdk.removeGeofences()) }

  @objc(getGeofences:reject:)
  func getGeofences(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(sdk.getGeofences()) }

  @objc(getGeofence:resolve:reject:)
  func getGeofence(_ identifier: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    resolve(sdk.getGeofence(identifier))
  }

  @objc(geofenceExists:resolve:reject:)
  func geofenceExists(_ identifier: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    resolve(sdk.geofenceExists(identifier))
  }

  // MARK: - Persistence / Logs

  @objc(getLocations:resolve:reject:)
  func getLocations(_ query: NSDictionary?, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    resolve(sdk.getLocations(query: query?.toDict()))
  }

  @objc(getCount:resolve:reject:)
  func getCount(_ query: NSDictionary?, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    resolve(sdk.getCount(query: query?.toDict()))
  }

  @objc(destroyLocations:reject:)
  func destroyLocations(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(sdk.destroyLocations()) }

  @objc(destroySyncedLocations:reject:)
  func destroySyncedLocations(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(sdk.destroySyncedLocations()) }

  @objc(destroyLocation:resolve:reject:)
  func destroyLocation(_ uuid: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    resolve(sdk.destroyLocation(uuid))
  }

  @objc(insertLocation:resolve:reject:)
  func insertLocation(_ params: NSDictionary, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    resolve(sdk.insertLocation(params.toDict()))
  }

  @objc(getLogs:resolve:reject:)
  func getLogs(_ limit: NSNumber, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    let logs = sdk.getLogs(limit: limit.intValue).map { entry -> [String: Any] in
      ["id": entry.id, "level": entry.level, "message": entry.message, "timestamp": entry.timestamp]
    }
    resolve(logs)
  }

  @objc(clearLogs:reject:)
  func clearLogs(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { sdk.clearLogs(); resolve(nil) }

  @objc(getLog:resolve:reject:)
  func getLog(_ query: NSDictionary?, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    resolve(sdk.getLog(query: query?.toDict()))
  }

  @objc(destroyLog:reject:)
  func destroyLog(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(sdk.destroyLog()) }

  @objc(emailLog:resolve:reject:)
  func emailLog(_ email: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(false) }

  @objc(log:message:resolve:reject:)
  func log(_ level: String, message: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    sdk.log(level, message)
    resolve(true)
  }

  // MARK: - HTTP sync

  @objc(sync:reject:)
  func sync(_ resolve: @escaping RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    sdk.sync { synced in resolve(synced) }
  }

  @objc(setDynamicHeaders:resolve:reject:)
  func setDynamicHeaders(_ headers: NSDictionary, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    sdk.setDynamicHeaders(headers.toStringDict())
    resolve(true)
  }

  @objc(refreshHeaders:resolve:reject:)
  func refreshHeaders(_ force: Bool, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(true) }

  @objc(setRouteContext:resolve:reject:)
  func setRouteContext(_ context: NSDictionary, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    sdk.setRouteContext(context.toDict())
    resolve(true)
  }

  @objc(clearRouteContext:reject:)
  func clearRouteContext(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    sdk.clearRouteContext()
    resolve(true)
  }

  @objc(setSyncBodyResponse:resolve:reject:)
  func setSyncBodyResponse(_ body: NSDictionary, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(nil) }

  @objc(registerHeadlessSyncBodyBuilder:resolve:reject:)
  func registerHeadlessSyncBodyBuilder(_ callbackIds: NSArray, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(false) }

  @objc(registerHeadlessHeadersCallback:resolve:reject:)
  func registerHeadlessHeadersCallback(_ callbackIds: NSArray, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(false) }

  // MARK: - Telematics / crash & fall

  @objc(getTelematicsEvents:resolve:reject:)
  func getTelematicsEvents(_ limit: NSNumber, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    let events = sdk.getTelematicsEvents(limit: limit.intValue).map { e -> [String: Any] in
      ["id": e.id, "eventType": e.eventType, "severity": e.severity,
       "latitude": e.latitude, "longitude": e.longitude, "timestamp": e.timestamp, "synced": e.synced]
    }
    resolve(events)
  }

  @objc(destroyTelematicsEvents:reject:)
  func destroyTelematicsEvents(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(sdk.destroyTelematicsEvents()) }

  @objc(simulateTelematicsEvent:severity:latitude:longitude:resolve:reject:)
  func simulateTelematicsEvent(_ eventType: String, severity: Double, latitude: Double, longitude: Double, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    resolve(sdk.simulateTelematicsEvent(eventType: eventType, severity: severity, latitude: latitude, longitude: longitude))
  }

  @objc(debugRunCrashModelInference:resolve:reject:)
  func debugRunCrashModelInference(_ options: NSDictionary, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    let dict = options.toDict()
    let peakG = (dict["peakG"] as? NSNumber)?.doubleValue ?? 5.0
    let speedKmh = (dict["speedKmh"] as? NSNumber)?.doubleValue ?? 60.0
    let crashLike = (dict["crashLike"] as? Bool) ?? true
    resolve(sdk.debugRunCrashModelInference(peakG, speedKmh, crashLike))
  }

  @objc(confirmImpact:resolve:reject:)
  func confirmImpact(_ id: NSNumber, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    resolve(sdk.confirmImpact(id.int64Value))
  }

  @objc(cancelImpact:resolve:reject:)
  func cancelImpact(_ id: NSNumber, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    resolve(sdk.cancelImpact(id.int64Value))
  }

  // MARK: - Permissions

  @objc(getPermissionStatus:reject:)
  func getPermissionStatus(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    resolve(Self.authToJs(sdk.getPermissionStatus()))
  }

  @objc(requestPermission:reject:)
  func requestPermission(_ resolve: @escaping RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    DispatchQueue.main.async {
      let requestAlways = self.sdk.configManager.getLocationAuthorizationRequest() == "Always"
      self.sdk.permissionManager.requestPermission(requestAlways: requestAlways) { status in
        resolve(Self.authToJs((status as? Int) ?? 0))
      }
    }
  }

  @objc(getNotificationPermissionStatus:reject:)
  func getNotificationPermissionStatus(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    resolve("authorized") // Always granted on iOS
  }

  @objc(requestNotificationPermission:reject:)
  func requestNotificationPermission(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    resolve("authorized") // Always granted on iOS
  }

  @objc(getMotionPermissionStatus:reject:)
  func getMotionPermissionStatus(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    if let detector = sdk.motionDetector {
      resolve(Self.motionToJs(detector.getMotionAuthorizationStatus()))
    } else {
      resolve(Self.motionToJs(Self.cmStatusToSdk(CMMotionActivityManager.authorizationStatus())))
    }
  }

  @objc(requestMotionPermission:reject:)
  func requestMotionPermission(_ resolve: @escaping RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    guard let detector = sdk.motionDetector else { resolve(3); return }
    DispatchQueue.main.async {
      detector.requestMotionPermission { status in resolve(Self.motionToJs(status)) }
    }
  }

  @objc(canScheduleExactAlarms:reject:)
  func canScheduleExactAlarms(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(true) }

  @objc(openExactAlarmSettings:reject:)
  func openExactAlarmSettings(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(false) }

  @objc(requestTemporaryFullAccuracy:resolve:reject:)
  func requestTemporaryFullAccuracy(_ purpose: String, resolve: @escaping RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    DispatchQueue.main.async {
      let result = self.sdk.permissionManager.requestTemporaryFullAccuracy(purposeKey: purpose)
      resolve((result as? Int) ?? 0)
    }
  }

  @objc(hasBackgroundPermission:reject:)
  func hasBackgroundPermission(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    resolve(sdk.hasBackgroundPermission)
  }

  // MARK: - Device / diagnostics

  @objc(getProviderState:reject:)
  func getProviderState(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(sdk.getProviderState()) }

  @objc(getSensors:reject:)
  func getSensors(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(sdk.getSensors()) }

  @objc(getDeviceInfo:reject:)
  func getDeviceInfo(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    var info = sdk.getDeviceInfo()
    info["framework"] = "react-native"
    resolve(info)
  }

  @objc(isPowerSaveMode:reject:)
  func isPowerSaveMode(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(sdk.isPowerSaveMode) }

  @objc(isIgnoringBatteryOptimizations:reject:)
  func isIgnoringBatteryOptimizations(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(true) }

  @objc(playSound:resolve:reject:)
  func playSound(_ name: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(sdk.playSound(name)) }

  // MARK: - Settings / OEM

  @objc(requestSettings:resolve:reject:)
  func requestSettings(_ action: String, resolve: @escaping RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    DispatchQueue.main.async { resolve(self.sdk.permissionManager.showLocationSettings()) }
  }

  @objc(showSettings:resolve:reject:)
  func showSettings(_ action: String, resolve: @escaping RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    DispatchQueue.main.async {
      resolve(action == "app" ? self.sdk.permissionManager.showAppSettings() : self.sdk.permissionManager.showLocationSettings())
    }
  }

  @objc(getSettingsHealth:reject:)
  func getSettingsHealth(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    resolve([
      "manufacturer": "Apple",
      "model": UIDevice.current.model,
      "isAggressiveOem": false,
      "aggressionRating": 0,
      "isIgnoringBatteryOptimizations": true,
      "autostartAvailable": false,
      "oemSettingsScreens": [[String: String]](),
    ])
  }

  @objc(openOemSettings:resolve:reject:)
  func openOemSettings(_ label: String, resolve: @escaping RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    DispatchQueue.main.async { resolve(self.sdk.permissionManager.showAppSettings()) }
  }

  @objc(showPowerManager:reject:)
  func showPowerManager(_ resolve: @escaping RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    DispatchQueue.main.async { resolve(self.sdk.permissionManager.showAppSettings()) }
  }

  // MARK: - Background / scheduling

  @objc(startBackgroundTask:reject:)
  func startBackgroundTask(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    let taskId = UIApplication.shared.beginBackgroundTask(withName: "TraceletRN", expirationHandler: nil)
    resolve(Int(taskId.rawValue))
  }

  @objc(stopBackgroundTask:resolve:reject:)
  func stopBackgroundTask(_ taskId: NSNumber, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    UIApplication.shared.endBackgroundTask(UIBackgroundTaskIdentifier(rawValue: taskId.intValue))
    resolve(0)
  }

  @objc(startSchedule:reject:)
  func startSchedule(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(sdk.startSchedule()) }

  @objc(stopSchedule:reject:)
  func stopSchedule(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(sdk.stopSchedule()) }

  @objc(registerHeadlessTask:resolve:reject:)
  func registerHeadlessTask(_ callbackIds: NSArray, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(false) }

  // MARK: - Enterprise

  @objc(verifyAuditTrail:reject:)
  func verifyAuditTrail(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(sdk.verifyAuditTrail()) }

  @objc(getAuditProof:resolve:reject:)
  func getAuditProof(_ uuid: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    resolve(sdk.getAuditProof(uuid))
  }

  @objc(addPrivacyZone:resolve:reject:)
  func addPrivacyZone(_ zone: NSDictionary, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    resolve(sdk.addPrivacyZone(zone.toDict()))
  }

  @objc(addPrivacyZones:resolve:reject:)
  func addPrivacyZones(_ zones: NSArray, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    resolve(sdk.addPrivacyZones(zones.toDictArray()))
  }

  @objc(removePrivacyZone:resolve:reject:)
  func removePrivacyZone(_ identifier: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    resolve(sdk.removePrivacyZone(identifier))
  }

  @objc(removePrivacyZones:reject:)
  func removePrivacyZones(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(sdk.removePrivacyZones()) }

  @objc(getPrivacyZones:reject:)
  func getPrivacyZones(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(sdk.getPrivacyZones()) }

  @objc(isDatabaseEncrypted:reject:)
  func isDatabaseEncrypted(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(sdk.isDatabaseEncrypted()) }

  @objc(encryptDatabase:reject:)
  func encryptDatabase(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(sdk.encryptDatabase()) }

  @objc(getAttestationToken:reject:)
  func getAttestationToken(_ resolve: @escaping RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    sdk.getAttestationToken { token in resolve(token) }
  }

  @objc(getDeadReckoningState:reject:)
  func getDeadReckoningState(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(sdk.getDeadReckoningState()) }

  @objc(getCarbonReport:resolve:reject:)
  func getCarbonReport(_ query: NSDictionary?, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    resolve(sdk.getCarbonReport(query: query?.toDict()))
  }

  // MARK: - Helpers

  private static func cmStatusToSdk(_ status: CMAuthorizationStatus) -> Int {
    switch status {
    case .notDetermined: return 0
    case .restricted: return 1
    case .denied: return 2
    case .authorized: return 3
    @unknown default: return 0
    }
  }

  // SDK location int (0=notDetermined, 2=whenInUse, 3=always, 4=deniedForever)
  // → JS `AuthorizationStatus` (notDetermined=0, whenInUse=1, denied=2, always=3, deniedForever=4).
  private static func authToJs(_ value: Int) -> Int {
    switch value {
    case 0: return 0
    case 1: return 2
    case 2: return 1
    case 3: return 3
    case 4: return 4
    default: return 0
    }
  }

  // SDK motion code (0=notDetermined, 1=restricted, 2=denied, 3=authorized, 4=deniedForever)
  // → JS `MotionAuthorizationStatus` (authorized=0, denied=1, restricted=2, notDetermined=3).
  private static func motionToJs(_ value: Int) -> Int {
    switch value {
    case 3: return 0
    case 2, 4: return 1
    case 1: return 2
    case 0: return 3
    default: return 3
    }
  }

  private enum E {
    static let location = "tracelet:location"
    static let motion = "tracelet:motionChange"
    static let speedMotion = "tracelet:speedMotionChange"
    static let activity = "tracelet:activityChange"
    static let provider = "tracelet:providerChange"
    static let geofence = "tracelet:geofence"
    static let geofencesChange = "tracelet:geofencesChange"
    static let heartbeat = "tracelet:heartbeat"
    static let http = "tracelet:http"
    static let schedule = "tracelet:schedule"
    static let powerSave = "tracelet:powerSaveChange"
    static let connectivity = "tracelet:connectivityChange"
    static let enabled = "tracelet:enabledChange"
    static let notificationAction = "tracelet:notificationAction"
    static let authorization = "tracelet:authorization"
    static let watch = "tracelet:watchPosition"
    static let trip = "tracelet:trip"
    static let budget = "tracelet:budgetAdjustment"
    static let driving = "tracelet:drivingEvent"
    static let impact = "tracelet:impact"
    static let modeChange = "tracelet:modeChange"
    static let crashModel = "tracelet:crashModelStatus"
  }
}

private extension NSDictionary {
  func toDict() -> [String: Any] { self as? [String: Any] ?? [:] }
  func toStringDict() -> [String: String] {
    var out: [String: String] = [:]
    for (k, v) in self { if let key = k as? String { out[key] = "\(v)" } }
    return out
  }
}

private extension NSArray {
  func toDictArray() -> [[String: Any]] { compactMap { $0 as? [String: Any] } }
}
