## 3.2.16

* **FIX** (Native): Resolve Android/iOS getting stuck in the moving state and never transitioning back to stationary, which kept continuous GPS active and drained the battery. The accelerometer stillness sampler now stays active during the stop-timeout countdown and requires sustained motion — rather than a single noisy or stale sample — to abort it ([#142](https://github.com/Ikolvi/Tracelet/issues/142)).
* **FIX** (Native): Background and post-reboot location captures are persisted (and therefore synced) again. Headless tracking (killed-state relaunch / boot) never calls `ready()`, so an internal readiness guard silently dropped every captured location before it reached the database, leaving auto-sync with nothing to upload.
* **FIX** (Android): The foreground-service notification now reliably appears when the app is backgrounded or terminated with `showNotificationOnPauseOnly` enabled. The app's own foreground service skewed foreground/background detection (and OS process-importance updates lag), so the pause-only notification was suppressed even though tracking and syncing continued.

## 3.2.15

* **FIX** (Native): Allow `getState()` and `stop()` to be called before `ready()` is invoked, correctly reporting persistent state and shutting down background services if the app was restarted from a killed state.
* **CHORE**: Update dependencies and constraints.
* **FIX**: Resolve `MissingPluginException` and test timing issues with `setHasCustomSyncBodyBuilder`.

## 3.2.14

 - **DOCS**: integrate nextra website and update pubspec URLs. ([99b7fda8](https://github.com/Ikolvi/Tracelet/commit/99b7fda82e290ca6c8175313eae62a2475360050))

## 3.2.13

- **CHORE**: Version bump to 3.2.13 to stay in lockstep with the federated set (Android `startOnBoot` reboot-tracking fix — see `tracelet_android`). No changes to this package.

## 3.2.12

- **CHORE**: Re-release to align the full federated package set and native SDKs to a single consistent version. The 3.2.11 release published with mismatched versions across some packages (a few resolved to 3.2.10). No functional code changes.

## 3.2.11

- **CHORE**: Version bump to align with 3.2.11 platform release.

## 3.2.10

 - Update a dependency to the latest release.

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

## 3.2.4

* **FIX**(ios): safely resolve dynamic symbols when `use_frameworks! :linkage => :dynamic` is used.

## 3.2.3

- **FIX**: Force speed motion manager to evaluate initial speed on Android to prevent the state machine from being permanently stuck in `MOVING` when indoors ([#115](https://github.com/Ikolvi/Tracelet/issues/115)).
- **FIX**: Resolve `flutter_rust_bridge has not been initialized` crash by ensuring the Rust core is instantiated and initialized before accessing methods ([#116](https://github.com/Ikolvi/Tracelet/issues/116)).
- **CHORE**: Sync release versions across all packages.

## 3.2.2

- **CHORE**: Sync release versions across all federated packages and update Swift Package Manager configuration.

## 3.2.1

- **CHORE**: Align federated package versions and include additional patch updates.

## 3.2.0

- **CHORE**: Bump dependency to tracelet `3.2.0`.


## 3.1.14

- **CHORE**: Sync release versions across workspace.


## 3.1.10

 - Bump "tracelet_firebase" to `3.1.10`.

## 3.1.9

- **FIX**(android): conditionally apply kotlin-android plugin to support older flutter SDKs while preventing warnings in modern Flutter environments.
- **CHORE**(ci): add strict pre-publish flutter build verification step to `release.yml`.

## 3.1.8

- Fix iOS SPM publishing

## 3.1.7

 - **FIX**(android): apply kotlin-android plugin to fix gradle build errors on newer AGP versions.
 - **FIX**(ios): fix SPM source folder paths in release bundling to ensure SDK compiles properly via CocoaPods.
 - **FIX**(ios): fix duplicate module import errors by adding conditional import checks for TraceletSDK.

## 3.1.4

- **CHORE**: Sync release versions across workspace.

## 3.0.1

- **FIX**(ios): Add missing `FlutterFramework` dependency to SPM plugin configuration to resolve compilation failures and `PlatformException`s.

## 3.0.0

- **CHORE**: bump version to match tracelet 3.0.0 release.
- **FEAT**: upgraded `tracelet` core dependency to `^3.0.0` which includes the new high-performance Rust Engine rewrite for improved battery efficiency and tracking reliability.

## 1.0.1

* chore: optimize package description and metadata.

## 1.0.0

* Initial release of the Tracelet Firebase Adapter.