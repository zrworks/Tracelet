# Tracelet Doctor

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Pub Package](https://img.shields.io/pub/v/tracelet_doctor.svg)](https://pub.dev/packages/tracelet_doctor)

> **Drop-in diagnostic overlay for Tracelet** — visualize permissions, OEM health, battery state, sensors, and tracking status in a single tap.

## Screenshot

The Doctor shows a premium dark-themed bottom sheet with:

- ⚠️ **Warnings** — actionable issues (permission denied, power save, aggressive OEM, mock GPS, etc.)
- 🛡️ **Permissions** — location, motion activity, accuracy authorization
- 📍 **Tracking State** — enabled/disabled, mode, motion, odometer, scheduler
- 🔋 **Battery & OEM** — power save, battery optimization, manufacturer, aggression rating meter
- 📡 **Sensors** — accelerometer, gyroscope, magnetometer, significant-motion
- 💾 **Database & Device** — pending location count, mock detection, platform, OS version

## Quick Start

```yaml
dependencies:
  tracelet: ^2.0.4
  tracelet_doctor: ^1.0.0
```

```dart
import 'package:tracelet_doctor/tracelet_doctor.dart';

// Show the diagnostic sheet:
TraceletDoctor.show(context);
```

That's it — one line. No setup, no configuration.

## Features

- **Zero native code** — pure Dart/Flutter widget
- **One-line integration** — `TraceletDoctor.show(context)`
- **Dark glassmorphic theme** — premium aesthetic with semantic status colors
- **12 warning types** — automatically computed from device state
- **Copy to clipboard** — export the full diagnostic JSON for sharing
- **Re-run** — refresh diagnostics without dismissing the sheet
- **Loading state** — animated pulse indicator while gathering data
- **Error handling** — graceful retry on platform call failures

## How It Works

The Doctor calls `Tracelet.getHealth()` internally, which fires 10 parallel platform calls:

1. `getState()` — tracking enabled, mode, motion, odometer
2. `getProviderState()` — location services, GPS, network, accuracy
3. `getSettingsHealth()` — OEM manufacturer, aggression rating
4. `getSensors()` — accelerometer, gyroscope, magnetometer, sig-motion
5. `getDeviceInfo()` — platform, OS version
6. `isPowerSaveMode()` — battery saver active
7. `isIgnoringBatteryOptimizations()` — app exemption status
8. `getPermissionStatus()` — location authorization
9. `getMotionPermissionStatus()` — motion/activity recognition
10. `getCount()` — pending locations in the database

All results are aggregated into a typed `HealthCheck` object with automatically computed `warnings`.

## Architecture

This is a **separate, optional package** in the Tracelet monorepo:

| Package | Description |
|---|---|
| `tracelet` | Core SDK — the only package apps depend on |
| **`tracelet_doctor`** (this package) | Diagnostic overlay widget |
| `tracelet_platform_interface` | Abstract platform interface |
| `tracelet_android` | Kotlin Android implementation |
| `tracelet_ios` | Swift iOS implementation |
| `tracelet_web` | Web implementation |

## License

Apache 2.0 — see [LICENSE](../../LICENSE) for details.
