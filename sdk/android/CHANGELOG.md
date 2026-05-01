# Changelog

## 1.1.1

- **FIX**: `TraceletSdk.destroyAll()` now respects `stopOnTerminate: false` for continuous (mode 0) and geofence (mode 1) tracking modes (#63). `locationEngine.destroy()` was unconditionally called, racing with `LocationService.onTaskRemoved()` bootstrap. Mirrors the existing guards already in place for `PeriodicLocationWorker` and `GeofenceManager`.

## 1.1.0

- **FIX**: `LocationService.onStartCommand` now always calls `startForegroundWithNotification()` at the top, before dispatching on `intent?.action`. Previously only `ACTION_START` promoted the service to the foreground, so any other entry path (`ACTION_STOP`, `ACTION_UPDATE_NOTIFICATION`, `ACTION_BUTTON`, and — most importantly — null-intent sticky restarts after a system kill) would fail Android's foreground-service contract and crash the host app with `RemoteServiceException: Context.startForegroundService() did not then call Service.startForeground()` (#59). The promotion is idempotent, so calling it on every entry is safe. An explicit `null ->` branch was added to `when(intent?.action)` so START_STICKY restarts no longer fall through. Added Robolectric `LocationServiceForegroundContractTest` covering all 5 entry paths.

## 1.0.12

- **PERF**: `LocationEngine.changePace(true)` now fires an additional one-shot `getCurrentLocation()` on stationary → moving transitions, delivering a fresh GPS fix as soon as the hardware is warm without waiting for the `locationUpdateInterval` tick on the continuous stream. Reduces first-fix latency on motion start from 5–10s to ~1–5s (#54). The one-shot is guarded by a `CancellationTokenSource` that is cancelled on `stop()` and superseded on subsequent transitions to prevent late callbacks from firing after a stop.
- **FIX**: After a manual `Tracelet.changePace(false)` (force stationary), the SDK can now detect real motion and resume tracking automatically. Previously, MotionDetector's accelerometer + significant-motion listeners stayed torn down (because `declareMoving()` had stopped them and `declareStationary()` is never invoked from outside), leaving the SDK in a permanent dead-state where no future motion could wake it. `TraceletSdk.changePace()` now invokes a new `MotionDetector.onManualPaceChange()` hook that re-engages the wake-up sensors. iOS was unaffected because CMMotionActivityManager runs continuously at the kernel level.

## 1.0.11

- **FIX**: Geofence and location `extras` now round-trip through SQLite as a `Map` instead of a non-parseable `Map.toString()` representation. Previously, `extras` passed to `addGeofence()` were lost before reaching geofence callbacks (#51 follow-up). Location `extras` are now also included in the read-back location map (previously silently dropped).
- **FIX**: Geofence and location extras are serialized via `org.json.JSONObject` on write and parsed back on read, matching the iOS SDK format. Legacy rows with malformed extras are safely ignored.

## 1.0.10

- **FIX**: Killed-state tracking — `LocationService.stopBootTracking()` is no longer called during `TraceletSdk.initialize()`. Boot-mode LocationEngine and HttpSyncManager now survive until `ready()` is explicitly called, fixing the race where `onAttachedToEngine` destroyed boot tracking before Dart could take over (#50).

## 1.0.9

- **FEAT**: Add `getSyncInterval()` to `ConfigManager` and timer-based sync to `HttpSyncManager` (#50).

## 1.0.8

- **FIX**: `cursorToLocation()` now uses canonical `is_moving` (snake_case) instead of `isMoving` (camelCase) — HTTP sync payload now matches iOS format (#48).
- **FIX**: `cursorToLocation()` now returns ISO 8601 timestamp string instead of numeric epoch milliseconds.
- **FIX**: `insertLocation()` now accepts both `is_moving` and `isMoving` keys for backward compatibility.
- **FIX**: `enrichLocation()`, `buildLocationMap()`, `onDrLocationEstimated()` now use canonical `is_moving` key.
- **FIX**: Audit trail `appendToChain()` and `verifyChain()` accept both `is_moving` and `isMoving` for hash computation.

## 1.0.7

- **CHORE**: Re-release — 1.0.6 was published alongside partially-released Flutter packages.

## 1.0.6

- **FIX**: `getCurrentPosition(samples: 1)` routes through `collectSamples` using `requestLocationUpdates` instead of `FusedLocationProviderClient.getCurrentLocation()` — forces a fresh GPS fix with proper timeout instead of returning stale cached locations (#46).
- **PERF**: Remove per-batch `onRequestFreshHeaders` invocation from `HttpSyncManager.sendBatch()` — eliminates unnecessary callback overhead on every sync request. Token refresh is handled reactively via `onAuthorizationRequired` on 401.
- **FIX**: Relax `isReady` guards to `::manager.isInitialized` for privacy zones, audit trail, and encryption — these features only need DB init, not active tracking.

## 1.0.5

- **FIX**: `getCurrentPosition()` / `collectSamples()` fall back to last known location when `FusedLocationProviderClient.getCurrentLocation()` returns null — fixes `LOCATION_UNAVAILABLE` on emulators and GPS-off devices (#46).
- **FIX**: Add public `clearPendingPermissionCallback()` — resolves cross-module `internal` visibility error from Flutter plugin.

## 1.0.4

- **FIX**: Add `isReady` guards to all SDK methods — prevents `UninitializedPropertyAccessException` when methods like `getState()`, `getCurrentPosition()`, geofence, persistence, sync, logging, scheduling, enterprise methods are called before `ready()` (re-fixes #46).

## 1.0.3

- **FIX**: Add `isReady` guards to all SDK methods — prevents `UninitializedPropertyAccessException` when methods like `getState()`, `getCurrentPosition()`, geofence, persistence, sync, logging, scheduling, enterprise methods are called before `ready()` (re-fixes #46).

## 1.0.2

- **FIX**: Guard `soundManager` access in `handleMotionStateChange()` and `destroyAll()` — prevents `UninitializedPropertyAccessException` when motion detector fires before full SDK initialization (fixes #41).
- **FIX**: Add `isReady` guard to `stop()` — prevents crash when `stop()` is called before `ready()` (fixes #46).
- **FIX**: Use `LocationManagerCompat.isLocationEnabled()` instead of `LocationManager.isLocationEnabled()` — fixes `NoSuchMethodError` crash on Android API 26/27 (fixes #47).
- **FIX**: `DeviceAttestor` now checks Play Integrity availability at runtime via `Class.forName` — prevents `NoClassDefFoundError` when `com.google.android.play:integrity` is not on the classpath. Uses lazy initialization for `IntegrityManagerFactory`.
- **FIX**: `DatabaseEncryptionManager` now checks `androidx.security:security-crypto` availability at runtime — `isDatabaseEncrypted()` returns `false` and `getDatabasePassword()` returns empty array when the library is absent.
- **FIX**: `TraceletSdk.ready()` checks `SqlCipherMigrator.isAvailable()` before attempting database encryption — logs a warning with setup instructions when SQLCipher is absent instead of crashing.
- **FIX**: `TraceletDatabase.encryptDatabase()` throws `IllegalStateException` with clear setup instructions if SQLCipher dependency is missing.
- **REFACTOR**: Extracted SQLCipher migration to `SqlCipherMigrator` class — cleaner separation, testable independently.
- **REFACTOR**: Refined ProGuard consumer rules — narrower keep rules, added `-dontwarn` for optional enterprise dependencies.
- **TEST**: Add `destroyAll_doesNotCrash_withoutSoundManager` unit test.
- **TEST**: Add `DeviceAttestor` and `SqlCipherMigrator` availability tests.

## 1.0.1

- Initial release on Maven Central.
