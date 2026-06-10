# FAQ

## What happens if the user turns off location services while tracking is active?

**Short answer:** Tracelet does **not** stop, crash, or tear down tracking. It keeps
the tracking session armed, emits a **`providerchange`** event so your app can react,
records no new locations while location is off (with two platform-specific
exceptions below), and **automatically resumes** delivering locations the moment the
user re-enables location — in every state (foreground, background, terminated). You do
**not** need to call `start()` again.

> "Location services off" here means the OS-level location toggle (Android: *Settings →
> Location*; iOS: *Settings → Privacy → Location Services*). Revoking the app's
> *permission* is a related but separate case — see [the permission note](#what-about-revoking-the-apps-permission-vs-turning-the-toggle-off).

### How to detect it

Listen for the provider-change event and check `enabled`:

```dart
final sub = tl.Tracelet.onProviderChange((tl.ProviderChangeEvent e) {
  if (!e.enabled) {
    // Location services were turned OFF — prompt the user / show a banner.
  } else {
    // Back ON — Tracelet has already resumed; no action required.
  }
});
```

`ProviderChangeEvent` carries: `enabled`, `status` (authorization), `gps`, `network`,
`accuracyAuthorization`, `gpsFallback`, and `mockLocationsDetected`. The same event is
also delivered to the **headless** callback in the background/killed state (if you've
registered one), and is persisted to the local DB as a `providerchange` record unless
you set `disableProviderChangeRecord: true`.

### Behavior by state and platform

| State | Android | iOS |
|---|---|---|
| **Foreground** | `providerchange` (`enabled: false`) fires; the foreground service stays alive; no new fixes until re-enabled. | `providerchange` fires; `didFailWithError` is handled gracefully (one-shots fall back to the last known location); no new fixes. |
| **Background** | Foreground service (and its notification) **keeps running**; fused updates simply stop; `providerchange` still dispatched. Resumes on re-enable. | The `CLLocationManager` subscription stays registered; iOS delivers nothing until location returns, then resumes (and can relaunch the app via region/SLC). |
| **Terminated (killed)** | If a background/boot session is active (`stopOnTerminate: false` / `startOnBoot`), the service is running and behaves as *Background* above. If the process isn't alive, nothing runs until the OS next starts it. | iOS relaunches the app via significant-location / region monitoring **only when a location/region event occurs** — which it can't while location is off. Once the user re-enables it, the next qualifying event relaunches and resumes tracking. |

In all cases the session state is preserved, so re-enabling location resumes tracking
automatically without re-initialization.

### What Tracelet does *not* do

- It does **not** auto-stop the tracking session or clear your config/state.
- It does **not** throw or crash — the platform "location off / denied" error is caught.
- It does **not** fabricate locations (except Android dead reckoning, below) — your DB
  simply has a gap for the period location was off.

### Platform specifics worth knowing

**Android**
- **GPS-only toggle vs. full off:** If the user disables *GPS* but Wi-Fi/cell
  positioning is still available, Tracelet automatically **falls back** to
  balanced-power (network) positioning and emits `providerchange` with
  `gpsFallback: true`, restoring full accuracy when GPS returns. If **all** location is
  off, no fixes are produced.
  - **These approximate (Wi-Fi/cell-tower) fixes *are* recorded and synced** — they are
    not dropped. Each location is tagged with `locationSource` (`"gps"` ≤50 m,
    `"wifi"` ≤200 m, `"cell"` worse, `"network"` during fallback) and its real
    `coords.accuracy` in metres, so you can distinguish or filter them. Tracelet does
    not reject by accuracy; instead it keeps low-accuracy fixes out of the **odometer**
    (`odometerAccuracyThreshold`, default 50 m) and drops impossible-speed jumps
    (`maxImpliedSpeed`). If you want GPS-quality only, filter by
    `locationSource == "gps"` or `accuracy <= 50` on your side.
  - If the user granted only **approximate/coarse** permission (or iOS "Precise: Off"),
    every fix is approximate by OS policy — surfaced via `accuracyAuthorization` /
    `reducedAccuracy`.
- **Dead reckoning:** if `enableDeadReckoning: true`, after GPS is lost for the
  configured delay Tracelet estimates positions from motion sensors until a real fix
  returns. These are clearly the only "locations" recorded while the GPS is off.
- The persistent foreground-service notification remains visible (tracking is still
  armed) even though no fixes are flowing.

**iOS**
- A failed `requestLocation()` (location off / denied) resolves one-shot requests with
  the last known location rather than hanging until timeout.
- iOS will not deliver background or relaunch events while location is off; delivery and
  killed-state relaunch resume after the user turns it back on.

### What you should do in your app

1. Subscribe to `onProviderChange` and surface a banner/dialog when `enabled == false`.
2. Optionally guide the user to settings via `Tracelet.openLocationSettings()`.
3. Do **not** call `start()` again on re-enable — Tracelet resumes on its own; calling
   `start()` is harmless but unnecessary.

### What about revoking the app's *permission* vs turning the toggle off?

Turning the **toggle** off affects all apps and is fully recoverable as described above.
Revoking the **app's location permission** (or downgrading "Always" → "While in use") is
reported via the same `providerchange` event through the `status` /
`accuracyAuthorization` fields. On Android 12+, if background-location permission is
lost, a boot/background restart is intentionally skipped (it would otherwise fail
silently) — re-grant the permission and re-initialize to resume.
