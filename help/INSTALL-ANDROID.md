# Android Setup Guide

This guide covers everything you need to configure in your Flutter app's Android project to use Tracelet.

---

## 1. Minimum Requirements

| Requirement        | Value             |
|--------------------|-------------------|
| `minSdk`           | **26** (Android 8.0 Oreo) |
| `compileSdk`       | **34+** (recommended 36) |
| `targetSdk`        | **34+** |
| Kotlin             | **1.9+** |
| Gradle AGP         | **8.0+** |

In your app's `android/app/build.gradle`:

```groovy
android {
    compileSdk = 36   // or 34+

    defaultConfig {
        minSdk = 26
        targetSdk = 36
    }
}
```

---

## 2. Permissions

Tracelet's plugin AndroidManifest automatically merges the following permissions into your app:

| Permission | Purpose |
|---|---|
| `ACCESS_FINE_LOCATION` | GPS location |
| `ACCESS_COARSE_LOCATION` | Network location |
| `ACCESS_BACKGROUND_LOCATION` | Background tracking (Android 10+) |
| `FOREGROUND_SERVICE` | Foreground service |
| `FOREGROUND_SERVICE_LOCATION` | Location-type foreground service (Android 14+) |
| `ACTIVITY_RECOGNITION` | Motion activity detection |
| `RECEIVE_BOOT_COMPLETED` | Start on boot |
| `WAKE_LOCK` | Background processing |
| `ACCESS_NETWORK_STATE` | Connectivity monitoring |
| `INTERNET` | HTTP sync |
| `POST_NOTIFICATIONS` | Notification (Android 13+) |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Battery optimization exemption dialog |
| `SCHEDULE_EXACT_ALARM` | Exact alarms for `periodicUseExactAlarms` / `scheduleUseAlarmManager` (Android 12+). Not granted by default on Android 13+; plugin falls back to inexact alarms if not granted. |

**You do not need to add these to your app's `AndroidManifest.xml`** — they are merged automatically from the plugin.

> **Play Store requirement:** The `ACCESS_BACKGROUND_LOCATION` permission
> triggers a **mandatory declaration** in the Google Play Console, including a
> short video. See [Play Store Declaration Guide](PLAY-STORE-DECLARATION.md)
> for step-by-step instructions.

> **Don't need all permissions?** You can remove optional permissions like
> `ACCESS_BACKGROUND_LOCATION`, `ACTIVITY_RECOGNITION`, `POST_NOTIFICATIONS`,
> and `SCHEDULE_EXACT_ALARM` using Android's manifest merger `tools:node="remove"`
> directive. Tracelet degrades gracefully — no crashes. See
> [Removing Permissions](PLAY-STORE-DECLARATION.md#removing-other-optional-permissions)
> for examples.

### Runtime Permissions

The plugin requests permissions at runtime when you call `Tracelet.requestLocationAuthorization()`. The flow is:

1. `ACCESS_FINE_LOCATION` (or `ACCESS_COARSE_LOCATION`)
2. `ACCESS_BACKGROUND_LOCATION` (separate dialog on Android 11+)
3. `ACTIVITY_RECOGNITION` (Android 10+)
4. `POST_NOTIFICATIONS` (Android 13+)

---

## 3. Foreground Service Notification

When background tracking is active, Android requires a persistent notification. Configure it in your `Config`:

```dart
await Tracelet.ready(Config(
  app: AppConfig(
    foregroundService: ForegroundServiceConfig(
      channelId: 'tracelet_channel',
      channelName: 'Location Tracking',
      notificationTitle: 'My App',
      notificationText: 'Tracking your route',
      notificationSmallIcon: 'drawable/ic_notification',
      notificationPriority: NotificationPriority.defaultPriority,
    ),
  ),
));
```

### Custom Notification Icon

Place your icon in `android/app/src/main/res/drawable/`:

```
android/app/src/main/res/
  drawable/
    ic_notification.png      (24×24dp)
  drawable-hdpi/
    ic_notification.png      (36×36px)
  drawable-xhdpi/
    ic_notification.png      (48×48px)
  drawable-xxhdpi/
    ic_notification.png      (72×72px)
```

Reference it as `'drawable/ic_notification'` (without the extension).

---

## 4. Background Location on Android 11+

Starting with Android 11 (API 30), **background location must be granted separately** from foreground location. The user must:

1. Grant "While using the app" first
2. Then go to Settings → grant "Allow all the time"

Tracelet handles this flow automatically when you call `Tracelet.requestLocationAuthorization()`.

---

## 5. Battery Optimization

Some OEMs (Samsung, Xiaomi, Huawei, OnePlus, etc.) aggressively kill background apps. To ensure reliable tracking:

```dart
// Check if app is whitelisted
final ignored = await Tracelet.isIgnoringBatteryOptimizations();

if (!ignored) {
  // Prompt user to whitelist the app
  await Tracelet.requestSettings('ignoreBackgroundOptimizations');
}
```

> **Tip:** Visit [dontkillmyapp.com](https://dontkillmyapp.com) for device-specific guidance.

---

## 6. ProGuard / R8 Rules

Tracelet uses Google Play Services and OkHttp, which have their own ProGuard rules bundled with their AARs. No additional ProGuard configuration is needed for release builds.

If you encounter issues, add to `android/app/proguard-rules.pro`:

```proguard
-keep class com.tracelet.** { *; }
-keep class com.google.android.gms.location.** { *; }
```

And in `android/app/build.gradle`:

```groovy
buildTypes {
    release {
        minifyEnabled true
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'),
                      'proguard-rules.pro'
    }
}
```

---

## 7. Google Play Services (Optional)

Tracelet uses the **Fused Location Provider** from Google Play Services for high-accuracy tracking and activity recognition. In version 2.0.0+, this is an **optional dependency**.

If you do NOT include it, the SDK will fall back to standard AOSP `LocationManager` (GPS/Network).

To enable high-accuracy GMS tracking, add this to your `android/app/build.gradle.kts`:
```kotlin
dependencies {
    implementation("com.google.android.gms:play-services-location:21.3.0")
}
```

---

## 8. Start on Boot

To resume tracking after a device reboot:

```dart
await Tracelet.ready(Config(
  app: AppConfig(
    stopOnTerminate: false,  // Keep tracking when app is killed
    startOnBoot: true,       // Resume after reboot
  ),
));
```

The plugin automatically registers a `BOOT_COMPLETED` broadcast receiver. On boot, it reads the persisted `trackingMode` and restores the correct mode:

| Tracking Mode | Boot Recovery Behavior |
|---|---|
| **Continuous** (0) | Starts foreground service with native `LocationEngine` |
| **Geofences** (1) | Starts foreground service; geofences re-registered via Google Play Services |
| **Periodic/WorkManager** (2) | Re-schedules `WorkManager` periodic work — **no foreground service, no notification** |
| **Periodic/Exact Alarms** (2) | Re-schedules `AlarmManager` exact alarms + `OneTimeWorkRequest` — **no foreground service** |
| **Periodic/FG Service** (2) | Starts foreground service with periodic timer |

> **Note:** For periodic mode without foreground service, boot recovery is entirely notification-free. The GPS icon only appears briefly (~5 sec) during each scheduled fix.

---

## 9. Headless Mode

To execute Dart code in the background when the app is terminated:

```dart
// Must be a top-level or static function
void headlessTask(HeadlessEvent event) {
  print('[Headless] ${event.name}: ${event.event}');
}

// Register in your main()
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Tracelet.registerHeadlessTask(headlessTask);
  runApp(MyApp());
}
```

---

## 10. Example AndroidManifest.xml

Here is a minimal `AndroidManifest.xml` for your app. Tracelet's permissions are merged automatically — you only need your app-specific entries:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="My App"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme" />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>

        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
```

---

## 11. Optional Dependencies (Enterprise & Performance)

Tracelet 2.0.0+ adopts an "on-demand" dependency model to keep your APK size small. Add only what you need to your **app-level** `build.gradle.kts`:

### High-Accuracy GMS & Activity Recognition
Enables the Fused Location Provider and `onActivityChange` events.
```kotlin
implementation("com.google.android.gms:play-services-location:21.3.0")
```

### Database Encryption (SQLCipher)
Enables AES-256 SQLite encryption for the local database.
```kotlin
implementation("net.zetetic:sqlcipher-android:4.6.1@aar")
implementation("androidx.security:security-crypto:1.1.0")
```

### Device Attestation (Play Integrity)
Enables `getAttestationToken()` and advanced tamper detection.
```kotlin
implementation("com.google.android.play:integrity:1.6.0")
```

**Estimated Size Impact:**
* **GMS Location:** ~1.2 MB
* **SQLCipher:** ~7.5 MB per ABI (use App Bundles to minimize)
* **Play Integrity:** ~0.5 MB

See [Database Encryption](DATABASE-ENCRYPTION.md) and [Device Attestation](DEVICE-ATTESTATION.md) for full setup details.

---

## Troubleshooting

### Location updates stop after a few minutes
- Ensure `stopOnTerminate: false`
- Check battery optimization settings
- Enable `debug: true` in `LoggerConfig` to see logs

### "App is running in the background" notification
- This is the required foreground service notification
- Customize it via `ForegroundServiceConfig`

### Permission denied errors
- Call `Tracelet.requestLocationAuthorization()` before `Tracelet.start()`
- On Android 11+, background location requires a separate grant

### Build errors with Google Play Services
- Ensure your `compileSdk` is 34+
- Run `./gradlew dependencies` to check for version conflicts
