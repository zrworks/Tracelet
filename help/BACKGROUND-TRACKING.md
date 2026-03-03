# Background Tracking

---

## With Foreground Notification (Recommended)

The foreground service keeps the app alive reliably in the background on Android.
A persistent notification is shown while tracking.

> **Android 13+:** You must request notification permission (`POST_NOTIFICATIONS`)
> before starting the foreground service, otherwise the notification will be
> hidden. See [Permissions Guide](PERMISSIONS.md#notification-permission-android-13).

> **iOS:** Foreground service config is ignored — iOS uses its own
> background-mode mechanisms (BackgroundTasks, CoreLocation significant
> changes). No notification permission is needed for background location.

```dart
// 1. Request notification permission (Android 13+)
if (Platform.isAndroid) {
  final notifStatus = await tl.Tracelet.getNotificationPermissionStatus();
  if (notifStatus != 3) {
    await tl.Tracelet.requestNotificationPermission();
  }
}

// 2. Configure and start
await tl.Tracelet.ready(tl.Config(
  app: tl.AppConfig(
    stopOnTerminate: false,
    startOnBoot: true,
    foregroundService: tl.ForegroundServiceConfig(
      notificationTitle: 'My App',
      notificationText: 'Tracking your location',
    ),
  ),
));
await tl.Tracelet.start();
```

### Custom Notification Icon

By default the notification uses the app launcher icon. To use a custom icon,
add a drawable resource to your Android project and reference it by name
(without the file extension or `res/drawable` prefix):

**1. Add the icon file:**

```
android/app/src/main/res/
├── drawable-mdpi/my_notification_icon.png      (24×24)
├── drawable-hdpi/my_notification_icon.png      (36×36)
├── drawable-xhdpi/my_notification_icon.png     (48×48)
├── drawable-xxhdpi/my_notification_icon.png    (72×72)
└── drawable-xxxhdpi/my_notification_icon.png   (96×96)
```

> **Tip:** Notification icons must be **monochrome white on transparent** per
> Material Design guidelines. Android tints them with the system accent color.
> Using a colorful icon will appear as a solid white square.

**2. Reference it in config:**

```dart
foregroundService: tl.ForegroundServiceConfig(
  notificationTitle: 'My App',
  notificationText: 'Tracking your location',
  notificationSmallIcon: 'my_notification_icon', // drawable resource name
),
```

> On iOS, foreground service configuration is ignored entirely — no
> notification icon is needed.

---

## Without Foreground Notification

No notification is shown. Suitable for short-lived tasks like check-ins,
one-shot location fetches, or foreground-only use. The OS may kill the app
in the background at any time.

```dart
await tl.Tracelet.ready(tl.Config(
  app: tl.AppConfig(
    stopOnTerminate: true,
    foregroundService: tl.ForegroundServiceConfig(enabled: false),
  ),
));
await tl.Tracelet.start();
```

---

## Switching at Runtime

You can switch between modes at runtime using `setConfig()`:

```dart
// Switch to background tracking with notification
await tl.Tracelet.setConfig(tl.Config(
  app: tl.AppConfig(
    stopOnTerminate: false,
    startOnBoot: true,
    foregroundService: tl.ForegroundServiceConfig(
      notificationTitle: 'My App',
      notificationText: 'Background tracking active',
    ),
  ),
));
await tl.Tracelet.start();

// Switch to no-notification mode
await tl.Tracelet.setConfig(tl.Config(
  app: tl.AppConfig(
    stopOnTerminate: true,
    foregroundService: tl.ForegroundServiceConfig(enabled: false),
  ),
));
await tl.Tracelet.start();
```

---

## Periodic Mode

**Best for:** Apps that need location samples at regular intervals (e.g., fleet tracking with 15–30 min updates, daily check-ins, low-frequency asset monitoring) while keeping battery usage minimal.

Unlike continuous tracking, periodic mode:
- **Turns the GPS radio ON** only for ~5–10 seconds per fix
- **Turns the GPS radio OFF** between fixes
- Shows the GPS icon / blue arrow **briefly** instead of permanently
- Reduces battery consumption dramatically compared to continuous tracking

### Quick Start

```dart
await Tracelet.ready(Config(
  geo: GeoConfig(
    periodicLocationInterval: 900,                // 15 minutes
    periodicDesiredAccuracy: DesiredAccuracy.medium,
  ),
));

final state = await Tracelet.startPeriodic();
print(state.trackingMode); // TrackingMode.periodic
```

### Configuration Options

| Option | Default | Description |
|---|---|---|
| `periodicLocationInterval` | `900` (15 min) | Seconds between fixes. Minimum 60s. WorkManager enforces ≥ 15 min on Android when not using foreground service. |
| `periodicDesiredAccuracy` | `medium` | Accuracy per fix: `high`, `medium`, `low`, `veryLow`, `lowestUnbiased`. Lower = less battery but larger error radius. |
| `periodicUseForegroundService` | `false` | **Android only.** `true` = foreground service with Handler timer (reliable timing, shows notification). `false` = WorkManager (no notification, system-managed scheduling). |
| `periodicUseExactAlarms` | `false` | **Android only.** Use `AlarmManager` exact alarms for precise wakeups instead of WorkManager. Falls back to inexact alarms if `SCHEDULE_EXACT_ALARM` is not granted. See [Exact Alarms](#exact-alarms-periodicuseexactalarms-true) below. |

### Android Strategies

#### WorkManager (default — `periodicUseForegroundService: false`)

- No persistent notification required
- System-optimized scheduling (batches with other apps for battery)
- Minimum interval: **15 minutes** (enforced by Android)
- Survives app kill and device reboot (WorkManager re-enqueues automatically)
- Location delivered via `onLocation` event or headless callback

#### Foreground Service (`periodicUseForegroundService: true`)

- Requires notification permission on Android 13+
- Shows a persistent notification while active
- Precise interval control (Handler-based timer)
- GPS only active for ~5–10 seconds per fix; radio off between fixes
- More reliable scheduling than WorkManager

#### Exact Alarms (`periodicUseExactAlarms: true`)

Uses `AlarmManager.setExactAndAllowWhileIdle()` to wake the device at precise intervals, then enqueues a `OneTimeWorkRequest` for the actual GPS fix. This gives you **exact timing without a foreground service notification**.

**How it works:**
```
startPeriodic()
  → Immediate OneTimeWorkRequest (first fix)
  → AlarmManager exact alarm → PeriodicAlarmReceiver
    → OneTimeWorkRequest → doWork() performs GPS fix
      → Schedules next exact alarm (self-chaining)
```

**Permission requirements by Android version:**

| API Level | Permission | Behavior |
|---|---|---|
| < 31 (Android 11 and below) | None | Exact alarms work without permission |
| 31–32 (Android 12–12L) | `SCHEDULE_EXACT_ALARM` | Granted by default |
| 33+ (Android 13+) | `SCHEDULE_EXACT_ALARM` | **Not granted by default** — user must enable in Settings > Apps > Alarms & Reminders |

The plugin **automatically falls back** to inexact `AlarmManager.set()` if `canScheduleExactAlarms()` returns `false`. No crash, no error — just less precise timing. A warning is logged.

**Example configuration:**
```dart
await Tracelet.ready(Config(
  geo: GeoConfig(
    periodicLocationInterval: 600,         // 10 minutes
    periodicDesiredAccuracy: DesiredAccuracy.medium,
    periodicUseExactAlarms: true,          // Use AlarmManager
  ),
));
final state = await Tracelet.startPeriodic();
```

> **Note:** The `SCHEDULE_EXACT_ALARM` permission is declared in the plugin's `AndroidManifest.xml`. No runtime permission dialog is triggered — on Android 13+, users must manually grant it via Settings if they want exact timing. Without it, the plugin silently degrades to inexact alarms.

#### Killed-State & Reboot Recovery (Android)

Tracelet's `BootReceiver` and `LocationService` are **tracking-mode-aware**. After a device reboot or app kill, they restore the correct tracking mode from persisted state:

| Scenario | WorkManager (default) | Exact Alarms | Foreground Service |
|---|---|---|---|
| **App swiped away** | WorkManager re-scheduled, FG service stopped (no notification) | AlarmManager + OneTimeWork re-scheduled, FG service stopped | FG service stays, periodic timer via boot tracking |
| **OS kills (OOM)** | WorkManager survives natively | Alarms survive, work re-enqueued | `START_STICKY` restarts service |
| **Device reboot** | `BootReceiver` re-schedules WorkManager (no FG service) | `BootReceiver` re-schedules exact alarms (no FG service) | `BootReceiver` starts FG service with periodic timer |
| **Force-stop** | All dead (WorkManager paused until next app launch) | All dead | All dead |

> **Key detail:** For WorkManager and exact-alarm strategies, the `BootReceiver` does **not** start a foreground service on reboot. It directly re-schedules the background work. This means no persistent notification appears — the GPS icon only shows briefly during each fix.

To enable reboot recovery, configure:

```dart
await Tracelet.ready(Config(
  app: AppConfig(
    stopOnTerminate: false,  // Resume after app kill
    startOnBoot: true,       // Resume after device reboot
  ),
));
```

### iOS Behavior

On iOS, periodic mode uses a layered approach for background survival:

#### During active tracking:
- `allowsBackgroundLocationUpdates` is set to `false` between fixes
- Each fix temporarily enables background location, calls `requestLocation()`, then disables it again
- The GPS arrow appears briefly (~5 sec) during each fix
- `startMonitoringSignificantLocationChanges()` runs continuously (no blue arrow) for cell-tower-based wake-ups

#### Background survival layers:
| Layer | Description |
|---|---|
| **Significant location changes** | Always active. Wakes the app on cell tower transitions (~500m). No blue arrow. |
| **BGAppRefreshTask** | Schedules supplementary wake-ups at `periodicLocationInterval`. Ensures fixes even without cell tower changes. |
| **CLServiceSession** (iOS 18+) | Preserves location authorization across app suspension and termination. |
| **PreventSuspendManager** | Optional (`preventSuspend: true`). Silent audio keeps app alive — guarantees timer fires. |

#### Killed-state auto-resume (requires "Always" permission):
When the app is terminated and a significant location change occurs, iOS relaunches the app. Tracelet automatically:
1. Detects the `LaunchOptionsKey.location` flag
2. Reads persisted tracking state from `StateManager`
3. Restarts the correct tracking mode (continuous, geofences, or periodic)
4. Re-establishes the `CLServiceSession`

> **"While In Use" limitation:** With only "When In Use" permission, periodic tracking works while the app is in the foreground or briefly after backgrounding. It **cannot** survive app termination. For reliable periodic tracking, request "Always" permission.

#### Required Info.plist keys for periodic mode:
See the [iOS Setup Guide](INSTALL-IOS.md#bgtaskscheduler-permitted-identifiers-required-for-periodic-mode) for the `BGTaskSchedulerPermittedIdentifiers` that must be declared.

### Stopping

Stop periodic tracking with the regular `stop()` method:

```dart
await Tracelet.stop();
```

This cancels the WorkManager job (Android), clears the periodic timer, and returns the plugin to idle state.

### Battery Comparison

| Mode | GPS Active | Icon Visible | Battery Impact |
|---|---|---|---|
| Continuous (`start()`) | Always | Always | High |
| Periodic 15-min | ~10s every 15 min | ~10s every 15 min | Very Low |
| Periodic 30-min | ~10s every 30 min | ~10s every 30 min | Minimal |
| Geofence-only | On enter/exit | Brief | Low |

> **Tip:** Combine `periodicDesiredAccuracy: DesiredAccuracy.medium` with a 15+ minute interval for optimal battery life. Use `high` accuracy only when you need sub-10m precision per fix.
