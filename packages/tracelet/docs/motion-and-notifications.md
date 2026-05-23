# Advanced Configuration: Motion Detection & Smart Notifications

Tracelet v2.0.7 introduced powerful new capabilities for managing device battery life, state tracking, and background notification UX. This document explains how to utilize these advanced enterprise features.

---

## 1. Speed-Based Motion Detection

By default, Tracelet uses **Accelerometer-Based** motion detection (`MotionDetectionMode.accelerometer`). This relies on the physical sensors of the device to determine if the user is moving (walking, driving) or stationary (sitting on a desk). 

However, in certain enterprise use cases (e.g., forklift tracking, ferry tracking, train tracking), the device might be physically vibrating or shaking even when it is not actually progressing geographically. In these cases, accelerometer data produces false positives, preventing the SDK from going to sleep.

To solve this, Tracelet provides **Speed-Based Motion Detection** (`MotionDetectionMode.speed`).

### How It Works
Instead of using the accelerometer hardware, Speed-Based detection relies purely on the geographic speed (GPS `m/s`) to dictate whether the device is "moving" or "stationary".

- **`speedMovingThreshold`**: The speed (in m/s) above which the device is considered "moving".
- **`speedStationaryDelay`**: How long (in seconds) the speed must remain *below* the threshold before the device officially enters the `STILL` state and powers down the GPS hardware.
- **`speedWakeConfirmCount`**: How many consecutive location updates above the threshold are required to wake up the SDK from a `STILL` state. This prevents GPS drift spikes from immediately waking the device.

### Example Configuration

```dart
final config = Config(
  motion: MotionConfig(
    // Enable Speed-based detection
    motionDetectionMode: MotionDetectionMode.speed,
    
    // Thresholds
    speedMovingThreshold: 2.5,       // roughly 9 km/h (walking speed)
    speedStationaryDelay: 120,       // wait 2 minutes below threshold to sleep
    speedWakeConfirmCount: 3,        // require 3 consecutive fast fixes to wake
    
    // When stationary, how often should we check the speed to wake up?
    stationaryTrackingMode: StationaryTrackingMode.periodic,
    stationaryPeriodicInterval: 300, // wake up every 5 minutes to check speed
  ),
);
```

> **Note:** Because Speed-Based motion detection disables the accelerometer, the SDK cannot instantly detect when the user starts moving. It relies on `stationaryPeriodicInterval` to periodically wake up the GPS hardware, check the current speed, and determine if tracking should resume.

---

## 2. Smart Notification Visibility (Android)

Android 8.0+ strictly requires a persistent Foreground Service Notification for any app tracking location in the background. While necessary, this persistent notification can clutter the user's notification tray when they are actively using your application in the foreground.

Tracelet solves this with **Smart Notification Visibility** (`showNotificationOnPauseOnly`).

### How It Works
When enabled, the Tracelet Android SDK binds to the `ProcessLifecycleOwner`.
- When the user **opens** the app (Foreground), Tracelet dynamically dismisses the persistent notification, relying on standard OS process prioritization to stay alive.
- When the user **minimizes or closes** the app (Background), Tracelet instantly spins the Foreground Service Notification back up to satisfy Android's background execution limits.

This creates a seamless, polished UX without sacrificing reliability.

### Example Configuration

```dart
final config = Config(
  android: AndroidConfig(
    foregroundService: ForegroundServiceConfig(
      enabled: true,
      notificationTitle: "Live Tracking Active",
      notificationText: "Tracelet is monitoring your location.",
      
      // ✨ Enable Smart Notification Visibility
      showNotificationOnPauseOnly: true,
    ),
  ),
);
```

> **Important:** This feature only applies to Android. On iOS, background location is managed via `UIBackgroundModes` and the blue status bar pill, which handles foreground/background transitions natively.
