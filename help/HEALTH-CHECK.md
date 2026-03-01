# Health Check API

The Health Check API provides a **single-call diagnostic snapshot** of
Tracelet's operational state. It aggregates 10 platform queries into one
typed `HealthCheck` object with auto-detected warnings — no manual plumbing
required.

Use it for:
- **Pre-flight checks** before starting tracking
- **Monitoring dashboards** showing device health in fleet apps
- **Support diagnostics** — export the health check to your backend
- **CI integration tests** verifying environment readiness

---

## Quick Start

```dart
final health = await Tracelet.getHealth();

if (!health.isHealthy) {
  for (final warning in health.warnings) {
    print('⚠ $warning');
  }
}

print('Tracking: ${health.trackingEnabled}');
print('Permission: ${health.locationPermission}');
print('Battery optimized: ${!health.isIgnoringBatteryOptimizations}');
print('Pending sync: ${health.locationCount} locations');
```

---

## What It Checks

`getHealth()` fires **10 platform calls in parallel** via `Future.wait`:

1. `getState()` — Tracking status, moving state, odometer
2. `getProviderState()` — Location services, GPS/network availability
3. `getPermissionStatus()` — Location authorization level
4. `getMotionPermissionStatus()` — Activity recognition permission
5. `requestTemporaryFullAccuracy()` — Accuracy authorization (iOS 14+)
6. `isPowerSaveMode` — Device battery saver state
7. `isIgnoringBatteryOptimizations()` — Battery exemption (Android)
8. `getSensors()` — Hardware sensor availability
9. `getDeviceInfo()` — Manufacturer, model, OS version
10. `getCount()` — Pending unsynced location count

All calls are read-only. No permissions are triggered, no state is changed.

---

## Auto-Detected Warnings

The `warnings` list is computed automatically from the diagnostic data.
Each warning maps to a `HealthWarning` enum value:

| Warning                            | Condition                                      | Impact                                        |
|------------------------------------|-------------------------------------------------|-----------------------------------------------|
| `locationPermissionDenied`         | Permission is denied or not determined          | No location data will be received             |
| `locationPermissionDeniedForever`  | Permission permanently denied                   | User must open system settings manually       |
| `locationPermissionOnlyWhenInUse`  | Only "when in use" permission granted           | Background tracking will not work reliably    |
| `locationServicesDisabled`         | Device location services are off                | No provider can deliver locations              |
| `powerSaveMode`                    | Battery saver is active                         | OS may throttle background location           |
| `aggressiveOem`                    | Manufacturer kills background apps              | Tracking may be killed silently               |
| `batteryOptimizationsNotIgnored`   | App not exempt from battery optimization        | Android may kill foreground service           |
| `reducedAccuracy`                  | Approximate location only (iOS 14+)             | ~5 km accuracy, unusable for most use cases   |
| `noAccelerometer`                  | No accelerometer sensor detected                | Motion detection (stationary/moving) fails    |
| `noSignificantMotion`              | No significant-motion sensor                    | Low-power wake-from-stationary unavailable    |
| `motionPermissionDenied`           | Activity recognition permission denied          | Falls back to accelerometer-only detection    |
| `mockLocationsDetected`            | Provider reports mock/spoofed locations          | Location data may be unreliable               |

### Convenience Properties

```dart
health.isHealthy         // true when warnings list is empty
health.hasWarnings       // opposite of isHealthy
health.warningCount      // number of warnings
health.hasBackgroundPermission  // "always" + services enabled
```

---

## Full Field Reference

### Tracking State

| Field                    | Type           | Description                                     |
|--------------------------|----------------|-------------------------------------------------|
| `trackingEnabled`        | `bool`         | Whether tracking is active                      |
| `trackingMode`           | `TrackingMode`   | `location` or `geofences`                      |
| `isMoving`               | `bool`         | Current motion state                            |
| `odometer`               | `double`       | Distance in meters since start                  |
| `schedulerEnabled`       | `bool`         | Schedule-based tracking active                  |
| `didLaunchInBackground`  | `bool`         | Launched via boot/schedule (not user)            |
| `didDeviceReboot`        | `bool`         | Device rebooted and tracking restarted          |

### Permissions

| Field                    | Type                     | Description                        |
|--------------------------|--------------------------|------------------------------------|
| `locationPermission`     | `AuthorizationStatus`    | `notDetermined`, `denied`, `whenInUse`, `always`, `deniedForever` |
| `motionPermission`       | `int`                    | 0=notDetermined, 1=restricted, 2=denied, 3=authorized |
| `accuracyAuthorization`  | `AccuracyAuthorization`  | `full` or `reduced` (iOS 14+)     |

### Provider

| Field                    | Type    | Description                                      |
|--------------------------|---------|--------------------------------------------------|
| `locationServicesEnabled`| `bool`  | Device-level location is on                      |
| `gpsEnabled`             | `bool`  | GPS provider available (Android)                 |
| `networkEnabled`         | `bool`  | Network provider available (Android)             |

### Battery & Power

| Field                              | Type    | Description                              |
|------------------------------------|---------|------------------------------------------|
| `isPowerSaveMode`                  | `bool`  | Battery saver active                     |
| `isIgnoringBatteryOptimizations`   | `bool`  | Exempt from Android battery optimization |

### OEM Health

| Field              | Type     | Description                                         |
|--------------------|----------|-----------------------------------------------------|
| `manufacturer`     | `String` | Device manufacturer (e.g., "Samsung", "Xiaomi")     |
| `model`            | `String` | Device model name                                   |
| `isAggressiveOem`  | `bool`   | Known aggressive background killer                  |
| `aggressionRating` | `int`    | OEM aggression score (0–5, from dontkillmyapp.com)  |

### Sensors

| Field                | Type    | Description                              |
|----------------------|---------|------------------------------------------|
| `hasAccelerometer`   | `bool`  | Accelerometer available                  |
| `hasGyroscope`       | `bool`  | Gyroscope available                      |
| `hasMagnetometer`    | `bool`  | Magnetometer available                   |
| `hasSignificantMotion`| `bool` | Significant-motion sensor available      |

### Database & Device

| Field            | Type       | Description                              |
|------------------|------------|------------------------------------------|
| `locationCount`  | `int`      | Unsynced locations in database           |
| `platform`       | `String`   | `"android"` or `"ios"`                   |
| `osVersion`      | `String`   | OS version string                        |
| `timestamp`      | `DateTime` | When the health check was taken          |

### Diagnostics

| Field                    | Type    | Description                              |
|--------------------------|---------|------------------------------------------|
| `mockLocationsDetected`  | `bool`  | Mock/spoofed locations detected          |
| `warnings`               | `List<HealthWarning>` | Auto-computed warning list |

---

## Serialization

`HealthCheck` supports full serialization for logging, storage, or server sync:

```dart
final health = await Tracelet.getHealth();

// Serialize to map
final map = health.toMap();

// Restore from map
final restored = HealthCheck.fromMap(map);

// Warnings are preserved as indices and restored as enum values
assert(restored.warnings == health.warnings);
```

The `timestamp` serializes as ISO 8601 and `warnings` serialize as integer
indices, both round-tripping safely.

---

## Example: Pre-Flight Check

```dart
Future<bool> isDeviceReady() async {
  final health = await Tracelet.getHealth();

  if (!health.hasBackgroundPermission) {
    showDialog('Background location permission required');
    return false;
  }

  if (health.warnings.contains(HealthWarning.batteryOptimizationsNotIgnored)) {
    showDialog('Please disable battery optimization for this app');
    await Tracelet.openBatterySettings();
    return false;
  }

  if (health.warnings.contains(HealthWarning.aggressiveOem)) {
    showDialog(
      '${health.manufacturer} devices may kill background apps. '
      'Please follow the instructions at dontkillmyapp.com.',
    );
  }

  return health.isHealthy;
}
```

## Example: Fleet Monitoring Dashboard

```dart
// Send health data to your backend every 5 minutes
Timer.periodic(Duration(minutes: 5), (_) async {
  final health = await Tracelet.getHealth();
  await http.post(
    Uri.parse('https://api.example.com/device-health'),
    body: jsonEncode(health.toMap()),
  );
});
```

## Example: Support Diagnostics

```dart
void onSupportButtonTapped() async {
  final health = await Tracelet.getHealth();
  final report = StringBuffer()
    ..writeln('=== Tracelet Health Report ===')
    ..writeln('Tracking: ${health.trackingEnabled}')
    ..writeln('Mode: ${health.trackingMode}')
    ..writeln('Permission: ${health.locationPermission}')
    ..writeln('Services: ${health.locationServicesEnabled}')
    ..writeln('Battery saver: ${health.isPowerSaveMode}')
    ..writeln('OEM: ${health.manufacturer} ${health.model}')
    ..writeln('Aggressive: ${health.isAggressiveOem}')
    ..writeln('Pending locations: ${health.locationCount}')
    ..writeln('Warnings: ${health.warnings}')
    ..writeln('Timestamp: ${health.timestamp}');

  // Copy to clipboard or email
  Clipboard.setData(ClipboardData(text: report.toString()));
}
```
