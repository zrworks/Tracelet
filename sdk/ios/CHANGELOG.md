## 3.2.15

* **FIX**: Allow `getState()` and `stop()` to be called before `ready()` is invoked, correctly reporting persistent state and shutting down background services if the app was restarted from a killed state.

## 3.2.13

- **CHORE**: Version bump to 3.2.13 to stay in lockstep with the federated set (Android `startOnBoot` reboot-tracking fix — see `tracelet_android`). No changes to this package.

## 3.2.12

- **CHORE**: Re-release to align the iOS SDK podspec with the federated package set at 3.2.12. The podspec version had drifted behind (3.2.9) during the 3.2.11 release; this realigns it. No functional code changes.

## 3.2.10

- **FIX**(ios): Remove `TraceletCore+Dummy.swift` / `TraceletSyncFFI+Dummy.swift` — `@_silgen_name` declarations from the old static library model caused "Undefined symbol" linker errors after the static→dynamic xcframework migration.
- **FIX**(android): Catch `ForegroundServiceStartNotAllowedException` in `LocationService.start()` so calling `ready()` from the background on Android 12+ no longer crashes the host app; the foreground service start is deferred until the app returns to foreground.


## 3.2.9

- **FIX**(ios): Remove `TraceletCore+Dummy.swift` / `TraceletSyncFFI+Dummy.swift` — `@_silgen_name` declarations from the old static library model caused "Undefined symbol" linker errors after the static→dynamic xcframework migration.
- **FIX**(android): Catch `ForegroundServiceStartNotAllowedException` in `LocationService.start()` so calling `ready()` from the background on Android 12+ no longer crashes the host app; the foreground service start is deferred until the app returns to foreground.


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

## 3.2.9

- **FIX**(ios): Remove `TraceletCore+Dummy.swift` / `TraceletSyncFFI+Dummy.swift` — `@_silgen_name` declarations from the old static library model caused "Undefined symbol" linker errors after the static→dynamic xcframework migration.
- **FIX**(android): Catch `ForegroundServiceStartNotAllowedException` in `LocationService.start()` so calling `ready()` from the background on Android 12+ no longer crashes the host app; the foreground service start is deferred until the app returns to foreground.

## 3.2.9

- **FIX**(ios): Remove `TraceletCore+Dummy.swift` / `TraceletSyncFFI+Dummy.swift` — `@_silgen_name` declarations from the old static library model caused "Undefined symbol" linker errors after the static→dynamic xcframework migration.
- **FIX**(android): Catch `ForegroundServiceStartNotAllowedException` in `LocationService.start()` so calling `ready()` from the background on Android 12+ no longer crashes the host app; the foreground service start is deferred until the app returns to foreground.

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
- **FEAT**: Implemented `SpeedMotionManager` for the new `tl.MotionDetectionMode.speed` tracking mode, exclusively using GPS speed variations for motion state transitions.
- **FIX**: Prevented a critical logic flaw where the accelerometer was completely shut down during the `stopTimeout` countdown. Motion during the countdown now correctly aborts the stationary transition (#85).
- **FIX**: Reset `TraceletHasRequestedAlways` flag upon iOS `notDetermined` state to prevent native prompt bypasses after the app is reinstalled.
- **REFACTOR**: Transitioned all string-based config values to type-safe Enums across the platform bridge.

## 2.0.7

- **FIX**: Resolved an issue where low-confidence Activity Recognition updates were ignored by the Dart event stream but were still silently updating the internal state machine, causing subsequent high-confidence updates to be dispatched as spurious "changes" even when the activity type hadn't actually changed.
- **FIX**: Resolved a bug where the `stopTimer` countdown (for transitioning from moving to stationary) was being incorrectly reset on every `CMMotionActivity` update. This caused the SDK to get stuck in the `moving` state because the countdown timer never had a chance to reach zero.

## 2.0.6

- **FIX**: Resolved critical issue where calculated `BatteryBudgetEngine` parameter adjustments (distance filter, accuracy) were not applied to `LocationEngine`.
- **FEAT**: Added "Charging Bypass" to skip battery budgeting updates while connected to external power.
- **PERF**: Implemented heartbeat deduplication, saving hundreds of redundant SQLite inserts/hour when stationary by tracking last persisted location timestamps.
- **FIX**: Corrected `stillSampleCount` dwell window regression to match the actual 10Hz accelerometer rate (reduced stationary delay from 15s to 5s).
- **FIX**: Added permission-missing checks and explicit feedback via `providerChange` events on `start()` call.

## 2.0.5

- **CHORE**: Bump version to 2.0.5 to align with federated Flutter packages and coordinated monorepo release.

## 2.0.3

- **FIX**: Remove unreliable iOS timestamp drift heuristic that could cause false mock detection flags due to device-network clock drift.

## 2.0.2

- **FIX**: `deferTime` is now accounted for in the heuristic mock detection drift calculation. Deferred locations are no longer incorrectly flagged as mock locations.
- **FIX**: Refactored `TraceletConfigTests.swift` to match the current configuration structure.

## 2.0.1

- **FIX**: Fixed persistent blue location indicator by properly conditionally disabling `CLBackgroundActivitySession` and `startUpdatingLocation()` in low-accuracy geofence-only mode.
- **FIX**: `TraceletSdk.startGeofences()` now properly cleans up `CLBackgroundActivitySession` if switching from high to low accuracy.

## 2.0.0

- **CHORE**: Major release synchronized with Tracelet Flutter 2.0.0.
- **FEAT**: Added `shakeThreshold`, `stillThreshold`, and `stillSampleCount` to `MotionConfig` for granular accelerometer tuning.
- **CHORE**: Aligned versioning across the entire Tracelet monorepo.

## 1.1.4

- **CHORE**: Aligned repository podspec files and updated release documentation.
- **CHORE**: Maintenance release to sync native SDK versions.

## 1.1.3

- **FIX**: Aligned `sdk/ios/TraceletSDK.podspec` with root production podspec.
- **FIX**: Updated license to Apache-2.0 and included missing frameworks (CoreMotion, BackgroundTasks, AVFoundation, AudioToolbox, DeviceCheck) and sqlite3 library.
- **FIX**: Synchronized release versioning with Android and Flutter monorepo.

## 1.0.11

- **PERF**: `LocationEngine.changePace(true)` now fires an additional one-shot `requestLocation()` on stationary → moving transitions, delivering a fresh GPS fix as soon as the hardware is warm without waiting for `distanceFilter` to be satisfied on the continuous stream. Reduces first-fix latency on motion start from 11–50s to ~1–5s (#54).

## 1.0.10

- **FIX**: Version bump for parity with Android SDK 1.0.10 (killed-state tracking fix #50).

## 1.0.9

- **FEAT**: Add `getSyncInterval()` to `ConfigManager` and timer-based sync to `HttpSyncManager` (#50).

## 1.0.8

- **FIX**: Fix `SubsystemTests` — use `HttpSyncManager.onRequestFreshHeaders` (static type) instead of instance access.

## 1.0.7

- **CHORE**: Sync release versions with Flutter package updates.

## 1.0.6

- **FIX**: `getCurrentPosition(samples: 1)` routes through `collectSamples` using `startUpdatingLocation` instead of `CLLocationManager.requestLocation()` — forces a fresh GPS fix with proper timeout instead of returning stale cached locations (#46).
- **PERF**: Remove per-batch `onRequestFreshHeaders` invocation from `HttpSyncManager.syncBatch()` — eliminates unnecessary callback overhead. Token refresh handled reactively via `onAuthorizationRequired` on 401.
- **FIX**: Relax `isReady` guards to `manager != nil` for privacy zones, audit trail, and encryption — these features only need DB init, not active tracking.

## 1.0.5

- **FIX**: `getCurrentPosition()` / `collectSamples()` / `didFailWithError` fall back to last known location when `CLLocationManager` returns no fix — fixes `LOCATION_UNAVAILABLE` on simulators and GPS-off devices (#46).

## 1.0.4

- **CHORE**: Version bump for strict dependency pinning in Flutter wrapper.

## 1.0.3

- **FIX**: Add `isReady` guards to **all** SDK methods that access subsystem properties — prevents crash when any method is called before `ready()`, not just `stop()` (re-fixes #46).
- **FIX**: `getState()` returns a safe default disabled state before `ready()` instead of crashing.
- **FIX**: `setConfig()`, `reset()`, `getLog()`, `playSound()`, `getSensors()`, all geofence/location/persistence/sync/schedule/privacy-zone/audit-trail methods now guard against pre-ready access.

## 1.0.2

- **FIX**: `TraceletSdk.stop()` now checks `isReady` before accessing managers — prevents crash when `stop()` is called before `ready()` (fixes #46).

## 1.0.1

- Initial release on CocoaPods.