# Tracelet — Master Project Plan

> **A fully open-source, production-grade Flutter background geolocation plugin.**
> Battery-conscious motion-detection intelligence, geofencing, SQLite persistence, HTTP sync, and headless Dart execution — for iOS & Android.

| Field | Value |
|---|---|
| **License** | Apache 2.0 (fully open-source, no proprietary native SDKs) |
| **Languages** | Dart · Kotlin (Android) · Swift (iOS) |
| **Architecture** | Federated Flutter Plugin (4 packages) |
| **Platform Comms** | Pigeon (type-safe) + EventChannel (streams) |
| **Min Android** | API 26 (Android 8.0) |
| **Min iOS** | 14.0 |
| **Target pub.dev name** | `tracelet` |

---

## Phase 0 — Project Scaffolding & Federated Structure

### 0.1 Monorepo & Tooling Setup
- [ ] Initialize git repo at `/Tracelet` with `.gitignore` (Dart/Flutter/Kotlin/Swift/Xcode/Gradle)
- [ ] Create `melos.yaml` for monorepo management (bootstrap, clean, test, analyze, format)
- [ ] Configure GitHub Actions CI: lint → analyze → test → build (Android + iOS)
- [ ] Add `LICENSE` (Apache 2.0) and root `README.md`
- [ ] Add `CONTRIBUTING.md` with PR/issue guidelines
- [ ] Add `CODE_OF_CONDUCT.md`
- [ ] Configure Dependabot for Dart, Gradle, and CocoaPods dependencies

### 0.2 Federated Package Creation
- [ ] Scaffold `packages/tracelet/` — app-facing Dart API
  - [ ] `pubspec.yaml` with `default_package` entries for Android & iOS
  - [ ] `lib/tracelet.dart` barrel export
  - [ ] `example/` Flutter app skeleton
- [ ] Scaffold `packages/tracelet_platform_interface/`
  - [ ] `pubspec.yaml` depending on `plugin_platform_interface`
  - [ ] `lib/tracelet_platform_interface.dart` barrel export
- [ ] Scaffold `packages/tracelet_android/`
  - [ ] `pubspec.yaml` depending on `tracelet_platform_interface`
  - [ ] `android/` Kotlin plugin skeleton (Gradle, `TraceletPlugin.kt`)
- [ ] Scaffold `packages/tracelet_ios/`
  - [ ] `pubspec.yaml` depending on `tracelet_platform_interface`
  - [ ] `ios/` Swift plugin skeleton (Podspec / Package.swift, `TraceletPlugin.swift`)
- [ ] Verify `flutter pub get` resolves cleanly across all 4 packages
- [ ] Verify `melos bootstrap` links all local packages

### 0.3 Pigeon Code Generation Setup
- [ ] Create `packages/tracelet_platform_interface/pigeons/tracelet_api.dart`
  - [ ] Define `@ConfigurePigeon` with Kotlin + Swift output paths
  - [ ] Define all Pigeon data classes (messages) mirroring Dart models
  - [ ] Define `@HostApi()` — Dart-calls-Native interface (≈40 methods)
  - [ ] Define `@FlutterApi()` — Native-calls-Dart interface (headless dispatch)
- [ ] Add `pigeon` to `dev_dependencies`
- [ ] Add `melos run pigeon` script target
- [ ] Run code generation → verify Kotlin output compiles
- [ ] Run code generation → verify Swift output compiles
- [ ] Commit generated code (not `.gitignore`'d — reproducible builds)

### 0.4 EventChannel Wiring
- [ ] Define 14 EventChannel path constants in platform interface:
  - [ ] `events/location`
  - [ ] `events/motionchange`
  - [ ] `events/activitychange`
  - [ ] `events/providerchange`
  - [ ] `events/geofence`
  - [ ] `events/geofenceschange`
  - [ ] `events/heartbeat`
  - [ ] `events/http`
  - [ ] `events/schedule`
  - [ ] `events/powersavechange`
  - [ ] `events/connectivitychange`
  - [ ] `events/enabledchange`
  - [ ] `events/notificationaction`
  - [ ] `events/authorization`
- [ ] Create base `StreamHandler` registration pattern for Android (Kotlin)
- [ ] Create base `StreamHandler` registration pattern for iOS (Swift)
- [ ] Wire up a smoke-test EventChannel (location) end-to-end and verify data flows

---

## Phase 1 — Core Dart API (`packages/tracelet/`)

### 1.1 Configuration Models
- [ ] `Config` — top-level compound config
  - [ ] `GeoConfig` — `desiredAccuracy`, `distanceFilter`, `locationUpdateInterval`, `fastestLocationUpdateInterval`, `stationaryRadius`, `locationTimeout`, `activityType`
  - [ ] `AppConfig` — `stopOnTerminate`, `startOnBoot`, `heartbeatInterval`, `schedule`, `foregroundService` (Android notification config)
  - [ ] `HttpConfig` — `url`, `method`, `headers`, `httpRootProperty`, `batchSync`, `maxBatchSize`, `autoSync`, `autoSyncThreshold`, `httpTimeout`, `params`, `locationsOrderDirection`, `extras`
  - [ ] `LoggerConfig` — `logLevel`, `logMaxDays`, `debug` (sound FX)
  - [ ] `MotionConfig` — `stopTimeout`, `motionTriggerDelay`, `disableMotionActivityUpdates`, `isMoving`
  - [ ] `GeofenceConfig` — `geofenceProximityRadius`, `geofenceInitialTriggerEntry`, `geofenceModeKnockOut`
- [ ] Add `toMap()` and `fromMap()` serialization to every config class
- [ ] Write unit tests for all config serialization round-trips

### 1.2 Data Models
- [ ] `Location` — `coords` (lat, lng, altitude, speed, heading, accuracy, speedAccuracy, headingAccuracy, altitudeAccuracy, floor), `timestamp`, `isMoving`, `uuid`, `odometer`, `activity` (type + confidence), `battery` (level + isCharging), `extras`, `event`
- [ ] `State` — `enabled`, `trackingMode`, `schedulerEnabled`, `odometer`, `didLaunchInBackground`, `didDeviceReboot`, `config` snapshot
- [ ] `Geofence` — `identifier`, `radius`, `latitude`, `longitude`, `notifyOnEntry`, `notifyOnExit`, `notifyOnDwell`, `loiteringDelay`, `extras`, `vertices` (polygon support placeholder)
- [ ] `GeofenceEvent` — `identifier`, `action` (ENTER/EXIT/DWELL), `location`, `extras`
- [ ] `GeofencesChangeEvent` — `on` (activated list), `off` (deactivated list)
- [ ] `ProviderChangeEvent` — `enabled`, `status`, `gps`, `network`, `accuracyAuthorization`
- [ ] `ActivityChangeEvent` — `activity`, `confidence`
- [ ] `HttpEvent` — `success`, `status`, `responseText`, `action` (request/response)
- [ ] `HeartbeatEvent` — `location`
- [ ] `HeadlessEvent` — `name`, `event` (dynamic payload)
- [ ] `Sensors` — `platform`, `accelerometer`, `gyroscope`, `magnetometer`, `significantMotion`
- [ ] `DeviceInfo` — `model`, `manufacturer`, `version`, `platform`, `framework`
- [ ] `ConnectivityChangeEvent` — `connected`
- [ ] `AuthorizationEvent` — `success`, `status`, `response`
- [ ] `PermissionRationale` — `title`, `message`, `positiveAction`, `negativeAction`
- [ ] `SQLQuery` — `start`, `end`, `limit`, `order`
- [ ] Write unit tests for all model `toMap`/`fromMap` round-trips

### 1.3 Public API — `Tracelet` Class
- [ ] **Lifecycle methods**
  - [ ] `ready(Config config)` → `Future<State>`
  - [ ] `start()` → `Future<State>`
  - [ ] `stop()` → `Future<State>`
  - [ ] `startGeofences()` → `Future<State>`
  - [ ] `getState()` → `Future<State>`
  - [ ] `setConfig(Config config)` → `Future<State>`
  - [ ] `reset([Config? config])` → `Future<State>`
- [ ] **Location methods**
  - [ ] `getCurrentPosition({options})` → `Future<Location>`
  - [ ] `watchPosition({options, callback})` → `Future<int>` (watchId)
  - [ ] `stopWatchPosition(int watchId)` → `Future<bool>`
  - [ ] `changePace(bool isMoving)` → `Future<bool>`
  - [ ] `getOdometer()` → `Future<double>`
  - [ ] `setOdometer(double value)` → `Future<Location>`
- [ ] **Geofencing methods**
  - [ ] `addGeofence(Geofence)` → `Future<bool>`
  - [ ] `addGeofences(List<Geofence>)` → `Future<bool>`
  - [ ] `removeGeofence(String identifier)` → `Future<bool>`
  - [ ] `removeGeofences()` → `Future<bool>`
  - [ ] `getGeofences()` → `Future<List<Geofence>>`
  - [ ] `getGeofence(String identifier)` → `Future<Geofence?>`
  - [ ] `geofenceExists(String identifier)` → `Future<bool>`
- [ ] **Persistence methods**
  - [ ] `getLocations([SQLQuery? query])` → `Future<List<Location>>`
  - [ ] `getCount()` → `Future<int>`
  - [ ] `destroyLocations()` → `Future<bool>`
  - [ ] `destroyLocation(String uuid)` → `Future<bool>`
  - [ ] `insertLocation(Map params)` → `Future<String>` (uuid)
- [ ] **HTTP sync methods**
  - [ ] `sync()` → `Future<List<Location>>`
- [ ] **Utility methods**
  - [ ] `get isPowerSaveMode` → `Future<bool>`
  - [ ] `requestPermission()` → `Future<int>`
  - [ ] `requestTemporaryFullAccuracy(String purpose)` → `Future<int>`
  - [ ] `getProviderState()` → `Future<ProviderChangeEvent>`
  - [ ] `getSensors()` → `Future<Sensors>`
  - [ ] `getDeviceInfo()` → `Future<DeviceInfo>`
  - [ ] `playSound(String name)` → `Future<bool>`
  - [ ] `isIgnoringBatteryOptimizations()` → `Future<bool>` (Android only)
  - [ ] `requestSettings(String action)` → `Future<bool>`
  - [ ] `showSettings(String action)` → `Future<bool>`
- [ ] **Background task methods**
  - [ ] `startBackgroundTask()` → `Future<int>` (taskId)
  - [ ] `stopBackgroundTask(int taskId)` → `Future<int>`
- [ ] **Logging methods**
  - [ ] `getLog([SQLQuery? query])` → `Future<String>`
  - [ ] `destroyLog()` → `Future<bool>`
  - [ ] `emailLog(String email)` → `Future<bool>`
  - [ ] `log(String level, String message)` → `Future<bool>`
- [ ] **Scheduling methods**
  - [ ] `startSchedule()` → `Future<State>`
  - [ ] `stopSchedule()` → `Future<State>`
- [ ] **Headless registration**
  - [ ] `registerHeadlessTask(void Function(HeadlessEvent) callback)` → `Future<bool>`

### 1.4 Event Stream Subscriptions
- [ ] `onLocation(void Function(Location))` — every recorded location
- [ ] `onMotionChange(void Function(Location))` — stationary↔moving transitions
- [ ] `onActivityChange(void Function(ActivityChangeEvent))` — activity type changes
- [ ] `onProviderChange(void Function(ProviderChangeEvent))` — GPS/network/auth changes
- [ ] `onGeofence(void Function(GeofenceEvent))` — enter/exit/dwell events
- [ ] `onGeofencesChange(void Function(GeofencesChangeEvent))` — activated/deactivated geofences
- [ ] `onHeartbeat(void Function(HeartbeatEvent))` — periodic heartbeat with location
- [ ] `onHttp(void Function(HttpEvent))` — HTTP sync success/failure
- [ ] `onSchedule(void Function(State))` — schedule start/stop transitions
- [ ] `onPowerSaveChange(void Function(bool))` — power-save mode toggles
- [ ] `onConnectivityChange(void Function(ConnectivityChangeEvent))` — online/offline
- [ ] `onEnabledChange(void Function(bool))` — tracking enabled/disabled
- [ ] `onNotificationAction(void Function(String))` — notification button taps (Android)
- [ ] `onAuthorization(void Function(AuthorizationEvent))` — HTTP auth events
- [ ] Implement automatic stream lifecycle management (subscribe on listen, cancel on dispose)

---

## Phase 2 — Platform Interface (`packages/tracelet_platform_interface/`)

### 2.1 Abstract Platform Class
- [ ] Create `TraceletPlatform extends PlatformInterface`
- [ ] Define all methods from Phase 1.3 as stubs throwing `UnimplementedError`
- [ ] Add `static TraceletPlatform _instance` with getter/setter
- [ ] Add `verifyToken()` for platform registration security
- [ ] Write unit test asserting all methods throw `UnimplementedError` by default

### 2.2 Method Channel Implementation (Default)
- [ ] Create `MethodChannelTracelet extends TraceletPlatform`
- [ ] Implement all methods using `MethodChannel` invocations
- [ ] Implement all EventChannel stream subscriptions
- [ ] Register as default platform instance

### 2.3 Pigeon API Definition & Generation
- [ ] Define all `@HostApi()` methods with Pigeon-typed parameters and return types
- [ ] Define `@FlutterApi()` for headless event dispatch
- [ ] Define all Pigeon message classes (mirrors of Dart models — simpler/flat)
- [ ] Generate Kotlin output → `tracelet_android/android/src/main/kotlin/.../generated/`
- [ ] Generate Swift output → `tracelet_ios/ios/Classes/generated/`
- [ ] Verify compilation on both platforms

---

## Phase 3 — Android Implementation (`packages/tracelet_android/`)

### 3.1 Plugin Entry Point & Channel Registration
- [ ] `TraceletPlugin.kt` implementing `FlutterPlugin`, `ActivityAware`
- [ ] `onAttachedToEngine()` → register Pigeon HostApi + 14 EventChannel StreamHandlers
- [ ] `onDetachedFromEngine()` → tear down channels and handlers
- [ ] `onAttachedToActivity()` → store Activity reference, init location manager
- [ ] `onDetachedFromActivity()` → release Activity reference
- [ ] Handle `onDetachedFromActivityForConfigChanges` / `onReattachedToActivityForConfigChanges`

### 3.2 Android Manifest & Permissions
- [ ] Declare permissions in library `AndroidManifest.xml`:
  - [ ] `ACCESS_FINE_LOCATION`
  - [ ] `ACCESS_COARSE_LOCATION`
  - [ ] `ACCESS_BACKGROUND_LOCATION`
  - [ ] `FOREGROUND_SERVICE`
  - [ ] `FOREGROUND_SERVICE_LOCATION`
  - [ ] `ACTIVITY_RECOGNITION`
  - [ ] `RECEIVE_BOOT_COMPLETED`
  - [ ] `ACCESS_NETWORK_STATE`
  - [ ] `INTERNET`
  - [ ] `WAKE_LOCK`
- [ ] Declare foreground service with `android:foregroundServiceType="location"`
- [ ] Declare `BootCompletedReceiver`
- [ ] Declare `GeofenceBroadcastReceiver`
- [ ] Add `proguard-rules.pro` to preserve plugin classes

### 3.3 Configuration & State Management
- [ ] `ConfigManager.kt` — persist config to `SharedPreferences` (JSON serialized)
- [ ] `StateManager.kt` — track enabled/disabled, trackingMode, odometer, schedulerEnabled
- [ ] `ready()` implementation: merge user config with defaults → persist → return State
- [ ] `setConfig()` implementation: merge partial updates → restart services if needed
- [ ] `reset()` implementation: restore defaults → optionally apply new config
- [ ] Config change diffing: detect which subsystems need restart (location, geofence, http, etc.)

### 3.4 Location Engine
- [ ] `LocationEngine.kt` — wrapper around `FusedLocationProviderClient`
  - [ ] `start()` → `requestLocationUpdates()` with `LocationRequest.Builder`
  - [ ] `stop()` → `removeLocationUpdates()`
  - [ ] `getCurrentPosition()` → one-shot with timeout and accuracy options
  - [ ] `watchPosition()` → interval-based updates with separate `LocationCallback`
  - [ ] `stopWatchPosition()` → cancel watch callback
  - [ ] `changePace(isMoving)` → toggle between high-frequency and off
- [ ] Configure `LocationRequest` from `GeoConfig`:
  - [ ] `setPriority()` from `desiredAccuracy`
  - [ ] `setMinUpdateDistanceMeters()` from `distanceFilter`
  - [ ] `setIntervalMillis()` from `locationUpdateInterval`
  - [ ] `setMaxUpdateDelayMillis()` for batching
- [ ] Location result processing:
  - [ ] Generate UUID for each location
  - [ ] Calculate odometer delta
  - [ ] Attach activity type and battery state
  - [ ] Check `distanceFilter` threshold before recording
  - [ ] Persist to SQLite
  - [ ] Dispatch to EventChannel (`events/location`)

### 3.5 Foreground Service
- [ ] `TraceletForegroundService.kt` extending `Service`
  - [ ] `startForeground()` with `FOREGROUND_SERVICE_TYPE_LOCATION` (Android 14+ compliant)
  - [ ] Create `NotificationChannel` (Android 8+)
  - [ ] Build persistent notification with configurable title/text/icon/actions
  - [ ] Handle notification action button clicks → dispatch `onNotificationAction`
  - [ ] Bind to `LocationEngine` lifecycle
- [ ] Service start/stop tied to `Tracelet.start()` / `Tracelet.stop()`
- [ ] Handle `stopOnTerminate: false` — keep service running after app UI killed
- [ ] Handle task removal (`onTaskRemoved`) — restart if `stopOnTerminate: false`

### 3.6 Motion Detection Engine
- [ ] `MotionDetector.kt`
  - [ ] Register `ActivityTransitionRequest` for STILL, WALKING, RUNNING, IN_VEHICLE, ON_BICYCLE, ON_FOOT
  - [ ] `BroadcastReceiver` for `ActivityTransitionResult`
  - [ ] On STILL detected → start `stopTimeout` countdown (configurable minutes)
  - [ ] On `stopTimeout` elapsed → declare STATIONARY:
    - [ ] Fire `onMotionChange(location, isMoving=false)` via EventChannel
    - [ ] Stop `LocationEngine` updates (conserve battery)
    - [ ] Start low-power accelerometer monitoring via `SensorManager`
  - [ ] On accelerometer motion threshold exceeded → declare MOVING:
    - [ ] Fire `onMotionChange(location, isMoving=true)` via EventChannel
    - [ ] Restart `LocationEngine` updates
  - [ ] Fire `onActivityChange(ActivityChangeEvent)` on every activity transition
- [ ] `SensorFusionManager.kt` — accelerometer/gyroscope shake detection for stationary→moving
- [ ] `getSensors()` implementation: query `SensorManager` for available hardware

### 3.7 Geofencing Engine
- [ ] `GeofenceManager.kt`
  - [ ] `addGeofence()` → build `Geofence` via `Geofence.Builder`, add to `GeofencingClient`
  - [ ] `addGeofences()` → batch add up to 100
  - [ ] `removeGeofence()` → `GeofencingClient.removeGeofences()`
  - [ ] `removeGeofences()` → remove all
  - [ ] `getGeofences()` → query from SQLite persistence
  - [ ] `getGeofence()` → query single by identifier
  - [ ] `geofenceExists()` → check SQLite
- [ ] `GeofenceBroadcastReceiver.kt`
  - [ ] Receive `GeofencingEvent.fromIntent(intent)`
  - [ ] Extract transition type (ENTER/EXIT/DWELL), geofence identifiers
  - [ ] Get current location from event
  - [ ] Fire `onGeofence(GeofenceEvent)` via EventChannel
  - [ ] Fire `onGeofencesChange(on, off)` with activated/deactivated lists
- [ ] `GeofenceStore.kt` — SQLite CRUD for geofence definitions
  - [ ] Persist all registered geofences (survive process kill)
  - [ ] Re-register all active geofences on boot / service restart
- [ ] Proximity-based monitoring: only register geofences within `geofenceProximityRadius` of current location
- [ ] `geofenceModeKnockOut` support: remove geofences after first trigger

### 3.8 SQLite Persistence Layer
- [ ] `TraceletDatabase.kt` — Room database with migrations
  - [ ] `LocationEntity` — all location fields + `synced` flag + `created_at`
  - [ ] `GeofenceEntity` — all geofence config fields
  - [ ] `LogEntry` — timestamp, level, message, tag
- [ ] `LocationDao.kt`
  - [ ] `insert(location)` → returns UUID
  - [ ] `getAll(limit, offset, order)` → paginated
  - [ ] `getUnsyncedLocations(batchSize)` → for HTTP sync
  - [ ] `getCount()` → total count
  - [ ] `markSynced(uuids: List<String>)`
  - [ ] `deleteAll()`
  - [ ] `deleteByUuid(uuid)`
- [ ] `GeofenceDao.kt` — CRUD for stored geofences
- [ ] `LogDao.kt` — insert, query (with date range + level filter), delete, prune old
- [ ] Database migration strategy: room auto-migrations + manual for breaking changes

### 3.9 HTTP Sync Engine
- [ ] `HttpSyncManager.kt`
  - [ ] Accept `HttpConfig` to configure all behavior
  - [ ] `sync()` → manual one-shot sync
  - [ ] `autoSync()` → triggered after each location insert if `autoSync: true`
  - [ ] Check `autoSyncThreshold` before syncing
  - [ ] Build request body: JSON array of location objects under `httpRootProperty`
  - [ ] Attach configured `headers` (auth tokens, custom)
  - [ ] Support `POST` and `PUT` methods
  - [ ] Configurable `httpTimeout`
- [ ] Use OkHttp (`okhttp3`) as HTTP client
  - [ ] GZIP request body compression for batches
  - [ ] `ConnectivityManager.NetworkCallback` to detect online/offline
  - [ ] On connectivity restored → trigger deferred sync
- [ ] Retry with exponential backoff
  - [ ] Base: 1s, max: 5min, max retries: 10
  - [ ] Jitter: ±25% randomization
  - [ ] Classify failures: transient (5xx/timeout) → retry; permanent (4xx) → log + skip
- [ ] Fire `onHttp(HttpEvent)` for every request (success or failure)
- [ ] On success: mark synced locations in SQLite via `markSynced()`
- [ ] `WorkManager` integration for guaranteed background sync
  - [ ] `PeriodicWorkRequest` as fallback (every 15 min)
  - [ ] `OneTimeWorkRequest` for immediate sync with constraints (network)

### 3.10 Headless Task Support
- [ ] `HeadlessTaskService.kt` — isolate runner
  - [ ] Store registration callback ID + dispatch callback ID in `SharedPreferences`
  - [ ] On background event with no UI FlutterEngine:
    - [ ] Create new `FlutterEngine` → `DartExecutor.executeDartCallback()`
    - [ ] Register `MethodChannel` for headless dispatch
    - [ ] Send `HeadlessEvent` (event name + JSON payload) to Dart callback
    - [ ] Await Dart completion signal → destroy FlutterEngine
  - [ ] Singleton FlutterEngine management (reuse if already running)
  - [ ] Thread-safe event queueing when engine is initializing
- [ ] Dart-side: `registerHeadlessTask()` stores callback handle via `PluginUtilities.getCallbackHandle()`

### 3.11 Boot Receiver & Start-on-Boot
- [ ] `BootCompletedReceiver.kt`
  - [ ] Receive `android.intent.action.BOOT_COMPLETED`
  - [ ] Read persisted config → check `startOnBoot: true`
  - [ ] Start `TraceletForegroundService`
  - [ ] Re-register geofences with `GeofencingClient`
  - [ ] Start `MotionDetector` activity recognition
- [ ] Test on Android 15 (location FGS from BOOT_COMPLETED is allowed)

### 3.12 Scheduling Engine
- [ ] `ScheduleManager.kt`
  - [ ] Parse schedule strings: `"1-7 09:00-17:00"` (dayOfWeek range + time range)
  - [ ] Support multiple schedule entries (array)
  - [ ] Use `AlarmManager.setExactAndAllowWhileIdle()` for precise start/stop
  - [ ] On schedule-start → call `Tracelet.start()`
  - [ ] On schedule-stop → call `Tracelet.stop()`
  - [ ] Fire `onSchedule(State)` on transitions
  - [ ] Persist schedule state → resume after reboot

### 3.13 Logging System
- [ ] `TraceletLogger.kt`
  - [ ] Write to Room `LogEntry` table
  - [ ] Support levels: OFF, ERROR, WARNING, INFO, DEBUG, VERBOSE
  - [ ] `getLog(query)` → return concatenated log string (filtered by date/level)
  - [ ] `emailLog(email)` → write log to temp file → `ACTION_SEND` intent
  - [ ] `destroyLog()` → clear all entries
  - [ ] `log(level, message)` → app-level log entry
  - [ ] Auto-prune entries older than `logMaxDays` (default 3)
  - [ ] Thread-safe write queue (background thread)

### 3.14 Debug Sound Effects
- [ ] `SoundManager.kt`
  - [ ] Bundle `.ogg` sound files in `src/main/res/raw/`:
    - [ ] `location_recorded.ogg`
    - [ ] `motion_change_true.ogg` (moving)
    - [ ] `motion_change_false.ogg` (stationary)
    - [ ] `geofence_enter.ogg`
    - [ ] `geofence_exit.ogg`
    - [ ] `geofence_dwell.ogg`
    - [ ] `http_success.ogg`
    - [ ] `http_failure.ogg`
  - [ ] Use `SoundPool` for low-latency playback
  - [ ] Only play when `LoggerConfig.debug == true`
  - [ ] `playSound(name)` public method for custom sounds
  - [ ] Strip sounds from release builds via Gradle task (reduce APK ~1.5MB)

### 3.15 Permission Handling
- [ ] `PermissionManager.kt`
  - [ ] Sequential permission flow:
    - [ ] 1. `ACCESS_FINE_LOCATION` (or COARSE)
    - [ ] 2. `ACCESS_BACKGROUND_LOCATION` (separate prompt, API 30+)
    - [ ] 3. `ACTIVITY_RECOGNITION` (API 29+)
  - [ ] Return status codes: 0=DENIED, 1=WHEN_IN_USE, 2=ALWAYS, 3=DENIED_FOREVER
  - [ ] `requestSettings("ignoreOptimizations")` → battery optimization whitelist prompt
  - [ ] `showSettings("location")` → open device location settings
  - [ ] `isIgnoringBatteryOptimizations()` → query `PowerManager`
  - [ ] `getProviderState()` → GPS enabled, network enabled, authorization status

### 3.16 Utility Methods
- [ ] Battery state: `BatteryManager` → level + isCharging
- [ ] `getDeviceInfo()` → `Build.MODEL`, `Build.MANUFACTURER`, `Build.VERSION.SDK_INT`
- [ ] `isPowerSaveMode()` → `PowerManager.isPowerSaveMode()`
- [ ] Odometer: persist cumulative distance in SharedPreferences
- [ ] Heartbeat: `Handler.postDelayed()` loop firing `onHeartbeat` at configurable interval

---

## Phase 4 — iOS Implementation (`packages/tracelet_ios/`)

### 4.1 Plugin Entry Point & Channel Registration
- [ ] `TraceletPlugin.swift` conforming to `FlutterPlugin`
  - [ ] `register(with registrar:)` → register Pigeon HostApi + 14 EventChannel StreamHandlers
  - [ ] Store `FlutterPluginRegistrar` reference
  - [ ] Create `TSLocationManager` (our internal manager) singleton
- [ ] `StreamHandler.swift` base class with `onListen` / `onCancel` overrides
- [ ] One `StreamHandler` subclass per event type (14 total)

### 4.2 Info.plist & Capabilities
- [ ] Document required `Info.plist` entries for consuming app:
  - [ ] `NSLocationWhenInUseUsageDescription`
  - [ ] `NSLocationAlwaysAndWhenInUseUsageDescription`
  - [ ] `NSMotionUsageDescription`
  - [ ] `UIBackgroundModes`: `location`, `fetch`, `processing`
  - [ ] `NSLocationTemporaryUsageDescriptionDictionary` (for temporary full accuracy)
  - [ ] `BGTaskSchedulerPermittedIdentifiers`
- [ ] Document required Capabilities: Background Modes → Location Updates

### 4.3 Configuration & State Management
- [ ] `ConfigManager.swift` — persist config to `UserDefaults` (JSON serialized)
- [ ] `StateManager.swift` — track enabled, trackingMode, odometer, schedulerEnabled
- [ ] `ready()`, `setConfig()`, `reset()` implementations mirroring Android

### 4.4 Location Engine
- [ ] `LocationEngine.swift` — wrapper around `CLLocationManager`
  - [ ] `requestAlwaysAuthorization()` on `ready()`
  - [ ] `allowsBackgroundLocationUpdates = true`
  - [ ] `showsBackgroundLocationIndicator = true`
  - [ ] `pausesLocationUpdatesAutomatically` from config
  - [ ] `activityType` from config (.fitness, .automotiveNavigation, .other)
  - [ ] `distanceFilter` from `GeoConfig.distanceFilter`
  - [ ] `desiredAccuracy` from `GeoConfig.desiredAccuracy`
- [ ] `startUpdatingLocation()` / `stopUpdatingLocation()`
- [ ] One-shot `requestLocation()` for `getCurrentPosition()`
- [ ] iOS 17+ integration:
  - [ ] Create `CLBackgroundActivitySession` for reliable background execution
  - [ ] Fallback: `startMonitoringSignificantLocationChanges()` for app relaunch after termination
- [ ] `CLLocationManagerDelegate` handling:
  - [ ] `didUpdateLocations` → process, persist, dispatch via EventChannel
  - [ ] `didFailWithError` → log and dispatch error
  - [ ] `locationManagerDidChangeAuthorization` → dispatch `onProviderChange`

### 4.5 Motion Detection Engine
- [ ] `MotionDetector.swift`
  - [ ] `CMMotionActivityManager.startActivityUpdates()` for real-time activity
  - [ ] Detect transitions: stationary ↔ walking/running/automotive/cycling
  - [ ] On stationary detection: start `stopTimeout` timer
    - [ ] After timeout → fire `onMotionChange(isMoving: false)` → stop `CLLocationManager`
    - [ ] Start `CMMotionManager` accelerometer updates (low-power shake detection)
  - [ ] On shake/motion detected → fire `onMotionChange(isMoving: true)` → restart location
  - [ ] Fire `onActivityChange` on every `CMMotionActivity` update
- [ ] `CMMotionActivityManager.isActivityAvailable()` check
- [ ] Fallback for devices without M-series coprocessor: use `CLLocationManager` `distanceFilter` only

### 4.6 Geofencing Engine
- [ ] `GeofenceManager.swift`
  - [ ] `CLLocationManager.startMonitoring(for: CLCircularRegion)`
  - [ ] **20-region limit workaround**: Nearest-20 algorithm
    - [ ] Store ALL registered geofences in SQLite
    - [ ] On each location update: calculate distance to all geofences
    - [ ] Monitor the 20 nearest
    - [ ] Swap monitored regions as device moves
    - [ ] Log swaps with `onGeofencesChange` event
  - [ ] iOS 17+ fallback: use `CLMonitor` with `CircularGeographicCondition`
  - [ ] Delegate callbacks:
    - [ ] `didEnterRegion` → dispatch `onGeofence(action: ENTER)`
    - [ ] `didExitRegion` → dispatch `onGeofence(action: EXIT)`
    - [ ] Dwell detection: start loitering timer on ENTER → DWELL after delay
  - [ ] Persist geofences in SQLite, re-register on app relaunch

### 4.7 SQLite Persistence Layer
- [ ] `TraceletDatabase.swift` — using raw SQLite3 C API (via Swift bridging) or GRDB
  - [ ] Same schema as Android: locations, geofences, logs tables
  - [ ] Same DAO methods: insert, query, count, delete, markSynced, prune
- [ ] Thread-safe database access (serial dispatch queue)
- [ ] Database file location: `Application Support/tracelet/tracelet.db`
- [ ] Migration support via schema versioning

### 4.8 HTTP Sync Engine
- [ ] `HttpSyncManager.swift`
  - [ ] Use `URLSession` with `URLSessionConfiguration.default` for foreground sync
  - [ ] Use `URLSessionConfiguration.background(withIdentifier:)` for background upload
    - [ ] Completes even after app suspension
  - [ ] Same batch, auto-sync, retry logic as Android (see 3.9)
  - [ ] `NWPathMonitor` for connectivity change detection
  - [ ] Fire `onHttp(HttpEvent)` for each request
  - [ ] GZIP compression via `URLRequest.setValue("gzip", forHTTPHeaderField: "Content-Encoding")`

### 4.9 Headless / Background Execution
- [ ] `HeadlessRunner.swift`
  - [ ] On significant-location-change app relaunch → check `launchOptions[.location]`
  - [ ] If headless callback registered:
    - [ ] Create `FlutterEngine`, call `run(withEntrypoint:)`
    - [ ] Dispatch `HeadlessEvent` via MethodChannel to Dart callback
  - [ ] `UIApplication.beginBackgroundTask()` — wrap short tasks (30s)
  - [ ] iOS 17+: `CLBackgroundActivitySession` for extended execution
  - [ ] `CLServiceSession` for maintaining authorization state
- [ ] Store callback info in `UserDefaults`

### 4.10 Scheduling, Sounds, Logging, Permissions
- [ ] `ScheduleManager.swift` — mirror Android with `Timer` / `DispatchSourceTimer`
- [ ] `SoundManager.swift` — `AudioServicesPlaySystemSound()` for debug sounds; bundle `.caf` files
- [ ] `TraceletLogger.swift` — SQLite log table, same interface as Android
  - [ ] `emailLog()` → `MFMailComposeViewController` with log attachment
- [ ] `PermissionManager.swift`:
  - [ ] `CLLocationManager.requestAlwaysAuthorization()`
  - [ ] `CLAccuracyAuthorization` handling (precise vs reduced)
  - [ ] `requestTemporaryFullAccuracyAuthorization(withPurposeKey:)` (iOS 14+)
  - [ ] Status codes: match Android enum (DENIED, WHEN_IN_USE, ALWAYS, DENIED_FOREVER)

### 4.11 Utility Methods
- [ ] Battery state: `UIDevice.current.batteryLevel` + `batteryState`
- [ ] `getDeviceInfo()`: `UIDevice.current.model`, `systemVersion`
- [ ] `isPowerSaveMode()`: `ProcessInfo.processInfo.isLowPowerModeEnabled`
- [ ] Heartbeat: `Timer.scheduledTimer` loop
- [ ] Odometer: persist in `UserDefaults`

---

## Phase 5 — Testing & Quality Assurance

### 5.1 Dart Unit Tests
- [ ] `tracelet/test/`
  - [ ] Config serialization round-trip tests (all 6 config sub-classes)
  - [ ] Model serialization round-trip tests (all 14+ models)
  - [ ] `Tracelet` API — mock platform, verify all methods delegate correctly
  - [ ] Event stream subscription/cancellation tests
  - [ ] Edge cases: null fields, empty lists, invalid values
- [ ] `tracelet_platform_interface/test/`
  - [ ] Verify all `TraceletPlatform` methods throw `UnimplementedError`
  - [ ] Verify platform registration token security
  - [ ] Test `MethodChannelTracelet` serialization
- [ ] Achieve **≥90% code coverage** on Dart packages

### 5.2 Android Unit Tests
- [ ] Room database tests (in-memory DB for `LocationDao`, `GeofenceDao`, `LogDao`)
- [ ] `ConfigManager` serialization tests
- [ ] `ScheduleManager` schedule parsing tests
- [ ] `HttpSyncManager` retry logic tests (mock OkHttp)
- [ ] `GeofenceManager` nearest-100 proximity filter tests
- [ ] `MotionDetector` state machine tests (mock activity events)
- [ ] `TraceletLogger` write/query/prune tests
- [ ] Use Robolectric where Android framework classes needed

### 5.3 iOS Unit Tests
- [ ] XCTest for `LocationEngine` delegate handling (mock `CLLocationManager`)
- [ ] `GeofenceManager` nearest-20 rotation algorithm tests
- [ ] `ConfigManager` persistence tests
- [ ] `ScheduleManager` parsing tests
- [ ] `HttpSyncManager` retry logic tests (mock `URLSession`)
- [ ] `TraceletDatabase` CRUD tests (in-memory SQLite)
- [ ] `MotionDetector` state machine tests

### 5.4 Integration Tests
- [ ] `tracelet/example/integration_test/`
  - [ ] Permission request flow (grant → verify status)
  - [ ] `ready()` → `start()` → verify `onLocation` fires
  - [ ] `changePace(true)` → verify location stream activates
  - [ ] `addGeofence()` → simulate entry → verify `onGeofence` fires
  - [ ] `getCurrentPosition()` → verify returns valid location
  - [ ] `insertLocation()` → `getLocations()` → verify persistence
  - [ ] `sync()` → verify HTTP request sent (mock server)
  - [ ] `stop()` → verify location stream stops
  - [ ] Start-on-boot verification (manual / scripted reboot test)
- [ ] Test matrix: Android API 26, 29, 33, 34, 35 × iOS 14, 16, 17, 18

### 5.5 Performance & Battery Tests
- [ ] 8-hour stationary test: measure battery drain (target <2%/hr)
- [ ] 1-hour active tracking test: measure battery drain (target <5%/hr)
- [ ] Memory profiling: no leaks over 24-hour background session
- [ ] SQLite performance: insert 100K locations, query/pagination speed
- [ ] HTTP sync: 10K location batch upload time and reliability
- [ ] Cold start time: plugin `ready()` call duration

### 5.6 CI / CD Pipeline
- [ ] GitHub Actions workflow: `test.yml`
  - [ ] `flutter analyze` on all packages
  - [ ] `flutter test --coverage` on all packages
  - [ ] Coverage gate: fail if below 90%
- [ ] GitHub Actions workflow: `build.yml`
  - [ ] Build Android AAR (debug + release)
  - [ ] Build iOS framework (debug + release)
  - [ ] Build example app APK + IPA
- [ ] GitHub Actions workflow: `publish.yml` (manual trigger)
  - [ ] `dart pub publish --dry-run` on all packages
  - [ ] Tag-based auto-publish to pub.dev
- [ ] Add status badges to README

---

## Phase 6 — Example App & Documentation

### 6.1 Example App (`tracelet/example/`)
- [ ] **Map View** (Google Maps or `flutter_map` + OpenStreetMap)
  - [ ] Real-time current location marker
  - [ ] Location trail polyline (recorded path)
  - [ ] Geofence circles on map (draggable radius)
  - [ ] Motion state indicator (moving/stationary icon)
  - [ ] Activity type badge (walking/running/driving/cycling)
- [ ] **Settings Screen**
  - [ ] All `GeoConfig` options with UI controls
  - [ ] All `AppConfig` options
  - [ ] All `HttpConfig` options
  - [ ] All `LoggerConfig` options
  - [ ] All `MotionConfig` options
  - [ ] All `GeofenceConfig` options
  - [ ] Apply / Reset buttons
- [ ] **Geofence Manager Screen**
  - [ ] List of active geofences
  - [ ] Add geofence (tap map or enter coords)
  - [ ] Remove geofence (swipe to delete)
  - [ ] Geofence event log
- [ ] **Events Log Screen**
  - [ ] Scrollable list of all events (location, motion, geofence, http, etc.)
  - [ ] Filter by event type
  - [ ] Tap to expand event details (JSON)
- [ ] **Sync Status Panel**
  - [ ] Pending location count
  - [ ] Last sync time
  - [ ] Manual "Sync Now" button
  - [ ] HTTP event log
- [ ] **Debug Log Viewer**
  - [ ] View plugin logs
  - [ ] Filter by log level
  - [ ] Email log button

### 6.2 Setup Documentation
- [ ] `help/INSTALL-ANDROID.md`
  - [ ] Gradle setup (minSdk, compileSdk, Kotlin version)
  - [ ] AndroidManifest.xml permissions checklist
  - [ ] proguard-rules.pro setup
  - [ ] Background location permission rationale best practices
  - [ ] Google Play policy compliance guidance
  - [ ] Troubleshooting common issues
- [ ] `help/INSTALL-IOS.md`
  - [ ] Info.plist entries checklist
  - [ ] Background Modes capability setup
  - [ ] Podfile configuration
  - [ ] App Store review guidelines for location apps
  - [ ] Troubleshooting common issues
- [ ] `help/MIGRATION-FROM-TRANSISTORSOFT.md`
  - [ ] API mapping table (transistorsoft method → Tracelet method)
  - [ ] Config key changes
  - [ ] Import changes
  - [ ] Breaking differences and workarounds

### 6.3 API Documentation
- [ ] Dartdoc comments on every public class, method, property, and enum value
- [ ] Code examples in dartdoc for every API method
- [ ] `dartdoc_options.yaml` configuration
- [ ] Generate and verify API docs locally
- [ ] Ensure pub.dev documentation score ≥ 110/130

### 6.4 Wiki & Conceptual Docs
- [ ] **Philosophy of Operation** — motion-detection intelligence explained
- [ ] **Debugging Guide** — how to read logs, common error patterns, sound FX guide
- [ ] **HTTP Server Setup** — example Node.js/Python server for receiving locations
- [ ] **Battery Optimization Guide** — per-manufacturer (Samsung, Xiaomi, Huawei, OnePlus) settings
- [ ] **FAQ** — common questions and answers

### 6.5 Repository Polish
- [ ] Root `README.md` with badges, feature list, quick-start code, screenshots
- [ ] `CHANGELOG.md` (keep-a-changelog format)
- [ ] `SECURITY.md` — vulnerability reporting instructions
- [ ] Issue templates: bug report, feature request
- [ ] PR template with checklist
- [ ] Add pub.dev topics: `geolocation`, `location`, `background`, `geofencing`

---

## Phase 7 — Advanced Features (Post-v1.0)

### 7.1 Trip Detection
- [x] Auto-detect trip start/end based on motion patterns *(v0.5.3 — shared Dart)*
- [x] `onTripStart` / `onTripEnd` events *(v0.5.3 — `onTrip()` API)*
- [x] Trip summary: distance, duration, route, start/end locations *(v0.5.3)*

### 7.2 Polygon Geofences
- [x] Support polygon vertices in `Geofence` model *(v0.5.3)*
- [x] Point-in-polygon algorithm for non-circular geofences *(v0.5.3 — shared Dart `GeoUtils.isPointInPolygon`)*
- [x] ~~Native polygon geofence rendering on Android (custom) and iOS (custom)~~ → Moved to shared Dart `GeofenceEvaluator` *(v0.6.0)*

### 7.3 Server-Side Geofence Sync
- [ ] Fetch geofences from remote API
- [ ] Auto-register/deregister based on server response
- [ ] Periodic geofence sync via HTTP

### 7.4 Web Platform Support
- [x] `packages/tracelet_web/` — using browser Geolocation API *(v0.5.0)*
- [x] Limited feature set (basic location, geofencing) *(v0.5.0)*
- [x] Location filtering and Kalman smoothing now work on web via shared Dart *(v0.6.0)*

### 7.5 Shared Dart Algorithm Migration (v0.6.0)
- [x] `KalmanLocationFilter` — shared Dart GPS smoothing (moved from native Kotlin/Swift)
- [x] `TripManager` — shared Dart trip detection (moved from native Kotlin/Swift)
- [x] `GeoUtils` — shared Dart haversine + point-in-polygon (moved from native)
- [x] `LocationProcessor` — shared Dart distance/elasticity/accuracy/speed filtering (NEW)
- [x] `GeofenceEvaluator` — shared Dart geofence proximity evaluation (NEW)
- [x] `ScheduleParser` — shared Dart schedule parsing (NEW)
- [x] `PersistDecider` — shared Dart persistence decision logic (NEW)
- [x] Remove duplicate native filtering code from Kotlin `LocationEngine` / `GeofenceManager`
- [x] Remove duplicate native filtering code from Swift `LocationEngine` / `GeofenceManager`
- [x] Fix broadcast stream bug — cached `.asBroadcastStream()` for stateful transformations
- [x] 86 algorithm unit tests (46 new + 40 existing)

### 7.7 Mock Location Detection & Prevention
- [x] `Location.isMock` field + serialization (all platforms)
- [x] `LocationFilter.rejectMockLocations` config — reject spoofed GPS
- [x] `MockDetectionLevel` enum — `disabled`, `basic`, `heuristic`
- [x] Android: `Location.isMock()` / `isFromMockProvider()`, satellite count, elapsed realtime drift
- [x] iOS: `CLLocationSourceInformation` (iOS 15+), timestamp drift heuristic
- [x] Web: `mock: false` passthrough (browser API has no detection)
- [x] Dart `LocationProcessor` — timestamp monotonicity check (all platforms)
- [x] `Location.mockHeuristics` — `MockHeuristics` metadata model
- [x] `ProviderChangeEvent.mockLocationsDetected` — alert for live detection
- [x] `help/MOCK-DETECTION.md` comprehensive documentation

### 7.8 OEM Compatibility (Android)
- [x] `OemCompat` utility — manufacturer detection (Huawei, Xiaomi, OnePlus, Samsung, Oppo, Vivo)
- [x] Aggression ratings (0–5 per dontkillmyapp.com)
- [x] Huawei PowerGenie wakelock tag hack (`LocationManagerService`)
- [x] Xiaomi autostart detection via `PackageManager.resolveActivity()`
- [x] OEM settings deep-links — 8 intents for 6 manufacturers
- [x] `Tracelet.getSettingsHealth()` — device health API
- [x] `Tracelet.openOemSettings(label)` — open OEM settings by label
- [x] OEM-safe wakelock lifecycle in `LocationService`
- [x] Boot receiver 60s wakelock during `BOOT_COMPLETED` processing
- [x] ProGuard/R8 consumer rules (`consumer-rules.pro`)
- [x] iOS/Web stubs (return `isAggressiveOem: false`)
- [x] `help/OEM-COMPATIBILITY.md` comprehensive guide

### 7.9 macOS / Windows / Linux
- [ ] `packages/tracelet_macos/` — CoreLocation on macOS (shared Darwin source with iOS)
- [ ] Windows/Linux via GNSS APIs (low priority)

### 7.10 Analytics Dashboard
- [ ] Open-source companion web dashboard (Vue.js / React)
- [ ] Real-time device tracking on map
- [ ] Historical route playback
- [ ] Geofence event timeline
- [ ] Device fleet overview

---

## Release Milestones

| Milestone | Target | Scope |
|---|---|---|
| **v0.1.0-alpha** | Phase 0 + 1 + 2 | Dart API complete, platform interface, no native code yet |
| **v0.5.0-beta** | + Phase 3 (Android) | Android fully functional (location, geofencing, sync, headless) |
| **v0.8.0-beta** | + Phase 4 (iOS) | iOS fully functional, feature parity with Android |
| **v0.9.0-rc** | + Phase 5 | Full test suite, CI/CD, battery benchmarks passed |
| **v1.0.0** | + Phase 6 | Example app, complete documentation, pub.dev published |
| **v1.x** | Phase 7 | Advanced features (trips, polygons, web, dashboard) |

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter App (Dart)                        │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                tracelet (app-facing)                   │  │
│  │  Tracelet.ready() / .start() / .onLocation() / ...    │  │
│  └───────────────────┬───────────────────────────────────┘  │
│                      │                                      │
│  ┌───────────────────▼───────────────────────────────────┐  │
│  │          tracelet_platform_interface                   │  │
│  │  TraceletPlatform (abstract) + Pigeon definitions     │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │         Shared Dart Algorithms (v0.6.0)         │  │  │
│  │  │  KalmanFilter · LocationProcessor · GeoUtils    │  │  │
│  │  │  GeofenceEvaluator · TripManager · ScheduleParser│ │  │
│  │  │  PersistDecider                                 │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └──────────┬──────────────┬─────────────┬──────────────┘  │
│             │              │             │                  │
│  ┌──────────▼────────┐ ┌───▼──────────┐ ┌▼──────────────┐  │
│  │ tracelet_android  │ │ tracelet_ios  │ │ tracelet_web  │  │
│  │ (Pigeon HostApi)  │ │(Pigeon HostApi)│ │(browser APIs) │  │
│  └──────────┬────────┘ └──────┬───────┘ └───────────────┘  │
└─────────────┼─────────────────┼─────────────────────────────┘
              │ Pigeon           │ Pigeon
┌─────────────▼──────────┐   ┌──▼────────────────────────────┐
│   Android Native (Kt)  │   │      iOS Native (Swift)       │
│ ┌────────────────────┐ │   │ ┌────────────────────────────┐│
│ │  ForegroundService │ │   │ │  CLLocationManager         ││
│ │  (TYPE_LOCATION)   │ │   │ │  + CLBackgroundActivity    ││
│ ├────────────────────┤ │   │ │    Session (iOS 17+)       ││
│ │  FusedLocation     │ │   │ ├────────────────────────────┤│
│ │  ProviderClient    │ │   │ │  CMMotionActivityManager   ││
│ ├────────────────────┤ │   │ ├────────────────────────────┤│
│ │  ActivityRecog-    │ │   │ │  CLCircularRegion /        ││
│ │  nitionClient      │ │   │ │  CLMonitor (iOS 17+)      ││
│ ├────────────────────┤ │   │ ├────────────────────────────┤│
│ │  GeofencingClient  │ │   │ │  URLSession (background)   ││
│ ├────────────────────┤ │   │ ├────────────────────────────┤│
│ │  Room SQLite DB    │ │   │ │  SQLite3 / GRDB            ││
│ ├────────────────────┤ │   │ ├────────────────────────────┤│
│ │  OkHttp + Work-    │ │   │ │  BGTaskScheduler           ││
│ │  Manager           │ │   │ │  + beginBackgroundTask     ││
│ ├────────────────────┤ │   │ ├────────────────────────────┤│
│ │  HeadlessTask      │ │   │ │  HeadlessRunner            ││
│ │  (FlutterEngine)   │ │   │ │  (FlutterEngine)           ││
│ └────────────────────┘ │   │ └────────────────────────────┘│
└────────────────────────┘   └───────────────────────────────┘
```

---

*Last updated: 2025-07-15*
*Status: v0.8.0 — OEM compatibility layer + Settings Health API*
