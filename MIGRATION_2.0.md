# Migration Guide: Tracelet 2.0.0

Tracelet 2.0.0 is a major milestone that introduces a structured configuration schema, shifts to Pigeon for robust platform-to-Dart communication, and adopts an "on-demand" dependency model on Android to significantly reduce APK size.

## 🚨 Breaking Changes

### 1. Optional Native Dependencies (Android)
To support GMS-free (AOSP) environments and reduce default APK size by **~16 MB**, several features are now optional. You **must** explicitly add these to your `android/app/build.gradle.kts` if you need them:

| Feature | Dependency |
|---|---|
| **High-Accuracy GMS** | `com.google.android.gms:play-services-location:21.3.0` |
| **Encryption** | `net.zetetic:sqlcipher-android:4.6.1@aar` + `androidx.security:security-crypto:1.1.0` |
| **Attestation** | `com.google.android.play:integrity:1.6.0` |

> [!NOTE]
> Without `play-services-location`, the SDK falls back to standard AOSP `LocationManager` (standard GPS).

### 2. Configuration Schema Refactoring
The `Config` object has been refactored from a partially flat structure to a fully structured, compound model. Fields are now grouped into logical sections.

#### Before (Tracelet 1.x):
```dart
tl.Config(
  desiredAccuracy: tl.DesiredAccuracy.high,
  distanceFilter: 10.0,
  stopOnTerminate: false,
  notificationTitle: 'Tracking', // Top-level
)
```

#### After (Tracelet 2.0.0):
```dart
tl.Config(
  geo: tl.GeoConfig(
    desiredAccuracy: tl.DesiredAccuracy.high,
    distanceFilter: 10.0,
  ),
  app: tl.AppConfig(
    stopOnTerminate: false,
  ),
  android: tl.AndroidConfig(
    foregroundService: tl.ForegroundServiceConfig(
      notificationTitle: 'Tracking',
    ),
  ),
)
```

#### Field Mapping Cheat Sheet:
| 1.x Field | 2.0.0 Path |
|---|---|
| `desiredAccuracy` | `geo.desiredAccuracy` |
| `distanceFilter` | `geo.distanceFilter` |
| `stationaryRadius` | `geo.stationaryRadius` |
| `locationTimeout` | `geo.locationTimeout` |
| `stopOnTerminate` | `app.stopOnTerminate` |
| `startOnBoot` | `app.startOnBoot` |
| `heartbeatInterval` | `app.heartbeatInterval` |
| `schedule` | `app.schedule` |
| `url`, `method`, `headers` | `http.url`, `http.method`, `http.headers` |
| `debug`, `logLevel` | `logger.debug`, `logger.logLevel` |
| `stopTimeout` | `motion.stopTimeout` |
| `geofenceProximityRadius`| `geofence.geofenceProximityRadius` |
| `notificationTitle` | `android.foregroundService.notificationTitle` |
| `rejectMockLocations` | `geo.filter.rejectMockLocations` |
| `mockDetectionLevel` | `geo.filter.mockDetectionLevel` |
| `encryptDatabase` | `security.encryptDatabase` |

### 3. Pigeon-Based Platform Interface
Tracelet now uses **Pigeon** for all platform-to-native communication.
*   **Dart**: Method calls to `TraceletPlatform.instance` now use strictly typed Pigeon models instead of `Map<String, dynamic>`.
*   **Native (Android/iOS)**: If you have custom native implementations or rely on manual method channel calls, these will break. You must align with the generated `TraceletHostApi` and `TraceletFlutterApi` interfaces.

### 4. Renamed Enums & Types
Many types have been renamed to follow the `Tl` prefix convention in the platform interface, though the public-facing Dart enums mostly remain stable.
*   `LocationAuthorizationRequest` → `tl.LocationAuthorizationRequest` (verified stable)
*   `ActivityType` → `tl.ActivityType` (verified stable)

## 🛠️ Migration Steps

1.  **Update `pubspec.yaml`**: Bump `tracelet` to `^2.0.0`.
2.  **Android Dependencies**: Add required GMS/Enterprise dependencies to `android/app/build.gradle.kts`.
3.  **Refactor Config**: Update your `Tracelet.ready(Config.balanced().copyWith(...))` call to use the new nested `GeoConfig`, `AppConfig`, etc.
4.  **Check JSON Payloads**: If you use `toDictionary()` or `toMap()` on locations for your own logic, ensure you account for the move to camelCase for fields like `isMoving` and `isCharging`.

## 📦 ProGuard / R8
Tracelet 2.0.0 includes internal `-dontwarn` rules. Your build will not fail if you exclude optional dependencies. If you include them, R8 will automatically detect and keep required classes.
