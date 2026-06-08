## 3.2.8

- **FIX**: Persist geofence ENTER/EXIT events in offline queue and auto-sync to server — events were previously dispatched to the app but never stored in the local SQLite database (Issue #128).
- **FIX**: Structured event envelope (`event_type`, `event_payload`) for geofence events round-trips correctly through `getLocations()` and `insertLocation()`.
- **FIX**(sync): Stop POSTing malformed error payloads on failed HTTP sync requests; fix iOS custom-body deadlock in `setSyncBodyBuilder` (Issue #125).
- **FIX**(android): Throw `NOT_READY` error before `ready()` is called to match iOS parity; previously Android silently ignored SDK calls before initialization (Issue #129).
- **FIX**(ios): Resolve `flutter_rust_bridge has not been initialized` on release builds — `TraceletCore` is now a dynamic framework, preventing dead-code stripping of FRB symbols (Issues #116, #123, #124).
- **FIX**(android): Resolve `Failed to lookup symbol 'frb_get_rust_content_hash'` — Rust symbols are now loaded directly from `libtracelet_core.so` bypassing `RTLD_LOCAL` isolation (Issues #116, #123).
- **PERF**(ios): Reduce background motion sensor CPU/battery usage — accelerometer polling is now paused when stationary (Issue #130).
- **FIX**: Persist historical `is_moving` state per location record so `getLocations()` returns accurate values instead of always returning the current live state (Issue #126).

## 3.2.7

- **FIX**(ios): prevent dead code stripping of flutter_rust_bridge symbols in release builds.
- **FIX**(android): implement OEM hardening mitigations and introduce `showPowerManager` to handle aggressive battery restrictions on specific OEM devices.

## 3.2.6

- **PERF**: Optimize database timestamp queries for O(log N) fast filtering and resolve precision bugs (Issue #119).
- **FEAT**: Implement `sslPinningFingerprints` natively across iOS and Android with Rust configs.
- **FIX**: Include pinned fingerprints in SSL verification error logs and messages.
- **FIX**: Rate limit Android MotionDetector logcat flooding during stillness (Issue #121).
- **FIX**: Resolve race conditions in tests for Issue 118.
- **REFACTOR**: Update integration test to use Config.fromMap for comprehensive Tracelet configuration testing.

## 3.2.5
- **FIX**: Resolved iOS accelerometer sensitivity mismatch (stationary lock) by normalizing incoming m/s² thresholds to g-force expected by CMMotionManager.
- **FIX**: Unify motion detection initial state and resume behavior across Android and iOS, preventing incorrect forced states on app launch and correctly resuming saved states.
- **FIX**: Resolved `flutter_rust_bridge` dynamic library load failures on release builds for users without `use_frameworks!` by preserving global symbols during Xcode stripping.

## 3.2.3

- **FIX**: Force speed motion manager to evaluate initial speed on Android to prevent the state machine from being permanently stuck in `MOVING` when indoors ([#115](https://github.com/Ikolvi/Tracelet/issues/115)).
- **FIX**: Resolve `flutter_rust_bridge has not been initialized` crash by ensuring the Rust core is instantiated and initialized before accessing methods ([#116](https://github.com/Ikolvi/Tracelet/issues/116)).
- **CHORE**: Sync release versions across all packages.

## 3.2.2

- **CHORE**: Sync release versions across all federated packages and update Swift Package Manager configuration.

## 3.2.1

- **CHORE**: Align federated package versions and include additional patch updates.

## 3.1.8

- Fix iOS SPM publishing

## 3.1.7

 - **FIX**(android): apply kotlin-android plugin to fix gradle build errors on newer AGP versions.
 - **FIX**(ios): fix SPM source folder paths in release bundling to ensure SDK compiles properly via CocoaPods.
 - **FIX**(ios): fix duplicate module import errors by adding conditional import checks for TraceletSDK.

## 3.1.4

- **CHORE**: Sync release versions across workspace.

# Changelog

## 3.2.1

- **CHORE**: Align federated package versions and include additional patch updates.

## 2026-05-31

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`tracelet` - `v3.2.0`](#tracelet---v320)
 - [`tracelet_platform_interface` - `v3.2.0`](#tracelet_platform_interface---v320)
 - [`tracelet_android` - `v3.2.0`](#tracelet_android---v320)
 - [`tracelet_ios` - `v3.2.0`](#tracelet_ios---v320)
 - [`tracelet_web` - `v3.2.0`](#tracelet_web---v320)
 - [`tracelet_doctor` - `v3.2.0`](#tracelet_doctor---v320)
 - [`tracelet_firebase` - `v3.2.0`](#tracelet_firebase---v320)
 - [`tracelet_supabase` - `v3.2.0`](#tracelet_supabase---v320)

---

#### `tracelet` - `v3.2.0`

 - **FEAT**: Implement short-lived WakeLocks for transient background tasks (`startBackgroundTask` / `stopBackgroundTask`), improving background execution reliability on Android (matches iOS `beginBackgroundTask`).
 - **FEAT**: The SQLCipher dependency is no longer required for database encryption (Tracelet Core now natively uses AES-GCM in Rust, reducing APK size by ~16MB).
 - **FEAT**: HTTP sync logic has been moved to the `tracelet_sync` module, which must now be included if you require network synchronization.
 - **FEAT**: Add reverse geocoding functionality. ([0fe7b89a](https://github.com/Ikolvi/Tracelet/commit/0fe7b89aad0e22ea28cf81dd81723a534300c175))

#### `tracelet_platform_interface` - `v3.2.0`

 - **FIX**(web): safe BigInt to int casting for rust bridge 64-bit integers. ([2e592b34](https://github.com/Ikolvi/Tracelet/commit/2e592b344ecc242d03e3c4f840d1f1380d6fecd0))
 - **FEAT**: Add reverse geocoding functionality. ([0fe7b89a](https://github.com/Ikolvi/Tracelet/commit/0fe7b89aad0e22ea28cf81dd81723a534300c175))

#### `tracelet_android` - `v3.2.0`

 - **FEAT**: Add reverse geocoding functionality. ([0fe7b89a](https://github.com/Ikolvi/Tracelet/commit/0fe7b89aad0e22ea28cf81dd81723a534300c175))

#### `tracelet_ios` - `v3.2.0`

 - **FEAT**: Add reverse geocoding functionality. ([0fe7b89a](https://github.com/Ikolvi/Tracelet/commit/0fe7b89aad0e22ea28cf81dd81723a534300c175))

#### `tracelet_web` - `v3.2.0`

#### `tracelet_doctor` - `v3.2.0`

#### `tracelet_firebase` - `v3.2.0`

#### `tracelet_supabase` - `v3.2.0`

## 3.0.1

- **CHORE**: Version bump for monorepo consistency with Flutter plugins (resolves SPM FlutterFramework missing dependency in wrapper).

## 3.0.0

- **FEAT**: Massive Architecture Rewrite — Core algorithms are now powered by a high-performance **Rust Core** using `flutter_rust_bridge`.
- **FEAT**: Smart Motion Mode — Introduced `MotionDetectionMode.smart` powered by the Rust battery budget engine.

## 2.1.0

- **CHORE**: Major release synchronized with Tracelet Flutter 2.1.0.
- **FEAT**: Smart foreground notification visibility — dynamically manages foreground service UI to hide the notification when the app is foregrounded and show it automatically in the background.
- **FEAT**: Implemented `SpeedMotionManager` for the new `tl.MotionDetectionMode.speed` tracking mode, bypassing raw accelerometer triggers and exclusively using GPS speed variations for motion state transitions.
- **FIX**: Prevented a critical logic flaw where the accelerometer was completely shut down during the `stopTimeout` countdown. Motion (e.g., hitting a pothole) during the countdown now correctly aborts the stationary transition (#85).
- **FIX**: Corrected `retryBackoffCap` backoff interval parsing from seconds to milliseconds, fixing an issue where HTTP sync retries fired continuously and exhausted CPU/network resources.
- **FIX**: Prevented `LocationEngine.stop` from unintentionally clobbering the global `stateManager.enabled` flag when transitioning into stationary states in speed mode.
- **REFACTOR**: Transitioned all string-based config values to type-safe Enums across the platform bridge.

## 2.0.7

- **FIX**: Resolved `UnsatisfiedLinkError` crash when optional SQLCipher dependency was added by explicitly loading the `sqlcipher` JNI library before creating the encrypted database ([#78](https://github.com/Ikolvi/Tracelet/issues/78)).
- **FIX**: Prevented false-positive shake events on Android by applying absolute magnitude thresholds (`Math.abs(magnitude)`) to align with iOS behavior, and fixed an edge case where a `stopTimeout` of 0 would skip the stillness transition entirely ([#79](https://github.com/Ikolvi/Tracelet/issues/79)).
- **FIX**: Resolved an issue where Android could get permanently stuck in the `moving` state in full mode if the device was woken up via the shake detector, by enabling accelerometer stillness detection as a continuous fallback even when Activity Recognition is active.

## 2.0.6

- **PERF**: Implemented hardware-level sensor batching (`maxReportLatencyUs`) on accelerometer registration (3s for shake, 5s for stillness) reducing CPU wake-ups by over 90% during active tracking.
- **FEAT**: Added graceful fallback to `TYPE_SIGNIFICANT_MOTION` hardware sensor when `TYPE_ACCELEROMETER` is unavailable.
- **FIX**: Dispatched explicit permission-missing `providerChange` events on `start()` call when location permissions are absent.

## 2.0.5

- **CHORE**: Bump version to 2.0.5 to align with federated Flutter packages and coordinated monorepo release.

## 2.0.3

- **FIX**: Refined Android elapsed realtime drift mock detection check. Age comparisons are now verified between wall-clock time and monotonic system clock to avoid false positives under network clock drift.

## 2.0.2

- **FIX**: `deferTime` is now accounted for in the heuristic mock detection drift calculation. Deferred locations are no longer incorrectly flagged as mock locations.

## 2.0.0

- **CHORE**: Major release synchronized with Tracelet Flutter 2.0.0.
- **FEAT**: Added `shakeThreshold`, `stillThreshold`, and `stillSampleCount` to `MotionConfig` for granular accelerometer tuning.
- **REFACTOR**: Core SDK now supports an "on-demand" dependency model. GMS Location, SQLCipher, and Play Integrity are no longer hard dependencies and are resolved via reflection at runtime.
- **CHORE**: Aligned versioning across the entire Tracelet monorepo.

## 1.1.4

- **CHORE**: Aligned repository podspec files and updated release documentation.
- **CHORE**: Maintenance release to sync native SDK versions.

## 1.1.3

- **CHORE**: Version bump for monorepo consistency.

## 1.1.2

- **FIX**: `destroyAll()` now guards **all** background-critical subsystems behind `stopOnTerminate: false`, not just `locationEngine` and `geofenceManager` (#65). `httpSyncManager.stop()`, `scheduleManager.stop()`, and `stopHeartbeat()` were still called unconditionally on every swipe-to-dismiss, killing HTTP sync, scheduled tasks, and heartbeat monitoring even when background tracking should survive. Uses a unified `keepAlive` flag derived from `!stopOnTerminate && stateManager.enabled`.

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

- **CHORE**: Sync release versions with Flutter package updates.

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
