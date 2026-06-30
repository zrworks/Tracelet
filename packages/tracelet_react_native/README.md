# @ikolvi/tracelet

Production-grade **background geolocation** for React Native. Battery-conscious
motion detection, geofencing (circular + polygon), SQLite persistence, HTTP sync
with delta encoding, crash & fall detection, driving telematics, and enterprise
audit/privacy features — powered by a shared Rust core.

> This is the React Native binding for [Tracelet](https://tracelet.ikolvi.com).
> It wraps the framework-agnostic native SDKs (`com.ikolvi:tracelet-sdk` on
> Android, `TraceletSDK` on iOS) and exposes the full Tracelet API to JS/TS.

## Requirements

- React Native **0.73+** (New Architecture supported; works under the bridge
  interop layer on the old architecture too).
- **Android**: `minSdkVersion 26+`.
- **iOS**: `14.0+`.

## Install

```sh
npm install @ikolvi/tracelet
# or
yarn add @ikolvi/tracelet
```

### iOS

```sh
cd ios && pod install
```

Add the required usage descriptions to `Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We use your location to track trips.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We use your location in the background to track trips.</string>
<key>NSMotionUsageDescription</key>
<string>We use motion data to detect when you start and stop moving.</string>
```

Enable the **Location updates** and **Background processing** background modes
in your target's *Signing & Capabilities*.

### Android

Permissions are merged automatically from the native SDK manifest. No manual
manifest edits are required for the default configuration.

## Quick start

```ts
import { Tracelet } from '@ikolvi/tracelet';

// Subscribe to location updates.
const sub = Tracelet.onLocation((location) => {
  console.log('[location]', location.coords.latitude, location.coords.longitude);
});

// Configure and enable tracking.
const state = await Tracelet.ready({
  desiredAccuracy: 'high',
  distanceFilter: 10,
  stopOnTerminate: false,
  startOnBoot: true,
  url: 'https://api.example.com/locations',
  autoSync: true,
});

if (!state.enabled) {
  await Tracelet.start();
}

// Later…
sub.remove();
```

### React hooks

```tsx
import { useLocation, useTraceletState, useGeofences } from '@ikolvi/tracelet';

function Tracker() {
  const location = useLocation();
  const state = useTraceletState();
  const geofences = useGeofences();
  // …
}
```

## Feature coverage

The TypeScript facade mirrors the Dart `Tracelet` API 1:1, including:

- Tracking lifecycle (`ready`, `start`, `stop`, `startGeofences`, `startPeriodic`, `changePace`)
- On-demand location (`getCurrentPosition`, `getLastKnownLocation`, `watchPosition`)
- Geofencing — circular **and** polygon (`addGeofence`, `addGeofences`, …)
- SQLite persistence & queries (`getLocations`, `getCount`, `insertLocation`, …)
- HTTP sync with delta encoding, dynamic headers, and route context
- Driving telematics, crash & fall detection (`onDrivingEvent`, `onImpact`, `confirmImpact`)
- Enterprise: tamper-evident audit trail, privacy zones, database encryption, device attestation
- Permissions, diagnostics, OEM battery settings, carbon reporting

See the [API reference](https://tracelet.ikolvi.com) for the complete surface.

## Platform notes

- **Headless custom sync-body / header callbacks** are deferred to a future
  release. v1 ships the native default payload plus static/dynamic headers and
  `setRouteContext`.

## License

Apache-2.0 © Kiran Benny Joseph
