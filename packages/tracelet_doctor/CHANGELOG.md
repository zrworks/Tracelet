## 3.2.8

- **FIX**: Persist geofence ENTER/EXIT events in offline queue and auto-sync to server — events were previously dispatched to the app but never stored in the local SQLite database (Issue #128).
- **FIX**: Structured event envelope (`event_type`, `event_payload`) for geofence events round-trips correctly through `getLocations()` and `insertLocation()`.

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

 - Bump "tracelet_doctor" to `3.1.10`.

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
- **FEAT**: UI now detects and displays the new `Smart` (Hybrid) motion detection mode in the Tracking Card.
- **FEAT**: Display `Battery Budget` target in the Battery & OEM Card.

## 1.0.4

 - Update a dependency to the latest release.

## 1.0.3

 - Update a dependency to the latest release.

## 1.0.2

 - Update a dependency to the latest release.

# Changelog

## 1.0.1

- **CHORE**: Update `tracelet` dependency to `^2.0.6`.
- **DOCS**: Added `example/example.dart` for pub.dev documentation scoring.
- **DOCS**: Added documentation cross-references back to `tracelet` in README.md.

## 1.0.0

- **Initial release** of Tracelet Doctor.
- Drop-in diagnostic bottom sheet via `TraceletDoctor.show(context)`.
- Permission status card (location, motion activity, accuracy authorization).
- Tracking state card (enabled/disabled, mode, motion, odometer, scheduler).
- Battery & OEM card with aggression rating meter (Huawei, Xiaomi, Samsung detection).
- Configuration review card with 5 smart issue detectors:
  - Missing headless task registration detection.
  - Tracking active without "Always" permission warning.
  - Mock locations detected during active tracking.
  - Power Save mode active during tracking.
  - Aggressive OEM without battery optimization exemption.
- Sensor availability grid (accelerometer, gyroscope, magnetometer, significant-motion).
- Database & device card with pending queue count and **clear pending locations** button with confirmation dialog.
- Warning list with 12 `HealthWarning` types and human-readable descriptions.
- Friendly "Tracelet Not Available" screen when plugin is not initialized.
- Copy-to-clipboard for full JSON diagnostic report.
- Re-run diagnostics without dismissing the sheet.
- Animated loading state and graceful error handling with retry.
- Dark glassmorphic theme with semantic status colors.
