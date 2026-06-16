# Configuration Profiles

Tracelet comes with three explicit, predefined tracking profiles designed to simplify setup for different use cases. These profiles encapsulate best practices and parameter combinations for various scenarios, ranging from turn-by-turn navigation to background-only minimal battery tracking. 

Instead of configuring dozens of individual settings, you can start with a baseline profile and override only what you need.

## 1. Balanced (`Config.balanced()`)

> [!TIP]
> **Recommended for most applications.** This profile is tailored for standard social, fleet, or delivery apps, striking the perfect balance between tracking accuracy and battery conservation.

The Balanced profile uses smart motion detection and adaptive mode. It is designed to capture good tracks while the user is actively moving, but gracefully scales back when the user stops or changes behavior.

### Key Characteristics
- **Desired Accuracy:** Medium (`1`) - Typically relies on standard GPS/Network fusion.
- **Distance Filter:** `20.0` meters - A location is recorded if the user moves 20 meters.
- **Stationary Radius:** `50.0` meters - Used to determine when the device has stopped moving.
- **Adaptive Mode:** `true` - The SDK will automatically scale parameters based on battery life and behavior.
- **Elasticity:** Enabled with a multiplier of `1.0` - Scales the distance filter at higher speeds.
- **Android Location Update Interval:** `5000` ms (5 seconds).

### Example
```dart
// Start with balanced and customize
await Tracelet.ready(Config.balanced().copyWith(
  app: AppConfig(stopOnTerminate: false),
  http: HttpConfig(url: "https://api.yourserver.com/locations")
));
```

---

## 2. High Accuracy (`Config.highAccuracy()`)

> [!IMPORTANT]
> **Recommended for navigation and critical tracking.** This profile forces the GPS hardware to stay hot and delivers the most precise, frequent updates at the cost of higher battery drain.

The High Accuracy profile disables adaptive degradation. It forces a tight stationary radius and enables dead reckoning and Kalman filtering to provide smooth, continuous tracks even in challenging environments like urban canyons.

### Key Characteristics
- **Desired Accuracy:** High (`0`) - Forces precise GPS.
- **Distance Filter:** `5.0` meters - Captures very granular movement.
- **Stationary Radius:** `25.0` meters - Tight detection for stops.
- **Adaptive Mode:** `false` - Ensures no degradation of quality occurs even if battery drops.
- **Dead Reckoning:** `true` - Uses inertial sensors to estimate location when GPS drops.
- **Kalman Filter:** `true` - Smooths out GPS noise for prettier polyline tracks.
- **Mock Location Rejection:** `true` - Drops spoofed locations.
- **Android Location Update Interval:** `1000` ms (1 second), with fastest interval `500` ms.
- **Android Geofence High Accuracy Mode:** `true`.

### Example
```dart
// Start with high accuracy for turn-by-turn tracking
await Tracelet.ready(Config.highAccuracy().copyWith(
  geo: GeoConfig(distanceFilter: 2.0) // tighten distance filter even more
));
```

---

## 3. Low Power (`Config.lowPower()`)

> [!TIP]
> **Recommended for background-only, ambient tracking.** This profile is highly battery-sensitive and uses sparse updates and cellular/wifi location providers.

The Low Power profile is ideal for apps that just need to know roughly where a user has been over a day, without draining their battery. It heavily utilizes sparse updates (dropping dense data points) and relies on network-based locations.

### Key Characteristics
- **Desired Accuracy:** Low (`2`) - Often satisfied by Wi-Fi/Cell tower triangulation rather than GPS.
- **Distance Filter:** `50.0` meters.
- **Stationary Radius:** `100.0` meters - Very loose stop detection to save wakeups.
- **Adaptive Mode:** `true` - Aggressively scales back tracking when battery is low.
- **Elasticity Multiplier:** `2.0` - Distance filter scales twice as fast when moving at speed.
- **Sparse Updates:** `true` - Deduplicates location recording to save disk and network overhead.
- **Sparse Distance Threshold:** `100.0` meters.
- **Android Location Update Interval:** `10000` ms (10 seconds).

### Example
```dart
// Start with low power for ambient background tracking
await Tracelet.ready(Config.lowPower().copyWith(
  http: HttpConfig(batchSync: true) // combine with batching for max savings
));
```

## 4. Passive (`Config.passive()`)

> [!TIP]
> **Recommended for extreme battery saving.** This profile never powers on the GPS hardware itself. Instead, it "piggybacks" on GPS requests made by other apps (like Google Maps or fitness trackers) to quietly collect location data.

The Passive profile is the ultimate battery saver. It is highly effective on Android where the `FusedLocationProviderClient` supports a passive priority. On iOS, it degrades gracefully to a very low accuracy setting (`3000` meters) to minimize wakeups.

### Key Characteristics
- **Desired Accuracy:** Lowest Unbiased (`4`) - Maps to `PRIORITY_PASSIVE` on Android and `kCLLocationAccuracyThreeKilometers` on iOS.
- **Distance Filter:** `0.0` meters - Collects everything it can passively grab.
- **Stationary Radius:** `500.0` meters - Loose stop detection.
- **Adaptive Mode:** `false` - It's already at the lowest possible state.
- **Sparse Updates:** `true` - Drops duplicate passive locations within 50 meters.
- **Android Location Update Interval:** `60000` ms (1 minute) to throttle aggressive passive streams.

### Example
```dart
// Start with passive mode to steal GPS from other apps
await Tracelet.ready(Config.passive().copyWith(
  app: AppConfig(stopOnTerminate: true)
));
```

## How Profiles Map Internally

When you call `Config.balanced()`, the SDK is internally deserializing a predefined JSON payload that sets all the core `GeoConfig`, `MotionConfig`, and `AndroidConfig` options. Any overrides you supply via `copyWith(...)` simply replace the values from the base profile.

This system guarantees that future improvements made by the Tracelet team to the baseline configurations will automatically be applied to your app when you upgrade the SDK, as long as you aren't manually overriding those specific parameters.
