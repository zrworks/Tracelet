# iOS Background Hardening

Tracelet implements multiple layers of protection to keep iOS background location tracking alive and prevent the OS from killing the app mid-operation.

---

## The Problem

iOS aggressively suspends and terminates background apps. Even with `location` background mode enabled, the OS can suspend your app during:

- Database writes after receiving a location update
- HTTP sync uploads (multi-second network operations)
- Headless Dart engine boot (creating a `FlutterEngine` takes time)
- Lifecycle transitions (stopping subsystems, flushing state)

If iOS suspends the app during any of these operations, data can be lost or corrupted.

---

## Protection Layers

Tracelet uses three complementary mechanisms:

### 1. `beginBackgroundTask` Wrapping

Every critical native operation is wrapped in `UIApplication.beginBackgroundTask` / `endBackgroundTask`. This tells iOS "I need a few more seconds to finish this work" and prevents immediate suspension.

**Wrapped operations:**

| Operation | Protection Scope |
|---|---|
| `LocationEngine.didUpdateLocations` | Persist location to SQLite → dispatch to Dart → evaluate geofences |
| `HttpSyncManager.sync()` | Fetch from DB → HTTP upload → delete synced records |
| `HeadlessRunner.dispatchEvent()` | Boot FlutterEngine → flush pending events |
| `TraceletIosPlugin.handleStop()` | Stop all subsystems → persist final state |
| `TraceletIosPlugin.handleReset()` | Destroy all subsystems → reset config |
| `TraceletIosPlugin.onStopRequested` | Motion-triggered stop → teardown |
| `TraceletIosPlugin.handleScheduleStop()` | Scheduled stop → teardown |
| `TraceletIosPlugin.stopAfterElapsedTimer` | Auto-stop after N minutes → teardown |

The `BackgroundTaskHelper` utility provides a thread-safe singleton API:

```swift
// Synchronous — wraps a block, auto-ends the task when done
BackgroundTaskHelper.shared.run("httpSync") {
    // Critical work here
}

// Manual — for async operations
let taskId = BackgroundTaskHelper.shared.begin("engineBoot")
defer { BackgroundTaskHelper.shared.end(taskId) }
```

**Expiration handling:** If iOS signals that time is running out (via the expiration handler), the background task ends gracefully. The operation may be interrupted, but no crash occurs.

### 2. `CLBackgroundActivitySession` (iOS 17+)

`CLBackgroundActivitySession` tells iOS that your app is actively tracking location in the background. It replaces the need for the `location` background mode indicator to be continuously visible.

- **Started** when tracking begins (`start()`, `startGeofences()`, `scheduleStart`)
- **Stopped** (invalidated) when tracking stops (`stop()`, `reset()`, `scheduleStop`, `stopOnStationary`, `stopAfterElapsed`)
- **No-op** on iOS < 17

### 3. `CLServiceSession` (iOS 18+)

`CLServiceSession` maintains your app's location authorization state during background execution. Without it, iOS 18+ may downgrade your authorization level when the app moves to the background.

- **Started** with `fullAccuracyPurposeKey` when tracking begins
- **Stopped** when tracking stops
- **No-op** on iOS < 18

### 4. Prevent Suspend (Silent Audio)

When `AppConfig.preventSuspend: true` is set, Tracelet plays an inaudible audio clip in a loop using `AVAudioPlayer` with the `.playback` audio session category. This prevents iOS from suspending the app entirely.

- Generates a 1-second silent WAV in memory (mono, 8kHz, 16-bit PCM)
- Started/stopped with all tracking lifecycle transitions
- Use only when continuous background execution is critical — increases battery usage slightly

```dart
await Tracelet.ready(Config(
  app: AppConfig(
    preventSuspend: true,  // Enable silent audio keep-alive
  ),
));
```

---

## Lifecycle Coverage

All four protection mechanisms are wired into every lifecycle path:

| Lifecycle Event | beginBackgroundTask | BackgroundActivitySession | ServiceSession | PreventSuspend |
|---|---|---|---|---|
| `start()` | — | ✅ start | ✅ start | ✅ start |
| `stop()` | ✅ wrap | ✅ stop | ✅ stop | ✅ stop |
| `startGeofences()` | — | ✅ start | ✅ startWhenInUse | ✅ start |
| `reset()` | ✅ wrap | ✅ stop | ✅ stop | ✅ stop |
| `scheduleStart` | — | ✅ start | ✅ start | ✅ start |
| `scheduleStop` | ✅ wrap | ✅ stop | ✅ stop | ✅ stop |
| `stopOnStationary` | ✅ wrap | ✅ stop | ✅ stop | ✅ stop |
| `stopAfterElapsed` | ✅ wrap | ✅ stop | ✅ stop | ✅ stop |
| `setConfig()` mid-session | — | — | — | ✅ toggle |
| Location update | ✅ wrap | — | — | — |
| HTTP sync | ✅ wrap | — | — | — |
| Headless engine boot | ✅ wrap | — | — | — |

---

## Requirements

| Mechanism | iOS Version | Permission | Setup |
|---|---|---|---|
| `beginBackgroundTask` | iOS 4+ | None | Automatic |
| `CLBackgroundActivitySession` | iOS 17+ | Location Always | Automatic (no-op on older iOS) |
| `CLServiceSession` | iOS 18+ | Location Always or When In Use | Automatic (no-op on older iOS) |
| Prevent Suspend | iOS 14+ | None | Set `AppConfig.preventSuspend: true` |

No additional Info.plist keys or capabilities are needed beyond the standard location background mode:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
</array>
```

---

## Debugging

Enable verbose logging to see background task activity:

```dart
await Tracelet.ready(Config(
  logger: LoggerConfig(
    debug: true,
    logLevel: LogLevel.verbose,
  ),
));
```

You'll see log entries like:
```
[BackgroundTaskHelper] begin: httpSync → taskId 1
[BackgroundTaskHelper] end: httpSync → taskId 1
[BackgroundTaskHelper] begin: locationUpdate → taskId 2
[BackgroundTaskHelper] end: locationUpdate → taskId 2
[BackgroundActivitySessionManager] start — CLBackgroundActivitySession created
[ServiceSessionManager] start — CLServiceSession created (fullAccuracy)
```

---

## Battery Impact

| Mechanism | Battery Impact | Notes |
|---|---|---|
| `beginBackgroundTask` | Negligible | Only extends runtime by seconds, not minutes |
| `CLBackgroundActivitySession` | None | Informational hint to iOS, no extra power draw |
| `CLServiceSession` | None | Authorization maintenance only |
| Prevent Suspend | Low–Moderate | Silent audio prevents deep sleep; use only when needed |

**Recommendation:** Leave `preventSuspend: false` (default) unless you need sub-second location delivery in the background. The other three mechanisms provide robust protection without any battery penalty.
