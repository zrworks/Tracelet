# tracelet_ios

📚 **Official Documentation:** [tracelet.ikolvi.com](https://tracelet.ikolvi.com)


[![Pub Package](https://img.shields.io/pub/v/tracelet_ios.svg)](https://pub.dev/packages/tracelet_ios)

iOS implementation of the [Tracelet](https://pub.dev/packages/tracelet) background geolocation plugin.

This package uses Swift and native Apple frameworks (CoreLocation, CoreMotion, BackgroundTasks, SQLite3) to provide production-grade background location tracking.

## Native Features

- **Kalman Filter GPS Smoothing** — Extended Kalman Filter implementation (`KalmanLocationFilter.swift`) smooths raw GPS coordinates using device-reported accuracy as measurement noise. Produces cleaner tracks and eliminates jitter. [Learn more →](https://github.com/Ikolvi/Tracelet/blob/main/help/KALMAN-FILTER.md)
- **Trip Detection** — `TripManager.swift` tracks motion state transitions to detect trip start/stop. Each trip includes distance, duration, waypoints, and start/stop locations. [Learn more →](https://github.com/Ikolvi/Tracelet/blob/main/help/TRIP-DETECTION.md)
- **Polygon Geofences** — Ray-casting point-in-polygon algorithm in `GeofenceManager.swift` for arbitrary polygon containment checks alongside circular geofences. [Learn more →](https://github.com/Ikolvi/Tracelet/blob/main/help/POLYGON-GEOFENCES.md)
- **Mock Location Detection** — Spoof detection using `CLLocationSourceInformation` (iOS 15+) and timestamp drift heuristic. Configurable via `MockDetectionLevel`. [Learn more →](https://github.com/Ikolvi/Tracelet/blob/main/help/MOCK-DETECTION.md)
- **OEM Compatibility** — iOS has no OEM-specific power management issues. The Settings Health API returns `isAggressiveOem: false` and an empty `oemSettingsScreens` list. [Learn more →](https://github.com/Ikolvi/Tracelet/blob/main/help/OEM-COMPATIBILITY.md)
- **Unlimited Geofences** — Proximity-based auto-load/unload in `GeofenceManager.swift`. Only the closest geofences within `geofenceProximityRadius` are registered with CLLocationManager (up to 20, the iOS limit), enabling monitoring of thousands of geofences. Geofences are dynamically swapped on each location update with `geofencesChange` events.
- **Background Task Protection** — All critical native operations (location persist, HTTP sync, headless engine boot, lifecycle transitions) are wrapped in `UIApplication.beginBackgroundTask` to prevent iOS from killing the app mid-operation.
- **iOS 17+ Background Activity Session** — `CLBackgroundActivitySession` extends background runtime for continuous location tracking without user interaction.
- **iOS 18+ Service Session** — `CLServiceSession` maintains location authorization state during background execution.
- **HTTP Sync Retry Engine** — Configurable retry with exponential backoff in `HttpSyncManager.swift` for transient 5xx, 429, and timeout failures. Defers sync on connectivity loss via `NWPathMonitor`. [Learn more →](https://github.com/Ikolvi/Tracelet/blob/main/help/HTTP-SYNC.md)
- **Configurable Motion Sensitivity** — `MotionDetector.swift` reads `shakeThreshold`, `stillThreshold`, and `stillSampleCount` from config at runtime (auto-converts m/s² to g-force).
- **Delta Encoding** — Native `DeltaEncoder.swift` compresses HTTP sync payloads by encoding only field deltas between consecutive locations, achieving 60–80% bandwidth reduction. Uses Foundation's `ISO8601DateFormatter` with fractional seconds fallback.
- **Wi-Fi-Only Sync** — `HttpSyncManager.swift` supports `disableAutoSyncOnCellular` to skip auto-sync on cellular networks.

## Usage

**You should not depend on this package directly.** Instead, depend on [`tracelet`](https://pub.dev/packages/tracelet) which automatically includes this package on iOS builds.

```yaml
dependencies:
  tracelet: ^1.1.0
```

For iOS-specific setup (Info.plist, capabilities, entitlements), see the [iOS Setup Guide](https://github.com/Ikolvi/Tracelet/blob/main/help/INSTALL-IOS.md).

## Related Packages

| Package | Description |
|---|---|
| [`tracelet`](https://pub.dev/packages/tracelet) | App-facing Dart API — the only package you depend on |
| [`tracelet_platform_interface`](https://pub.dev/packages/tracelet_platform_interface) | Abstract platform interface |
| [`tracelet_android`](https://pub.dev/packages/tracelet_android) | Android implementation |
| [`tracelet_web`](https://pub.dev/packages/tracelet_web) | Web implementation |

## More Information

- [GitHub Repository](https://github.com/Ikolvi/Tracelet)
- [Documentation](https://github.com/Ikolvi/Tracelet/tree/main/help)
- [Issue Tracker](https://github.com/Ikolvi/Tracelet/issues)

