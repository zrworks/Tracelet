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

## Does Tracelet resume tracking after a device reboot — and does the device need to be unlocked first?

**Short answer:** Yes, Tracelet resumes automatically after a reboot — **but only after the
user unlocks the device at least once.** Until that first unlock, Tracelet does not run.
This is an Android platform rule (Direct Boot / File-Based Encryption), not a Tracelet
limitation, and it applies to every location SDK. iOS cannot auto-start on reboot at all.

### Why the first unlock is required (Android)

Modern Android uses **File-Based Encryption (FBE)** with two storage areas:

- **Credential-Encrypted (CE)** storage — unlocked only **after** the user enters their
  PIN / pattern / password / biometric the first time after boot.
- **Device-Encrypted (DE)** storage — available earlier, in *Direct Boot* mode, but only
  to components explicitly marked `directBootAware`.

Tracelet's `BootReceiver` listens for `BOOT_COMPLETED`, which Android **dispatches only
after that first unlock** (the earlier `LOCKED_BOOT_COMPLETED` goes to `directBootAware`
components only, which Tracelet is not). On top of that, everything Tracelet needs —
config (`com.tracelet.config`), state (`com.tracelet.state`), and the location database —
lives in **CE** storage, so it is physically inaccessible before unlock anyway.

Sequence after a reboot:

1. Device boots → **Tracelet is idle** (no `BOOT_COMPLETED`, CE storage locked).
2. User unlocks once → `BOOT_COMPLETED` fires → `BootReceiver` resumes tracking and sync.

> Only the **first** unlock matters. Afterwards the screen can be locked again (phone in
> pocket, screen off) and tracking/sync continue normally.

### Requirements for boot resume

- `startOnBoot: true` and `stopOnTerminate: false` in config.
- Background-location ("Always") permission granted — on Android 12+, a boot restart is
  intentionally skipped if it's missing.
- The user must have explicitly been tracking when the device shut down (a prior
  `stop()` is **not** resurrected by a reboot).

### Behavior by platform

| | Android | iOS |
|---|---|---|
| **Auto-start on reboot** | Yes, via `BootReceiver` on `BOOT_COMPLETED` — **after first unlock**. | **No.** Apps cannot run on boot. The app stays unlaunched until the user opens it or a significant-location-change relaunches it (which only occurs after a post-reboot unlock). |
| **Android 14+ note** | The OS forbids starting a *location* foreground service from `BOOT_COMPLETED`; Tracelet falls back to WorkManager/alarm tracking (**no persistent notification**) until the app is next opened. | n/a |

### Can Tracelet track *before* the first unlock?

Not out of the box. Pre-unlock tracking requires Android **Direct Boot**: marking the
boot receiver, foreground service, and startup provider `directBootAware`, adding a
`LOCKED_BOOT_COMPLETED` filter, and moving the data Tracelet needs into **DE** storage.
DE storage is readable before the user authenticates, a **weaker at-rest guarantee** than
the CE (and optionally `encryptDatabase`-protected) storage Tracelet uses normally — so
enabling it would relax the encryption posture for any data captured before unlock.

Because of that trade-off, Tracelet keeps Direct Boot **off by default** so existing
apps preserve full credential-encrypted protection. It can be offered as an advanced,
**app-level (build-time + runtime) opt-in** that buffers pre-unlock fixes in DE storage
and migrates them into the encrypted CE database on first unlock. If pre-unlock tracking
is a hard requirement, raise it before depending on it.

## Does Tracelet keep tracking after the app is closed or swiped away from recents?

**Short answer:** On **Android**, yes — with `stopOnTerminate: false`, tracking continues
natively after the app is swiped away. On **iOS** it depends on *how* the app ended:
system-initiated termination relaunches and resumes; a user force-quit (swipe up) stops
location services until the app is manually reopened.

### Android

When the task is removed from recents, `LocationService.onTaskRemoved` fires. With
`stopOnTerminate: false`, Tracelet bootstraps a **native** `LocationEngine` (plus motion
detection and the headless sync bridge) that runs without a Flutter engine, so capture
and HTTP sync keep going. The foreground-service notification is what keeps the process
alive; if the OS still kills it under memory pressure, the `START_STICKY` service is
restarted. With `stopOnTerminate: true`, the service tears down on swipe-away.

### iOS

iOS has no equivalent of a long-lived background service, so Tracelet relies on
significant-location-change / region monitoring:

- **System termination** (memory, OS housekeeping): iOS relaunches the app in the
  background on the next qualifying location event and `autoResumeTracking` restores the
  session.
- **User force-quit** (swipe up in the app switcher): Apple intentionally suspends all of
  the app's location services until the user opens the app again. No SDK can override this.

## What happens to my locations if the device is offline (no internet)?

**Short answer:** Nothing is lost (within your retention limits). Locations are persisted
locally the instant they're captured and uploaded when connectivity returns, with retry
and backoff. A batch is removed from the database only after a successful upload.

### How it works

1. Each fix is written to the on-device SQLite database (encrypted at rest when
   `encryptDatabase: true`) immediately, independent of network state.
2. Auto-sync attempts an upload (debounced by `autoSyncDelay`). On failure it retries with
   exponential backoff governed by `maxRetries`, `retryBackoffBase`, and `retryBackoffCap`.
3. Records are deleted from the database **only after the server confirms receipt**
   (`clearLocationsUpTo` runs on a 2xx), so an interrupted or offline upload is retried
   later — never dropped.

### Retention & controls

- `maxDaysToPersist` / `maxRecordsToPersist` bound how much history is buffered; the
  oldest records are pruned once exceeded.
- `disableAutoSyncOnCellular: true` holds uploads until Wi-Fi.
- Sync also runs headlessly in the background and after a reboot (see the reboot question
  above), so a buffered backlog uploads without the user opening the app.

## Why don't I get continuous location updates when the device is stationary?

**Short answer:** By design — it is the single biggest battery saving Tracelet provides.
Continuous GPS is paused when the device is still and resumes automatically on movement.

When motion detection (`motionDetectionMode`) determines the device is stationary, Tracelet
stops the continuous GPS stream and switches to a low-power strategy (periodic one-shot
fixes or geofence monitoring). Continuous tracking wakes the instant real motion is
detected. To still receive a periodic location while parked, set `heartbeatInterval`
(seconds). Small GPS drift while stationary does not inflate distance — fixes worse than
`odometerAccuracyThreshold` (default 50 m) are excluded from the odometer.

## How do I reduce battery usage even further?

Tracelet already sleeps the GPS when stationary, but several levers tighten it further:

- **Battery budget** — `batteryBudgetPerHour` (e.g. `3.0` for 3%/hr) lets Tracelet
  auto-adjust `distanceFilter` and `desiredAccuracy` at runtime to hold that target.
- **Distance filter** — a larger `distanceFilter` (metres) records fewer fixes while moving.
- **Lower accuracy** — `desiredAccuracy` of `medium`/`low` draws less power than `high`/`best`.
- **Periodic mode** — for coarse "where are they roughly" use cases, periodic one-shot
  fixes (`startPeriodic`) are dramatically cheaper than continuous tracking.
- **Keep motion permission granted** — without `ACTIVITY_RECOGNITION` (Android) /
  Motion & Fitness (iOS), Tracelet cannot sleep the GPS as aggressively.

## What's the difference between the `motionDetectionMode` options?

`motionDetectionMode` decides how Tracelet detects movement to start and stop the GPS:

- **`accelerometer`** — hardware motion sensors (plus Activity Recognition where
  permitted). Lowest power, works indoors and without a GPS fix.
- **`speed`** — GPS speed only. Simple and predictable, but it needs a GPS fix to notice
  you've stopped, so it reacts slower and costs more power.
- **`smart`** — combines both: stays continuous if *either* the accelerometer *or* GPS
  speed indicates motion, and goes stationary only when *both* agree you've stopped. Most
  robust against false stationary/moving transitions; recommended for most apps.

## How accurate are the locations, and how do I tell GPS from Wi-Fi/cell fixes?

Every `Location` carries a real `coords.accuracy` in metres and a `locationSource` tag:
`"gps"` (≤50 m), `"wifi"` (≤200 m), `"cell"` (worse), or `"network"` (during GPS
fallback). Tracelet does **not** silently drop low-accuracy fixes — it records them so the
trail stays continuous — but it keeps poor fixes out of the **odometer**
(`odometerAccuracyThreshold`, default 50 m) and rejects impossible-speed jumps
(`maxImpliedSpeed`). To use GPS-quality data only, filter by `locationSource == "gps"` or
`accuracy <= 50`. If only **approximate/coarse** location was granted (or iOS "Precise:
Off"), every fix is approximate by OS policy — check `accuracyAuthorization` /
`reducedAccuracy`.

## Is my location data encrypted at rest?

Optionally, yes. Set `encryptDatabase: true` to encrypt the local SQLite database that
buffers locations. On Android this uses **SQLCipher** (AES-256) and requires you to add
the SQLCipher dependency to your app — it is kept optional so the default build stays
small, and calling `encryptDatabase` without it throws a clear error. On iOS the encrypted
store is handled natively.

For tamper-evidence rather than confidentiality, the **audit trail** (`audit.enabled`)
hash-chains each record (e.g. SHA-256), so you can prove the history was not altered after
the fact. **Privacy zones** suppress or redact fixes inside sensitive areas (such as a
user's home).

## Does Tracelet detect mock / fake GPS locations?

Yes, via `mockDetectionLevel` on `LocationFilter`:

- **`disabled`** (0, default) — all locations accepted unconditionally.
- **`basic`** (1) — trusts the platform's "is mock" flag.
- **`heuristic`** (2) — the platform flag *plus* native heuristics and a Dart-side
  timestamp check, to catch spoofers that hide the flag.

At `heuristic`, each `Location` is annotated with why it was judged real or fake, so you
can accept, flag, or reject mock fixes in your own logic.

## I'm coming from flutter_background_geolocation — how hard is the switch?

Tracelet's API is intentionally close to `flutter_background_geolocation`, so most apps
map over with minimal changes — `ready`/`start`/`stop`, the location/motion/provider
events, and HTTP sync all have direct equivalents. See
[MIGRATION-FROM-FBG.md](./MIGRATION-FROM-FBG.md) for the full config/event mapping table
and the handful of behavioural differences to watch for.
