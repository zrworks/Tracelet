## 0.8.0

* **FEAT**: `OemCompat` utility — comprehensive OEM compatibility layer with manufacturer detection (Huawei, Xiaomi, OnePlus, Samsung, Oppo, Vivo), aggression ratings (0–5), and OEM-specific settings deep-links.
* **FEAT**: Huawei PowerGenie wakelock hack — uses `LocationManagerService` wakelock tag to bypass PowerGenie background killing.
* **FEAT**: Xiaomi autostart detection — runtime check for MIUI autostart management activity availability.
* **FEAT**: OEM settings deep-links — 8 manufacturer-specific settings screens (autostart, battery saver, app launch, protected apps) validated via `PackageManager.resolveActivity()`.
* **FEAT**: `getSettingsHealth` method channel handler — returns full device OEM health map.
* **FEAT**: `openOemSettings` method channel handler — launches OEM settings by label.
* **PERF**: OEM-safe wakelock lifecycle in `LocationService` — acquire on start, release on stop/destroy/taskRemoved.
* **PERF**: Boot receiver wakelock — temporary 60-second wakelock during `BOOT_COMPLETED` processing to survive aggressive OEM process killing.
* **CHORE**: ProGuard/R8 consumer rules (`consumer-rules.pro`) — prevents stripping of services, receivers, Room entities, and Kotlin metadata in release builds.
* **DOCS**: Update README with OEM compatibility feature and documentation link.
* **CHORE**: Bump `tracelet_platform_interface` to ^0.8.0.

## 0.7.1

* **DOCS**: Add mock location detection feature to README with platform-specific detection details.
* **CHORE**: Bump `tracelet_platform_interface` to ^0.7.1.

## 0.7.0

* **FEAT**: Mock location detection — `isLocationMock()` uses `Location.isMock()` (API 31+) and `isFromMockProvider()` (API 18+) to flag spoofed GPS.
* **FEAT**: Heuristic mock detection (level 2) — satellite count check (< 4 = suspicious) and `SystemClock.elapsedRealtimeNanos` drift detection (> 5s = suspicious).
* **FEAT**: `enrichLocation()` includes `mock` flag and `mockHeuristics` metadata map (satellites, elapsedRealtimeDriftMs, platformFlagMock).
* **FEAT**: Native-level mock rejection — when `rejectMockLocations` is enabled, drops mocked locations before sending to Dart and fires `ProviderChangeEvent.mockLocationsDetected`.
* **FEAT**: `ConfigManager.getMockDetectionLevel()` and `getRejectMockLocations()` getters.
* **CHORE**: Bump `tracelet_platform_interface` to ^0.7.0.

## 0.6.1

* **REFACTOR**: Remove 6 dead `ConfigManager` constants and methods for filtering migrated to Dart in 0.6.0 (`getDisableElasticity`, `getElasticityMultiplier`, `getFilterPolicy`, `getMaxImpliedSpeed`, `getTrackingAccuracyThreshold`, `getUseKalmanFilter`).
* **REFACTOR**: Remove dead `EventDispatcher.sendTrip()` and `"trip"` channel registration — trip events now from Dart `TripManager`.
* **CHORE**: Bump `tracelet_platform_interface` to ^0.6.1.

## 0.6.0

* **REFACTOR**: Remove duplicate location filtering from `LocationEngine.onLocationReceived()` — elasticity, distance filter, accuracy filter, and speed filter now handled by shared Dart `LocationProcessor`.
* **REFACTOR**: Replace `GeofenceManager.evaluateHighAccuracyProximity()` with no-op stub — proximity evaluation moved to shared Dart `GeofenceEvaluator`.
* **CHORE**: Bump `tracelet_platform_interface` to ^0.6.0.

## 0.5.5

* **CHORE**: Bump `tracelet_platform_interface` to ^0.5.5.

## 0.5.4

* **FIX**: Heartbeat event now wraps location data in `{"location": ...}` to match `HeartbeatEvent.fromMap()` — fixes heartbeat always returning zero coordinates.
* **FIX**: Heartbeat falls back to last known location (via `enrichLocation()`) when `getCurrentPosition` returns null.

## 0.5.3

* **CHORE**: Bump `tracelet_platform_interface` to ^0.5.3.

## 0.5.2

* **FEAT**: Accelerometer-only motion detection mode — when `disableMotionActivityUpdates` is `true`, uses hardware accelerometer + `TYPE_SIGNIFICANT_MOTION` sensor for permission-free stationary↔moving detection.
* **PERF**: Lazily initialize `ActivityRecognitionClient` — no longer created when unused in accelerometer-only mode.
* **PERF**: Cache `SensorManager` instance via `obtainSensorManager()` instead of re-fetching on each call.
* **FIX**: Graceful degradation — if `ACTIVITY_RECOGNITION` permission throws `SecurityException`, automatically falls back to accelerometer-only mode.
* **REFACTOR**: Extract `activityTransition()` helper to reduce boilerplate in transition registration.

## 0.5.1

* **DOCS**: Rewrite README with proper description, setup guide link, and related packages table.

## 0.5.0

* **CHORE**: Bump `tracelet_platform_interface` to ^0.5.0.
* **CHORE**: Bump version to 0.5.0.

## 0.4.0

* **FEAT**: `getMotionPermissionStatus()` / `requestMotionPermission()` — ACTIVITY_RECOGNITION permission handling.
* **FIX**: Auto-pace not triggering — start accelerometer monitoring in `MotionDetector.start()` when stationary.
* **FIX**: Speed always zero in motionchange events — track `lastEffectiveSpeed` in LocationEngine.
* **FIX**: Kotlin compilation error from literal `\n` in import line.
* **CHORE**: Bump `tracelet_platform_interface` to ^0.4.0.

## 0.3.0

* **FEAT**: One-shot location via `getCurrentPosition()` with `persist`, `samples`, `maximumAge`, and `extras` parameters.
* **FEAT**: `getLastKnownLocation()` with 3-tier fallback — in-memory cache → FusedLocationProviderClient → system LocationManager (GPS/Network).
* **FEAT**: `ForegroundServiceConfig.enabled` — conditionally start/stop foreground service based on config.
* **FIX**: Replace `requestLocationUpdates` with sequential `getCurrentLocation()` calls in `collectSamples()` to avoid silent throttling on budget devices without foreground service.
* **BREAKING**: Requires `tracelet_platform_interface: ^0.3.0`.

## 0.2.3

* Fix LICENSE file format for proper SPDX detection on pub.dev.

## 0.2.2

* Fix `ConfigManager.setConfig()` — flatten nested section sub-maps (`geo`, `app`, `http`, etc.) sent by Dart before processing. Fixes foreground service notification config (title, text, channel, priority) and all other sub-config values being silently ignored.

## 0.2.1

* Version bump for coordinated release.

## 0.2.0

* Add SPDX `license: Apache-2.0` identifier for pub.dev scoring.

## 0.1.0

* Initial release.
* FusedLocationProvider-based location tracking.
* Foreground service with configurable notification.
* Activity recognition via Google Play Services.
* SQLite persistence with Room.
* HTTP auto-sync with OkHttp.
* Geofencing with platform GeofencingClient.
* Headless Dart isolate execution.
* Boot-completed receiver for start-on-boot.
* WorkManager-based scheduling.
