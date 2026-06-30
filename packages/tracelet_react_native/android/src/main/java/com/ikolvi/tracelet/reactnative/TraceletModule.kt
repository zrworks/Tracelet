package com.ikolvi.tracelet.reactnative

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableMap
import com.facebook.react.modules.core.DeviceEventManagerModule
import com.ikolvi.tracelet.sdk.TraceletEventSender
import com.ikolvi.tracelet.sdk.TraceletSdk
import com.ikolvi.tracelet.sdk.model.AuthorizationStatus

/**
 * React Native bridge for Tracelet.
 *
 * This module contains **no business logic** — it marshals JS objects to/from
 * the framework-agnostic [TraceletSdk] (map-based API) and forwards the SDK's
 * 22 event callbacks to JS via `RCTDeviceEventEmitter`.
 */
class TraceletModule(
  private val reactContext: ReactApplicationContext,
) : ReactContextBaseJavaModule(reactContext) {

  override fun getName(): String = NAME

  private val sdk: TraceletSdk get() = TraceletSdk.getInstance(reactContext)

  @Volatile private var initialized = false

  /** Lazily wire the event sender + bootstrap the SDK exactly once. */
  private fun ensureInitialized() {
    if (initialized) return
    synchronized(this) {
      if (initialized) return
      sdk.setEventSender(eventSender)
      sdk.initialize()
      initialized = true
    }
  }

  private fun emit(eventName: String, payload: Any?) {
    reactContext
      .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
      .emit(eventName, payload)
  }

  // RN requires these for modules that emit events.
  @ReactMethod fun addListener(eventName: String) { /* no-op */ }
  @ReactMethod fun removeListeners(count: Int) { /* no-op */ }

  // ===========================================================================
  // Event sender — forwards every SDK callback to JS.
  // ===========================================================================

  private val eventSender = object : TraceletEventSender {
    override fun sendLocation(data: Map<String, Any?>) = emit(E_LOCATION, data.toWritable())
    override fun sendMotionChange(data: Map<String, Any?>) = emit(E_MOTION, data.toWritable())
    override fun sendSpeedMotionChange(data: Map<String, Any?>) = emit(E_SPEED_MOTION, data.toWritable())
    override fun sendActivityChange(data: Map<String, Any?>) = emit(E_ACTIVITY, data.toWritable())
    override fun sendProviderChange(data: Map<String, Any?>) = emit(E_PROVIDER, data.toWritable())
    override fun sendGeofence(data: Map<String, Any?>) = emit(E_GEOFENCE, data.toWritable())
    override fun sendGeofencesChange(data: Map<String, Any?>) = emit(E_GEOFENCES_CHANGE, data.toWritable())
    override fun sendHeartbeat(data: Map<String, Any?>) = emit(E_HEARTBEAT, data.toWritable())
    override fun sendHttp(data: Map<String, Any?>) = emit(E_HTTP, data.toWritable())
    override fun sendSchedule(data: Map<String, Any?>) = emit(E_SCHEDULE, data.toWritable())
    override fun sendPowerSaveChange(isPowerSaveMode: Boolean) = emit(E_POWER_SAVE, isPowerSaveMode)
    override fun sendConnectivityChange(data: Map<String, Any?>) = emit(E_CONNECTIVITY, data.toWritable())
    override fun sendEnabledChange(enabled: Boolean) = emit(E_ENABLED, enabled)
    override fun sendNotificationAction(action: String) = emit(E_NOTIFICATION_ACTION, action)
    override fun sendAuthorization(data: Map<String, Any?>) = emit(E_AUTHORIZATION, data.toWritable())
    override fun sendWatchPosition(data: Map<String, Any?>) = emit(E_WATCH, data.toWritable())
    override fun sendRemoteConfigEvent(data: Map<String, Any?>) { /* not exposed in v1 */ }
    override fun sendTrip(data: Map<String, Any?>) = emit(E_TRIP, data.toWritable())
    override fun sendBudgetAdjustment(data: Map<String, Any?>) = emit(E_BUDGET, data.toWritable())
    override fun sendDrivingEvent(data: Map<String, Any?>) = emit(E_DRIVING, data.toWritable())
    override fun sendImpact(data: Map<String, Any?>) = emit(E_IMPACT, data.toWritable())
    override fun sendModeChange(data: Map<String, Any?>) = emit(E_MODE_CHANGE, data.toWritable())
    override fun sendCrashModelStatus(data: Map<String, Any?>) = emit(E_CRASH_MODEL, data.toWritable())
    override fun hasListener(eventName: String): Boolean = true
  }

  // ===========================================================================
  // Lifecycle
  // ===========================================================================

  @ReactMethod
  fun ready(config: ReadableMap, promise: Promise) = guard(promise) {
    ensureInitialized()
    reactContext.currentActivity?.let { sdk.activity = it }
    sdk.ready(config.toMap()) { state -> promise.resolve(state.toWritable()) }
  }

  @ReactMethod
  fun start(promise: Promise) = guard(promise) {
    sdk.start()
    promise.resolve(sdk.getState().toWritable())
  }

  @ReactMethod
  fun stop(promise: Promise) = guard(promise) {
    sdk.stop()
    promise.resolve(sdk.getState().toWritable())
  }

  @ReactMethod
  fun startGeofences(promise: Promise) = guard(promise) {
    sdk.startGeofences()
    promise.resolve(sdk.getState().toWritable())
  }

  @ReactMethod
  fun startPeriodic(promise: Promise) = guard(promise) {
    sdk.startPeriodic()
    promise.resolve(sdk.getState().toWritable())
  }

  @ReactMethod
  fun getState(promise: Promise) = guard(promise) {
    promise.resolve(sdk.getState().toWritable())
  }

  @ReactMethod
  fun setConfig(config: ReadableMap, promise: Promise) = guard(promise) {
    promise.resolve(sdk.setConfig(config.toMap()).toWritable())
  }

  @ReactMethod
  fun reset(config: ReadableMap?, promise: Promise) = guard(promise) {
    sdk.reset(config?.toMap())
    promise.resolve(sdk.getState().toWritable())
  }

  // ===========================================================================
  // Location
  // ===========================================================================

  @ReactMethod
  fun getCurrentPosition(options: ReadableMap, promise: Promise) = guard(promise) {
    sdk.getCurrentPosition(options.toMap()) { location ->
      promise.resolve(location?.toWritable())
    }
  }

  @ReactMethod
  fun getLastKnownLocation(options: ReadableMap?, promise: Promise) = guard(promise) {
    sdk.getLastKnownLocation(options?.toMap() ?: emptyMap()) { location ->
      promise.resolve(location?.toWritable())
    }
  }

  @ReactMethod
  fun watchPosition(options: ReadableMap, promise: Promise) = guard(promise) {
    promise.resolve(sdk.watchPosition(options.toMap()))
  }

  @ReactMethod
  fun stopWatchPosition(watchId: Double, promise: Promise) = guard(promise) {
    promise.resolve(sdk.stopWatchPosition(watchId.toInt()))
  }

  @ReactMethod
  fun changePace(isMoving: Boolean, promise: Promise) = guard(promise) {
    sdk.changePace(isMoving)
    promise.resolve(true)
  }

  @ReactMethod
  fun getOdometer(promise: Promise) = guard(promise) { promise.resolve(sdk.getOdometer()) }

  @ReactMethod
  fun setOdometer(value: Double, promise: Promise) = guard(promise) {
    promise.resolve(sdk.setOdometer(value).toWritable())
  }

  // ===========================================================================
  // Geofencing
  // ===========================================================================

  @ReactMethod
  fun addGeofence(geofence: ReadableMap, promise: Promise) = guard(promise) {
    promise.resolve(sdk.addGeofence(geofence.toMap()))
  }

  @ReactMethod
  fun addGeofences(geofences: ReadableArray, promise: Promise) = guard(promise) {
    sdk.addGeofences(geofences.toMapList())
    promise.resolve(true)
  }

  @ReactMethod
  fun removeGeofence(identifier: String, promise: Promise) = guard(promise) {
    promise.resolve(sdk.removeGeofence(identifier))
  }

  @ReactMethod
  fun removeGeofences(promise: Promise) = guard(promise) { promise.resolve(sdk.removeGeofences()) }

  @ReactMethod
  fun getGeofences(promise: Promise) = guard(promise) {
    promise.resolve(sdk.getGeofences().toWritableArray())
  }

  @ReactMethod
  fun getGeofence(identifier: String, promise: Promise) = guard(promise) {
    promise.resolve(sdk.getGeofence(identifier)?.toWritable())
  }

  @ReactMethod
  fun geofenceExists(identifier: String, promise: Promise) = guard(promise) {
    promise.resolve(sdk.geofenceExists(identifier))
  }

  // ===========================================================================
  // Persistence / DB / Logs
  // ===========================================================================

  @ReactMethod
  fun getLocations(query: ReadableMap?, promise: Promise) = guard(promise) {
    promise.resolve(sdk.getLocations(query?.toMap()).toWritableArray())
  }

  @ReactMethod
  fun getCount(query: ReadableMap?, promise: Promise) = guard(promise) {
    promise.resolve(sdk.getCount(query?.toMap()))
  }

  @ReactMethod
  fun destroyLocations(promise: Promise) = guard(promise) { promise.resolve(sdk.destroyLocations()) }

  @ReactMethod
  fun destroySyncedLocations(promise: Promise) = guard(promise) {
    promise.resolve(sdk.destroySyncedLocations())
  }

  @ReactMethod
  fun destroyLocation(uuid: String, promise: Promise) = guard(promise) {
    promise.resolve(sdk.destroyLocation(uuid))
  }

  @ReactMethod
  fun insertLocation(params: ReadableMap, promise: Promise) = guard(promise) {
    promise.resolve(sdk.insertLocation(params.toMap()))
  }

  @ReactMethod
  fun getLogs(limit: Double, promise: Promise) = guard(promise) {
    val logs = sdk.getLogs(limit.toInt()).map {
      mapOf("id" to it.id.toLong(), "level" to it.level, "message" to it.message, "timestamp" to it.timestamp)
    }
    promise.resolve(logs.toWritableArray())
  }

  @ReactMethod
  fun clearLogs(promise: Promise) = guard(promise) { sdk.clearLogs(); promise.resolve(null) }

  @ReactMethod
  fun getLog(query: ReadableMap?, promise: Promise) = guard(promise) {
    promise.resolve(sdk.getLog(query?.toMap()))
  }

  @ReactMethod
  fun destroyLog(promise: Promise) = guard(promise) { promise.resolve(sdk.destroyLog()) }

  @ReactMethod
  fun emailLog(email: String, promise: Promise) = guard(promise) {
    // The SDK delivers logs via getLog; email composition is host-app responsibility.
    promise.resolve(false)
  }

  @ReactMethod
  fun log(level: String, message: String, promise: Promise) = guard(promise) {
    promise.resolve(sdk.log(level, message))
  }

  // ===========================================================================
  // HTTP sync
  // ===========================================================================

  @ReactMethod
  fun sync(promise: Promise) = guard(promise) {
    sdk.sync { synced -> promise.resolve(synced.toWritableArray()) }
  }

  @ReactMethod
  fun setDynamicHeaders(headers: ReadableMap, promise: Promise) = guard(promise) {
    @Suppress("UNCHECKED_CAST")
    sdk.setDynamicHeaders(headers.toMap().mapValues { it.value.toString() })
    promise.resolve(true)
  }

  @ReactMethod
  fun refreshHeaders(force: Boolean, promise: Promise) = guard(promise) { promise.resolve(true) }

  @ReactMethod
  fun setRouteContext(context: ReadableMap, promise: Promise) = guard(promise) {
    sdk.setRouteContext(context.toMap())
    promise.resolve(true)
  }

  @ReactMethod
  fun clearRouteContext(promise: Promise) = guard(promise) {
    sdk.clearRouteContext()
    promise.resolve(true)
  }

  @ReactMethod
  fun setSyncBodyResponse(body: ReadableMap, promise: Promise) = guard(promise) {
    // Headless custom-body builder is v2 (see PLAN-REACT-NATIVE §6).
    promise.resolve(null)
  }

  @ReactMethod
  fun registerHeadlessSyncBodyBuilder(callbackIds: ReadableArray, promise: Promise) =
    guard(promise) { promise.resolve(false) }

  @ReactMethod
  fun registerHeadlessHeadersCallback(callbackIds: ReadableArray, promise: Promise) =
    guard(promise) { promise.resolve(false) }

  // ===========================================================================
  // Telematics / crash & fall
  // ===========================================================================

  @ReactMethod
  fun getTelematicsEvents(limit: Double, promise: Promise) = guard(promise) {
    val events = sdk.getTelematicsEvents(limit.toInt()).map {
      mapOf(
        "id" to it.id,
        "eventType" to it.eventType,
        "severity" to it.severity,
        "latitude" to it.latitude,
        "longitude" to it.longitude,
        "timestamp" to it.timestamp,
        "synced" to it.synced,
      )
    }
    promise.resolve(events.toWritableArray())
  }

  @ReactMethod
  fun destroyTelematicsEvents(promise: Promise) = guard(promise) {
    promise.resolve(sdk.destroyTelematicsEvents())
  }

  @ReactMethod
  fun simulateTelematicsEvent(
    eventType: String,
    severity: Double,
    latitude: Double,
    longitude: Double,
    promise: Promise,
  ) = guard(promise) {
    promise.resolve(sdk.simulateTelematicsEvent(eventType, severity, latitude, longitude))
  }

  @ReactMethod
  fun debugRunCrashModelInference(options: ReadableMap, promise: Promise) = guard(promise) {
    val map = options.toMap()
    val peakG = (map["peakG"] as? Number)?.toDouble() ?: 5.0
    val speedKmh = (map["speedKmh"] as? Number)?.toDouble() ?: 60.0
    val crashLike = map["crashLike"] as? Boolean ?: true
    promise.resolve(sdk.debugRunCrashModelInference(peakG, speedKmh, crashLike).toWritable())
  }

  @ReactMethod
  fun confirmImpact(id: Double, promise: Promise) = guard(promise) {
    promise.resolve(sdk.confirmImpact(id.toLong()))
  }

  @ReactMethod
  fun cancelImpact(id: Double, promise: Promise) = guard(promise) {
    promise.resolve(sdk.cancelImpact(id.toLong()))
  }

  // ===========================================================================
  // Permissions
  // ===========================================================================

  @ReactMethod
  fun getPermissionStatus(promise: Promise) = guard(promise) {
    promise.resolve(authToJs(sdk.getPermissionStatus()))
  }

  @ReactMethod
  fun requestPermission(promise: Promise) = guard(promise) {
    reactContext.currentActivity?.let { sdk.activity = it }
    sdk.requestPermission { status: AuthorizationStatus -> promise.resolve(authToJs(status)) }
  }

  @ReactMethod
  fun getNotificationPermissionStatus(promise: Promise) = guard(promise) {
    promise.resolve(notificationToJs(sdk.getNotificationPermissionStatus()))
  }

  @ReactMethod
  fun requestNotificationPermission(promise: Promise) = guard(promise) {
    reactContext.currentActivity?.let { sdk.activity = it }
    sdk.requestNotificationPermission { status -> promise.resolve(notificationToJs(status)) }
  }

  @ReactMethod
  fun getMotionPermissionStatus(promise: Promise) = guard(promise) {
    promise.resolve(motionToJs(sdk.getMotionPermissionStatus()))
  }

  @ReactMethod
  fun requestMotionPermission(promise: Promise) = guard(promise) {
    reactContext.currentActivity?.let { sdk.activity = it }
    sdk.requestMotionPermission { status -> promise.resolve(motionToJs(status)) }
  }

  @ReactMethod
  fun canScheduleExactAlarms(promise: Promise) = guard(promise) {
    promise.resolve(sdk.canScheduleExactAlarms())
  }

  @ReactMethod
  fun openExactAlarmSettings(promise: Promise) = guard(promise) {
    promise.resolve(sdk.openExactAlarmSettings())
  }

  @ReactMethod
  fun requestTemporaryFullAccuracy(purpose: String, promise: Promise) = guard(promise) {
    // iOS-only concept; on Android full accuracy is governed by FINE permission.
    promise.resolve(if (sdk.getPermissionStatus() == AuthorizationStatus.DENIED) 1 else 0)
  }

  @ReactMethod
  fun hasBackgroundPermission(promise: Promise) = guard(promise) {
    promise.resolve(sdk.getPermissionStatus() == AuthorizationStatus.ALWAYS)
  }

  // ===========================================================================
  // Device / diagnostics
  // ===========================================================================

  @ReactMethod
  fun getProviderState(promise: Promise) = guard(promise) {
    promise.resolve(sdk.getProviderState().toWritable())
  }

  @ReactMethod
  fun getSensors(promise: Promise) = guard(promise) { promise.resolve(sdk.getSensors().toWritable()) }

  @ReactMethod
  fun getDeviceInfo(promise: Promise) = guard(promise) {
    val info = mapOf(
      "manufacturer" to android.os.Build.MANUFACTURER,
      "model" to android.os.Build.MODEL,
      "osVersion" to android.os.Build.VERSION.RELEASE,
      "buildNumber" to android.os.Build.DISPLAY,
      "isVirtualDevice" to android.os.Build.FINGERPRINT.contains("generic"),
      "isDeveloperModeEnabled" to false,
      "isPhysicalDevice" to !android.os.Build.FINGERPRINT.contains("generic"),
    )
    promise.resolve(info.toWritable())
  }

  @ReactMethod
  fun isPowerSaveMode(promise: Promise) = guard(promise) { promise.resolve(sdk.isPowerSaveMode()) }

  @ReactMethod
  fun isIgnoringBatteryOptimizations(promise: Promise) = guard(promise) {
    promise.resolve(sdk.isIgnoringBatteryOptimizations())
  }

  @ReactMethod
  fun playSound(name: String, promise: Promise) = guard(promise) { promise.resolve(sdk.playSound(name)) }

  // ===========================================================================
  // Settings / OEM
  // ===========================================================================

  @ReactMethod
  fun requestSettings(action: String, promise: Promise) = guard(promise) {
    promise.resolve(sdk.requestSettings(action))
  }

  @ReactMethod
  fun showSettings(action: String, promise: Promise) = guard(promise) {
    promise.resolve(sdk.showSettings(action))
  }

  @ReactMethod
  fun getSettingsHealth(promise: Promise) = guard(promise) {
    promise.resolve(sdk.getSettingsHealth().toWritable())
  }

  @ReactMethod
  fun openOemSettings(label: String, promise: Promise) = guard(promise) {
    promise.resolve(sdk.openOemSettings(label))
  }

  @ReactMethod
  fun showPowerManager(promise: Promise) = guard(promise) { promise.resolve(sdk.showPowerManager()) }

  // ===========================================================================
  // Background / scheduling
  // ===========================================================================

  @ReactMethod
  fun startBackgroundTask(promise: Promise) = guard(promise) { promise.resolve(0) }

  @ReactMethod
  fun stopBackgroundTask(taskId: Double, promise: Promise) = guard(promise) { promise.resolve(0) }

  @ReactMethod
  fun startSchedule(promise: Promise) = guard(promise) {
    sdk.startSchedule()
    promise.resolve(sdk.getState().toWritable())
  }

  @ReactMethod
  fun stopSchedule(promise: Promise) = guard(promise) {
    sdk.stopSchedule()
    promise.resolve(sdk.getState().toWritable())
  }

  @ReactMethod
  fun registerHeadlessTask(callbackIds: ReadableArray, promise: Promise) = guard(promise) {
    // Android Headless JS wiring is delivered in P6 (see PLAN-REACT-NATIVE §6).
    promise.resolve(false)
  }

  // ===========================================================================
  // Enterprise
  // ===========================================================================

  @ReactMethod
  fun verifyAuditTrail(promise: Promise) = guard(promise) {
    promise.resolve(sdk.verifyAuditChain().toWritable())
  }

  @ReactMethod
  fun getAuditProof(uuid: String, promise: Promise) = guard(promise) {
    promise.resolve(sdk.getAuditProof(uuid)?.toWritable())
  }

  @ReactMethod
  fun addPrivacyZone(zone: ReadableMap, promise: Promise) = guard(promise) {
    promise.resolve(sdk.addPrivacyZone(zone.toMap()))
  }

  @ReactMethod
  fun addPrivacyZones(zones: ReadableArray, promise: Promise) = guard(promise) {
    promise.resolve(sdk.addPrivacyZones(zones.toMapList()))
  }

  @ReactMethod
  fun removePrivacyZone(identifier: String, promise: Promise) = guard(promise) {
    promise.resolve(sdk.removePrivacyZone(identifier))
  }

  @ReactMethod
  fun removePrivacyZones(promise: Promise) = guard(promise) {
    promise.resolve(sdk.removePrivacyZones())
  }

  @ReactMethod
  fun getPrivacyZones(promise: Promise) = guard(promise) {
    promise.resolve(sdk.getPrivacyZones().toWritableArray())
  }

  @ReactMethod
  fun isDatabaseEncrypted(promise: Promise) = guard(promise) {
    promise.resolve(sdk.isDatabaseEncrypted())
  }

  @ReactMethod
  fun encryptDatabase(promise: Promise) = guard(promise) { promise.resolve(sdk.encryptDatabase()) }

  @ReactMethod
  fun getAttestationToken(promise: Promise) = guard(promise) {
    sdk.attestDevice { token -> promise.resolve(token?.toWritable()) }
  }

  @ReactMethod
  fun getDeadReckoningState(promise: Promise) = guard(promise) {
    promise.resolve(sdk.getDeadReckoningState()?.toWritable())
  }

  @ReactMethod
  fun getCarbonReport(query: ReadableMap?, promise: Promise) = guard(promise) {
    promise.resolve(sdk.getCarbonReport(query?.toMap()).toWritable())
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  private inline fun guard(promise: Promise, block: () -> Unit) {
    try {
      block()
    } catch (e: Throwable) {
      promise.reject("TRACELET_ERROR", e.message, e)
    }
  }

  // Maps the SDK's AuthorizationStatus to the JS `AuthorizationStatus` enum
  // (notDetermined=0, whenInUse=1, denied=2, always=3, deniedForever=4).
  private fun authToJs(status: AuthorizationStatus): Int = when (status) {
    AuthorizationStatus.NOT_DETERMINED -> 0
    AuthorizationStatus.WHEN_IN_USE -> 1
    AuthorizationStatus.DENIED -> 2
    AuthorizationStatus.ALWAYS -> 3
    AuthorizationStatus.DENIED_FOREVER -> 4
  }

  // Maps to the JS `MotionAuthorizationStatus` enum
  // (authorized=0, denied=1, restricted=2, notDetermined=3).
  private fun motionToJs(status: AuthorizationStatus): Int = when (status) {
    AuthorizationStatus.WHEN_IN_USE, AuthorizationStatus.ALWAYS -> 0
    AuthorizationStatus.DENIED, AuthorizationStatus.DENIED_FOREVER -> 1
    AuthorizationStatus.NOT_DETERMINED -> 3
  }

  // Maps to the JS `NotificationAuthorizationStatus` string enum.
  private fun notificationToJs(status: AuthorizationStatus): String = when (status) {
    AuthorizationStatus.WHEN_IN_USE, AuthorizationStatus.ALWAYS -> "authorized"
    else -> "denied"
  }

  @Suppress("UNCHECKED_CAST")
  private fun ReadableMap.toMap(): Map<String, Any?> = toHashMap() as Map<String, Any?>

  @Suppress("UNCHECKED_CAST")
  private fun ReadableArray.toMapList(): List<Map<String, Any?>> =
    toArrayList().mapNotNull { it as? Map<String, Any?> }

  private fun Map<String, Any?>.toWritable(): WritableMap = Arguments.makeNativeMap(this)

  private fun List<Map<String, Any?>>.toWritableArray() =
    Arguments.makeNativeArray(this.map { Arguments.makeNativeMap(it) })

  companion object {
    const val NAME = "TraceletReactNative"

    private const val E_LOCATION = "tracelet:location"
    private const val E_MOTION = "tracelet:motionChange"
    private const val E_SPEED_MOTION = "tracelet:speedMotionChange"
    private const val E_ACTIVITY = "tracelet:activityChange"
    private const val E_PROVIDER = "tracelet:providerChange"
    private const val E_GEOFENCE = "tracelet:geofence"
    private const val E_GEOFENCES_CHANGE = "tracelet:geofencesChange"
    private const val E_HEARTBEAT = "tracelet:heartbeat"
    private const val E_HTTP = "tracelet:http"
    private const val E_SCHEDULE = "tracelet:schedule"
    private const val E_POWER_SAVE = "tracelet:powerSaveChange"
    private const val E_CONNECTIVITY = "tracelet:connectivityChange"
    private const val E_ENABLED = "tracelet:enabledChange"
    private const val E_NOTIFICATION_ACTION = "tracelet:notificationAction"
    private const val E_AUTHORIZATION = "tracelet:authorization"
    private const val E_WATCH = "tracelet:watchPosition"
    private const val E_TRIP = "tracelet:trip"
    private const val E_BUDGET = "tracelet:budgetAdjustment"
    private const val E_DRIVING = "tracelet:drivingEvent"
    private const val E_IMPACT = "tracelet:impact"
    private const val E_MODE_CHANGE = "tracelet:modeChange"
    private const val E_CRASH_MODEL = "tracelet:crashModelStatus"
  }
}
