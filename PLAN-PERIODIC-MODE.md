# Periodic Tracking Mode — GPS Icon Optimization Plan

## Problem

When `start()` is called, both platforms activate **continuous** GPS updates:

- **Android**: `fusedClient.requestLocationUpdates()` → persistent GPS icon in status bar
- **iOS**: `startUpdatingLocation()` + `allowsBackgroundLocationUpdates = true` → persistent blue arrow

The GPS icon stays on 100% of the time, even when the app only needs periodic location fixes (e.g., every 15–30 minutes).

## Root Cause

There is **no periodic tracking mode**. The only options today are:

- `TrackingMode.location` → continuous GPS (always-on icon)
- `TrackingMode.geofences` → geofence-only (no location updates)

The existing `heartbeatInterval` (default 60s) does one-shot fixes but runs **on top of** continuous tracking — it doesn't replace it.

---

## Solution: Add `TrackingMode.periodic`

A new tracking mode where the engine:

1. Wakes up every N minutes (configurable)
2. Performs a **one-shot** `getCurrentPosition()` with configurable accuracy (default `medium` ≈ 200m)
3. **Immediately stops** the location manager after the fix
4. Reports the location to Dart via the existing EventChannel
5. Goes back to sleep

**GPS icon visible for ~5–10 seconds per fetch** instead of permanently.

---

## New Config Options (all in `GeoConfig`)

| Option | Type | Default | Description |
|---|---|---|---|
| `periodicLocationInterval` | `int` | `900` (15 min) | Seconds between one-shot fixes in periodic mode. Range: 60–43200 (1 min–12 hrs). |
| `periodicDesiredAccuracy` | `DesiredAccuracy` | `medium` | Accuracy for periodic fixes. `medium` ≈ 200m (WiFi/cell, no GPS radio). Configurable to `high` if GPS precision needed. |
| `periodicUseForegroundService` | `bool` | `false` | **Android only.** `true`: keep foreground service + timer (reliable, sub-15-min intervals). `false`: use WorkManager (no notification, battery-optimal, min 15 min). |
| `periodicUseExactAlarms` | `bool` | `false` | **Android only.** When `periodicUseForegroundService: false`, use `AlarmManager.setExactAndAllowWhileIdle()` instead of WorkManager for more precise timing. Requires `SCHEDULE_EXACT_ALARM` permission on API 31+. |

---

## Android Architecture (Two Strategies)

### Strategy 1: WorkManager (default) — `periodicUseForegroundService: false`

- Schedule a `PeriodicWorkRequest` at `periodicLocationInterval`
- `PeriodicLocationWorker` does:
  1. `fusedClient.getCurrentLocation(priority)` → GPS icon for ~5 sec
  2. Dispatch location via `EventDispatcher`
  3. `Result.success()` → worker done, GPS off
- **No foreground service, no persistent notification, no GPS icon between fixes**
- Minimum interval: 15 minutes (Android WorkManager constraint)
- If `periodicUseExactAlarms: true` → use `AlarmManager` + `OneTimeWorkRequest` combo for more precise timing

### Strategy 2: Foreground Service + Timer — `periodicUseForegroundService: true`

- Keep `LocationService` running (persistent notification stays)
- Replace `requestLocationUpdates()` with `Handler.postDelayed()` loop
- Each tick: `getCurrentPosition()` → dispatch → done
- **Notification visible, but GPS icon only during fix (~5 sec)**
- Supports intervals < 15 min with full reliability
- Best for apps that need guaranteed, precise timing

---

## iOS Architecture

### Primary mechanism: `startMonitoringSignificantLocationChanges()` (no blue arrow)

### Periodic fix: `Timer.scheduledTimer()` fires `requestLocation()`

### Background survival (layered, configurable):

| Layer | Always Active | Config Guard | Purpose |
|---|---|---|---|
| Significant location changes | Yes | — | Wakes app on cell tower transition (no blue arrow) |
| `BGAppRefreshTask` | Yes | — | Schedules next wakeup at `periodicLocationInterval` |
| `beginBackgroundTask` | Yes | — | Keeps app alive during each location fix processing |
| `PreventSuspendManager` (silent audio) | No | `preventSuspend: true` | Guarantees timer fires even while backgrounded |

### Flow in periodic mode:

1. `startMonitoringSignificantLocationChanges()` (always, for app relaunch)
2. Do NOT call `startUpdatingLocation()`
3. Set `allowsBackgroundLocationUpdates = false`
4. Schedule `BGAppRefreshTask` at `periodicLocationInterval`
5. On wakeup (BGTask or significant change or timer):
   - `requestLocation()` → blue arrow for ~5 sec
   - `didUpdateLocations` fires → dispatch → `stopUpdatingLocation()`
   - Reschedule next `BGAppRefreshTask`

---

## Enum Change

```dart
enum TrackingMode {
  location,   // index 0 — continuous GPS (existing)
  geofences,  // index 1 — geofence-only (existing)
  periodic,   // index 2 — one-shot fixes at interval (NEW)
}
```

---

## Files to Create/Modify

| # | File | Action | Description |
|---|---|---|---|
| 1 | `platform_interface/types/enums.dart` | Modify | Add `TrackingMode.periodic` |
| 2 | `platform_interface/models/config.dart` | Modify | Add 4 new config options |
| 3 | `tracelet_android/.../PeriodicLocationWorker.kt` | **Create** | WorkManager `CoroutineWorker` for one-shot fixes |
| 4 | `tracelet_android/.../LocationEngine.kt` | Modify | Add `startPeriodic()` / `stopPeriodic()` with timer-based one-shot |
| 5 | `tracelet_android/.../TraceletAndroidPlugin.kt` | Modify | Route `periodic` mode, skip continuous `start()` |
| 6 | `tracelet_android/.../service/LocationService.kt` | Modify | Support periodic mode (timer instead of continuous) |
| 7 | `tracelet_android/.../ConfigManager.kt` | Modify | Read new config options |
| 8 | `tracelet_ios/.../LocationEngine.swift` | Modify | Add `startPeriodic()` / `stopPeriodic()`, guard `allowsBackgroundLocationUpdates` |
| 9 | `tracelet_ios/.../TraceletIosPlugin.swift` | Modify | Route `periodic` mode, skip PreventSuspend by default |
| 10 | `tracelet_ios/.../ConfigManager.swift` | Modify | Read new config options |
| 11 | `tracelet/src/tracelet.dart` | Modify | Add `startPeriodic()` convenience + docs |
| 12 | `tracelet/src/models/config.dart` | Modify | Expose new config options in app-facing API |
| 13 | Tests for all packages | Create/Modify | Unit tests for periodic mode |

---

## Implementation Order

```
Step 1: tracelet_platform_interface
  ├─ Add TrackingMode.periodic enum
  ├─ Add config options (periodicLocationInterval, periodicDesiredAccuracy,
  │   periodicUseForegroundService, periodicUseExactAlarms)
  └─ Tests

Step 2: tracelet_android
  ├─ ConfigManager: read new options
  ├─ Create PeriodicLocationWorker (WorkManager strategy)
  ├─ LocationEngine: startPeriodic() / stopPeriodic() (ForegroundService strategy)
  ├─ TraceletAndroidPlugin: route periodic mode
  ├─ LocationService: periodic mode support
  └─ Tests (Robolectric)

Step 3: tracelet_ios
  ├─ ConfigManager: read new options
  ├─ LocationEngine: startPeriodic() / stopPeriodic()
  │   ├─ allowsBackgroundLocationUpdates = false
  │   ├─ startMonitoringSignificantLocationChanges() only
  │   ├─ Timer + requestLocation() for periodic fix
  │   └─ BGAppRefreshTask scheduling
  ├─ TraceletIosPlugin: route periodic mode
  └─ Tests (XCTest)

Step 4: tracelet (app-facing)
  ├─ startPeriodic() convenience method
  ├─ Documentation
  └─ Tests

Step 5: Validation
  ├─ melos run analyze
  ├─ melos exec -- "dart format --set-exit-if-changed ."
  └─ Integration test in example app
```

---

## Usage Examples

```dart
// Battery-optimized periodic tracking (every 30 min, ~200m accuracy)
await Tracelet.start(
  geoConfig: GeoConfig(
    periodicLocationInterval: 1800,
    periodicDesiredAccuracy: DesiredAccuracy.medium,
  ),
  trackingMode: TrackingMode.periodic,
);

// Reliable periodic with foreground service (every 5 min, GPS accuracy)
await Tracelet.start(
  geoConfig: GeoConfig(
    periodicLocationInterval: 300,
    periodicDesiredAccuracy: DesiredAccuracy.high,
    periodicUseForegroundService: true,
  ),
  trackingMode: TrackingMode.periodic,
);

// iOS with guaranteed background execution
await Tracelet.start(
  geoConfig: GeoConfig(
    periodicLocationInterval: 1800,
    periodicDesiredAccuracy: DesiredAccuracy.medium,
  ),
  appConfig: AppConfig(preventSuspend: true),
  trackingMode: TrackingMode.periodic,
);
```

---

## Expected Results

| Metric | `TrackingMode.location` (current) | `TrackingMode.periodic` (WorkManager) | `TrackingMode.periodic` (FG Service) |
|---|---|---|---|
| Android GPS icon | Always on | ~5 sec per fix | ~5 sec per fix |
| iOS blue arrow | Always on | ~5 sec per fix | N/A |
| Android notification | Always visible | None | Always visible |
| Battery drain/day | High (~15-25%) | Very low (~1-3%) | Low (~3-5%) |
| Accuracy | ~10m | ~200m (configurable) | ~200m (configurable) |
| Min interval | N/A | 15 min (WorkManager) | 1 min |
| Survives reboot | Yes (BootReceiver) | Yes (WorkManager persists) | Yes (BootReceiver) |

---

## Key Design Decisions

1. **Everything is configurable** — interval, accuracy, scheduling mechanism, foreground service usage
2. **Smart defaults** — WorkManager (Android), BGAppRefreshTask + significant changes (iOS), 15-min interval, medium accuracy
3. **Two Android strategies** — WorkManager for max battery savings, ForegroundService for max reliability
4. **Layered iOS background survival** — significant changes (always) + BGAppRefreshTask + optional silent audio
5. **Backward compatible** — existing `TrackingMode.location` and `TrackingMode.geofences` behavior unchanged
6. **Testable** — each strategy is isolated in its own class/method, mockable dependencies
