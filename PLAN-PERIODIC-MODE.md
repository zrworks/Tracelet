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

### ✅ IMPLEMENTED

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

### Killed-State & Reboot Recovery

| Scenario | Continuous (0) | Geofences (1) | Periodic/WorkManager (2) | Periodic/ExactAlarm (2) | Periodic/FG-Service (2) |
|---|---|---|---|---|---|
| **App swiped away** | FG service + `startBootTracking()` | FG service + `startBootTracking()` | WorkManager re-scheduled, FG service stopped | AlarmManager re-scheduled, FG service stopped | FG service + periodic timer via `startBootTracking()` |
| **OS kills (OOM)** | `START_STICKY` restarts service | `START_STICKY` restarts service | WorkManager survives natively | Alarms survive, OneTimeWork re-enqueued | `START_STICKY` restarts service |
| **Device reboot** | `BootReceiver` → `LocationService.startFromBoot()` | `BootReceiver` → `LocationService.startFromBoot()` | `BootReceiver` → `PeriodicLocationWorker.schedule()` (no FG service) | `BootReceiver` → `scheduleOneTime()` + `scheduleExactAlarm()` (no FG service) | `BootReceiver` → `LocationService.startFromBoot()` → periodic timer |
| **Force-stop** | Dead | Dead | Dead (WorkManager paused) | Dead | Dead |

**Key improvement:** `BootReceiver` and `LocationService.startBootTracking()` are now **tracking-mode-aware**. They read `StateManager.trackingMode` to decide the correct restart strategy instead of always starting continuous GPS.
- **Notification visible, but GPS icon only during fix (~5 sec)**
- Supports intervals < 15 min with full reliability
- Best for apps that need guaranteed, precise timing

---

## iOS Architecture

### ✅ IMPLEMENTED

### Primary mechanism: `startMonitoringSignificantLocationChanges()` (no blue arrow)

### Periodic fix: `Timer.scheduledTimer()` fires `requestLocation()`

### Background survival (layered, configurable):

| Layer | Always Active | Config Guard | Purpose | Status |
|---|---|---|---|---|
| Significant location changes | Yes | — | Wakes app on cell tower transition (no blue arrow) | ✅ |
| `BGAppRefreshTask` | Yes | — | Schedules next wakeup at `periodicLocationInterval` | ✅ |
| `beginBackgroundTask` | Yes | — | Keeps app alive during each location fix processing | ✅ |
| `CLServiceSession` (iOS 18+) | Yes | — | Preserves authorization across suspension/termination | ✅ |
| `PreventSuspendManager` (silent audio) | No | `preventSuspend: true` | Guarantees timer fires even while backgrounded | ✅ |
| **Killed-state auto-resume** | Yes | — | Detects `LaunchOptionsKey.location` and restores tracking | ✅ |

### Flow in periodic mode:

1. `startMonitoringSignificantLocationChanges()` (always, for app relaunch)
2. Do NOT call `startUpdatingLocation()`
3. Set `allowsBackgroundLocationUpdates = false`
4. Schedule `BGAppRefreshTask` at `periodicLocationInterval` via `PeriodicRefreshScheduler`
5. Start `CLServiceSession` (iOS 18+) with appropriate auth level (Always vs WhenInUse)
6. On wakeup (BGTask or significant change or timer):
   - `requestLocation()` → blue arrow for ~5 sec
   - `didUpdateLocations` fires → dispatch → `stopUpdatingLocation()`
   - Reschedule next `BGAppRefreshTask`
7. On killed-state relaunch (significant location change with Always permission):
   - `application(_:didFinishLaunchingWithOptions:)` detects `.location` key
   - `autoResumeTracking()` reads persisted `StateManager` state
   - Restarts the correct tracking mode from persisted config

### Permission-based behavior:

| Permission | Behavior |
|---|---|
| **While In Use** | Timer works in foreground/background (~30 sec), BGAppRefreshTask supplements. Cannot relaunch from killed state. |
| **Always** | Full killed-state support: significant location changes relaunch app → `autoResumeTracking()` restores periodic mode. `CLServiceSession` preserves auth. |

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

| # | File | Action | Description | Status |
|---|---|---|---|---|
| 1 | `platform_interface/types/enums.dart` | Modify | Add `TrackingMode.periodic` | ✅ |
| 2 | `platform_interface/models/config.dart` | Modify | Add 4 new config options | ✅ |
| 3 | `tracelet_android/.../PeriodicLocationWorker.kt` | **Create** | WorkManager `CoroutineWorker` for one-shot fixes | ✅ |
| 4 | `tracelet_android/.../LocationEngine.kt` | Modify | Add `startPeriodic()` / `stopPeriodic()` with timer-based one-shot | ✅ |
| 5 | `tracelet_android/.../TraceletAndroidPlugin.kt` | Modify | Route `periodic` mode, skip continuous `start()` | ✅ |
| 6 | `tracelet_android/.../service/LocationService.kt` | Modify | Tracking-mode-aware boot recovery + task-removal handling | ✅ |
| 7 | `tracelet_android/.../ConfigManager.kt` | Modify | Read new config options | ✅ |
| 8 | `tracelet_android/.../receiver/BootReceiver.kt` | Modify | Tracking-mode-aware reboot recovery (periodic without FG service) | ✅ |
| 9 | `tracelet_android/.../StateManager.kt` | Modify | Fixed docs to include `2=periodic` | ✅ |
| 10 | `tracelet_ios/.../LocationEngine.swift` | Modify | Add `startPeriodic()` / `stopPeriodic()`, guard `allowsBackgroundLocationUpdates`, `performPeriodicFix()` internal | ✅ |
| 11 | `tracelet_ios/.../TraceletIosPlugin.swift` | Modify | Route `periodic` mode, auto-resume from killed state, CLServiceSession, wire PeriodicRefreshScheduler | ✅ |
| 12 | `tracelet_ios/.../ConfigManager.swift` | Modify | Read new config options | ✅ |
| 13 | `tracelet_ios/.../PeriodicRefreshScheduler.swift` | **Create** | BGAppRefreshTask manager for supplementary periodic wake-ups | ✅ |
| 14 | `tracelet/src/tracelet.dart` | Modify | Add `startPeriodic()` convenience + docs | ✅ |
| 15 | `tracelet/src/models/config.dart` | Modify | Expose new config options in app-facing API | ✅ |
| 16 | Tests (iOS) | **Create** | 23 XCTests for PeriodicRefreshScheduler + AutoResume | ✅ |
| 17 | Tests (Android) | **Create** | 31 Kotlin tests for BootReceiver + LocationService boot recovery | ✅ |

---

## Implementation Order

All steps are **COMPLETE** ✅

```
Step 1: tracelet_platform_interface ✅
  ├─ Add TrackingMode.periodic enum
  ├─ Add config options (periodicLocationInterval, periodicDesiredAccuracy,
  │   periodicUseForegroundService, periodicUseExactAlarms)
  └─ Tests

Step 2: tracelet_android ✅
  ├─ ConfigManager: read new options
  ├─ Create PeriodicLocationWorker (WorkManager strategy)
  ├─ LocationEngine: startPeriodic() / stopPeriodic() (ForegroundService strategy)
  ├─ TraceletAndroidPlugin: route periodic mode
  ├─ LocationService: periodic mode support
  └─ Tests (Robolectric)

Step 3: tracelet_ios ✅
  ├─ ConfigManager: read new options
  ├─ LocationEngine: startPeriodic() / stopPeriodic()
  │   ├─ allowsBackgroundLocationUpdates = false
  │   ├─ startMonitoringSignificantLocationChanges() only
  │   ├─ Timer + requestLocation() for periodic fix
  │   └─ performPeriodicFix() exposed as internal
  ├─ PeriodicRefreshScheduler: BGAppRefreshTask scheduling (NEW)
  ├─ TraceletIosPlugin: route periodic mode
  │   ├─ Killed-state auto-resume via application(_:didFinishLaunchingWithOptions:)
  │   ├─ CLServiceSession (iOS 18+) / CLBackgroundActivitySession (iOS 17+)
  │   └─ PeriodicRefreshScheduler wired into start/stop/reset lifecycle
  └─ Tests (XCTest) — 23 tests passing

Step 4: tracelet (app-facing) ✅
  ├─ startPeriodic() convenience method
  ├─ Documentation
  └─ Tests

Step 5: Validation ✅
  ├─ flutter build ios --no-codesign — SUCCESS
  ├─ flutter build apk --debug — SUCCESS
  ├─ XCTests — 23/23 PASSED (iOS)
  ├─ Kotlin unit tests — 61/61 PASSED (Android)
  ├─ Dart tests — 2/2 PASSED
  ├─ dart analyze — 0 issues across all 6 packages
  └─ dart format — 0 changes across 69 files
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
