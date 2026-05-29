## 3.1.7

 - **FIX**(android): apply kotlin-android plugin to fix gradle build errors on newer AGP versions.
 - **FIX**(ios): fix SPM source folder paths in release bundling to ensure SDK compiles properly via CocoaPods.
 - **FIX**(ios): fix duplicate module import errors by adding conditional import checks for TraceletSDK.

# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2026-05-27

### Changes

---

## 3.1.4

**FEAT**: Major architectural upgrade: Unified Rust Core.
- The heavy lifting for Geofences, Privacy Zones, Audit Trail, and SQLite persistence has been moved to a shared Rust core (`tracelet_core`).
- Guarantees 100% mathematical and behavioral parity between iOS and Android.
- Eliminates subtle cross-platform inconsistencies in geofence ray-casting and proximity evaluation.
- Native SDK wrappers (Swift/Kotlin) have been thinned out to act purely as FFI bridges via UniFFI.

**FEAT**: Introduced explicit predefined tracking profiles: `Config.highAccuracy()`, `Config.balanced()`, and `Config.lowPower()` to simplify setup.

**CHORE**: Release strategy overhaul. The iOS Rust Core is now bundled directly into the `tracelet_ios` plugin for pub.dev publication, while the Android SDK continues to be distributed via Maven Central.

## 2026-05-23

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`tracelet` - `v2.1.0`](#tracelet---v210)
 - [`tracelet_ios` - `v2.1.0`](#tracelet_ios---v210)
 - [`tracelet_android` - `v2.1.0`](#tracelet_android---v210)
 - [`tracelet_platform_interface` - `v2.1.0`](#tracelet_platform_interface---v210)
 - [`tracelet_doctor` - `v1.0.4`](#tracelet_doctor---v104)
 - [`tracelet_web` - `v2.0.9`](#tracelet_web---v209)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `tracelet_doctor` - `v1.0.4`
 - `tracelet_web` - `v2.0.9`

---

#### `tracelet` - `v2.1.0`

### 🎉 Major Features & Improvements
- **FEAT**: Smart Foreground Notification Visibility (Android) — Added dynamic foreground service notification management. The notification now intelligently hides itself when the app is in the foreground, and reappears seamlessly when the app enters the background. This significantly reduces notification clutter while maintaining OS-level compliance.
- **FEAT**: Speed-Based Motion Detection Mode — Introduced a new motion detection mode (`tl.MotionDetectionMode.speed`). In this mode, motion state transitions are driven directly by GPS speed calculations rather than raw accelerometer hardware. This provides enhanced compatibility and reliability on devices with aggressive sensor sleep policies, particularly in vehicular tracking scenarios.
- **FEAT**: Strongly-Typed Enums Across Bridge — Fully refactored string-based config comparisons to typed enum indices across the Flutter, Pigeon, Android, and iOS layers. This eliminates magic strings and ensures type-safety across the entire plugin bridge.

### 🐛 Bug Fixes
- **FIX (Core)**: Fixed Accelerometer "Deaf Period" During Stop Countdown — Fixed a critical flaw in both Android and iOS native SDKs where the accelerometer was completely shut down during the `stopTimeout` countdown. Previously, if the device was still for 5 seconds on a smooth road, it would begin the 60-second stop countdown and ignore any subsequent bumps or shakes. Now, the accelerometer remains active during the countdown and will correctly abort the stationary transition if motion resumes ([#85](https://github.com/Ikolvi/Tracelet/issues/85)).
- **FIX (iOS)**: Resolved Native Permission Prompt Loop — Fixed an issue where reinstalling the app on iOS would bypass the native "Change to Always Allow" permission dialog and incorrectly redirect users to the iOS Settings app. `TraceletHasRequestedAlways` is now properly reset upon `notDetermined` OS state.
- **FIX (Core)**: Corrected Exponential Retry Backoff Scaling — Fixed a critical unit discrepancy between Dart and Swift for `retryBackoffCap` and `retryBackoffBase`. Time values are now properly cast as milliseconds instead of seconds, resolving a severe bug where HTTP retries fired every 60ms during network failure, causing excessive CPU/network thrashing and a massive 58KB+ log flood.
- **FIX (Core)**: Resolved Location Stream Dropping Events — Refactored the core `Tracelet.locationStream` pipeline. Replaced the faulty `asyncMap` batch processing with a highly robust `.expand()` implementation. The `Tracelet.locationStream` now correctly parses, type-casts, and guarantees delivery of every individual `Location` object without throwing `type '_Map<Object?, Object?>' is not a subtype of type 'Map<String, dynamic>'` or silently discarding valid coordinates.
- **FIX (Android)**: Prevent `LocationEngine.stop` from unintentionally overriding the global `stateManager.enabled` flag during speed-based motion transitions.
- **FIX (Example)**: Updated the example app's initialization config to enforce `MotionDetectionMode.accelerometer` as the default to ensure immediate indoor responsiveness upon installation.

#### `tracelet_ios` - `v2.1.0`

 - **CHORE**: Sync release versions across workspace.

#### `tracelet_android` - `v2.1.0`

 - **CHORE**: Sync release versions across workspace.

#### `tracelet_platform_interface` - `v2.1.0`

 - **CHORE**: Sync release versions across workspace.


## 2026-05-22

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`tracelet_ios` - `v2.0.8`](#tracelet_ios---v208)
 - [`tracelet` - `v2.0.8`](#tracelet---v208)
 - [`tracelet_doctor` - `v1.0.3`](#tracelet_doctor---v103)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `tracelet` - `v2.0.8`
 - `tracelet_doctor` - `v1.0.3`

---

#### `tracelet_ios` - `v2.0.8`

 - Bump "tracelet_ios" to `2.0.8`.


## 2026-05-22

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`tracelet_android` - `v2.0.7`](#tracelet_android---v207)
 - [`tracelet_ios` - `v2.0.7`](#tracelet_ios---v207)
 - [`tracelet` - `v2.0.7`](#tracelet---v207)
 - [`tracelet_doctor` - `v1.0.2`](#tracelet_doctor---v102)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `tracelet` - `v2.0.7`
 - `tracelet_doctor` - `v1.0.2`

---

#### `tracelet_android` - `v2.0.7`

 - **FIX**(interface): correct intToAuthStatus permission index mappings ([[#80](https://github.com/Ikolvi/Tracelet/issues/80)](https://github.com/Ikolvi/Tracelet/issues/80)). ([8cfd7f51](https://github.com/Ikolvi/Tracelet/commit/8cfd7f5150791063bc1286c5c185d01f1d3fc306))

#### `tracelet_ios` - `v2.0.7`

 - **FIX**(interface): correct intToAuthStatus permission index mappings ([[#80](https://github.com/Ikolvi/Tracelet/issues/80)](https://github.com/Ikolvi/Tracelet/issues/80)). ([8cfd7f51](https://github.com/Ikolvi/Tracelet/commit/8cfd7f5150791063bc1286c5c185d01f1d3fc306))

