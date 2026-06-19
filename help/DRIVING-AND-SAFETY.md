# Driving & Safety (Telematics, Transport Mode, Crash/Fall)

> Added in **3.3.0**. Everything here is **opt-in and off by default** — if you
> don't enable a feature, its engine is never created and your tracking behaves
> exactly as before.

Tracelet can turn the raw location + accelerometer stream into **meaningful
events** about *how* a device is moving — on the device, no cloud calls. There
are three independent features:

| Feature | What it tells you | Enable with | Listen with |
|---|---|---|---|
| **Driving events** | hard braking / acceleration / cornering / speeding | `TelematicsConfig` | `Tracelet.onDrivingEvent` |
| **Transport mode** | walking / running / cycling / vehicle / still | `ClassifierConfig` | `Tracelet.onModeChange` |
| **Crash & fall** | a likely crash or fall just happened | `ImpactConfig` | `Tracelet.onImpact` |

**Who uses this?** Usage-based insurance & fleet safety (driving events),
delivery/field apps (transport mode), and lone-worker/rideshare/personal-safety
apps (crash & fall). Enable any combination — they're independent.

---

## 1. Driving events (telematics)

### Quick start

```dart
// Turn it on (50 km/h limit enables speeding detection)
await Tracelet.ready(Config(
  telematics: TelematicsConfig(
    enableDrivingEvents: true,
    speedLimitKmh: 50,
  ),
));

// Listen
Tracelet.onDrivingEvent((e) {
  print('${e.kind} — severity ${e.severity}, value ${e.value}');
});

await Tracelet.start();
```

You'll get events like `harsh_braking` / `harsh_acceleration` /
`harsh_cornering` / `speeding`.

### Event fields

| Field | Meaning |
|---|---|
| `kind` | which event |
| `severity` | `0.0`–`1.0`, how far past the threshold (good for scoring) |
| `value` | **g-force** for harsh events, **km/h over the limit** for speeding |
| `speed` | speed at the moment (m/s) |
| `latitude` / `longitude` / `timestamp` | where & when |

### Options (all thresholds in g; 1 g ≈ 9.81 m/s²)

| Option | Default | Meaning |
|---|---|---|
| `harshBrakingG` | `0.40` | brake threshold |
| `harshAccelerationG` | `0.35` | acceleration threshold |
| `harshCorneringG` | `0.40` | cornering threshold |
| `speedLimitKmh` | `0` (off) | speed limit; `0` disables speeding |
| `speedingToleranceKmh` | `5` | grace over the limit |
| `speedingMinDurationMs` | `3000` | sustained-over-limit time before it counts |
| `minSpeedForEventsKmh` | `5` | ignore events below this speed |

> **Why no events sometimes?** These are derived from ~1 Hz, noisy GPS speed, so
> Tracelet favours accuracy over sensitivity (it won't cry wolf). Best used while
> actually driving.

---

## 2. Transport mode

```dart
await Tracelet.ready(Config(
  classifier: ClassifierConfig(enableFusedClassifier: true),
));
Tracelet.onModeChange((e) => print('Now: ${e.mode} (${e.confidence})'));
```

Reports `still` / `walking` / `running` / `cycling` / `vehicle`.

| Option | Default | Meaning |
|---|---|---|
| `enableFusedClassifier` | `false` | master switch |
| `fusedClassifierAuthoritative` | `false` | `false` = annotate only (recommended); `true` = let the fused mode drive sampling |
| `modeSwitchDwellMs` | `8000` | how long a mode must persist before it's reported |
| `minModeConfidence` | `0.6` | below this → reported as `unknown` |

By default it's a **second opinion** — it reports a mode but the OS activity stays
in charge. Most apps want this.

---

## 3. Crash & fall detection

```dart
await Tracelet.ready(Config(
  impact: ImpactConfig(
    enableCrashDetection: true,
    confirmWindowMs: 15000,  // 15s for the user to cancel
  ),
));

Tracelet.onImpact((e) async {
  if (e.isPotential) {
    // Show an "Are you OK?" countdown.
    await Tracelet.cancelImpact(e.id);   // user is fine
    // await Tracelet.confirmImpact(e.id); // escalate now
  } else {
    // e.kind == 'crash'/'fall' — confirmed; start your SOS flow.
  }
});
```

**The flow:** hard impact while moving → `potential_crash` (with a deadline) →
user cancels/confirms, or it auto-confirms to `crash` after `confirmWindowMs`.

| Option | Default | Meaning |
|---|---|---|
| `enableCrashDetection` | `false` | vehicle crash |
| `enableFallDetection` | `false` | personal fall (best-effort; more false alarms) |
| `crashGThreshold` | `2.0` | impact strength (g) for a crash (lowered from 3.0 — field data showed 3.0 g missed ~half of real crashes; the cancel-countdown offsets the extra alarms) |
| `crashMinSpeedKmh` | `25` | must have been moving this fast (corroboration) |
| `confirmWindowMs` | `15000` | cancel-countdown length |
| `minImpactConfidence` | `0.6` | suppress low-confidence candidates |

> ⚠️ Tracelet provides the **trigger + cancel window** only — it never places
> emergency calls. Building the SOS flow is your app's job.

### Confirmation survives the app being killed

A violent impact often ends with the OS killing the app (the phone is flung,
the vehicle comes to rest, Doze kicks in). Tracelet makes the confirmation
**process-death safe**: the moment a `potential_crash` / `potential_fall` is
raised it is persisted to disk and a wake-up is armed for just after the
deadline. If the in-process countdown is still alive it confirms normally and
disarms the wake-up; if the app was killed, the wake-up re-emits the confirmed
`crash` / `fall` from a fresh process so your SOS flow still runs.

- **Android** — an exact `AlarmManager` alarm (`setExactAndAllowWhileIdle`, fires
  in Doze) wakes a receiver that re-delivers the confirmed event.
- **iOS** — a local notification scheduled at the deadline alerts the user even
  while the app is dead, and the confirmed event is re-delivered the next time
  the SDK runs (background relaunch or foreground). Grant notification
  permission for the user-facing alert; the re-delivery works regardless.

A user **cancel** removes the persisted candidate and disarms the wake-up, so a
cancelled candidate is never re-confirmed after a restart.

### Corroboration signals

To raise recall without flooding you with false alarms, the confidence of a
candidate is corroborated by additional physical evidence:

- **Free-fall before impact** (`#180`) — a falling phone reads near-0 g just
  before the jolt; the classic drop signature.
- **Post-impact stillness** (`#180`) — after a real fall the body comes to rest;
  the acceleration trace settles back near 1 g with little movement.
- **Δv speed collapse** (`#181`) — a real crash collapses the vehicle's speed
  within ~1–2 s. Tracelet samples the post-impact GPS speed and **raises**
  confidence on a sharp collapse (it never suppresses a candidate — the design
  favours recall).
- **Cabin-pressure spike** (`#173`) — a severe collision or airbag deployment
  produces a brief cabin air-pressure transient. On devices with a barometer
  (Android `TYPE_PRESSURE`, iOS `CMAltimeter`), a sharp pressure swing
  concurrent with the impact **raises** confidence. Most phones with no
  barometer simply skip this cue, so its absence never changes detection.

### Optional: ML crash model

Crash detection runs on a **rule engine** by default (no setup). To gate crashes
on a trained probability, plug in a licensed **ML model** — opt-in, **downloaded
(never embedded)**, and shipped **AES-256-GCM encrypted**:

```dart
impact: ImpactConfig(
  enableCrashDetection: true,
  crashModelUrl: 'https://your-cdn/tracelet_optimized.crashmodel', // encrypted
  crashModelSha256: 'b27a764f…',  // integrity check
  crashModelThreshold: 0.5074,    // rf_probability_threshold from training
),
```

| Option | Default | Meaning |
|---|---|---|
| `crashModelUrl` | `null` | URL of the encrypted blob; `null` ⇒ pure rule engine |
| `crashModelSha256` | `null` | hex SHA-256 of the blob, verified after download |
| `crashModelThreshold` | `0.5` | probability at which the model flags a crash |

The SDK downloads + SHA-verifies the blob (caching it on-device so it is fetched
once, and re-downloading automatically when you publish a new version with a
fresh digest), decrypts it **in memory** with a runtime-injected key, and runs
it; any failure ⇒ **rule-engine fallback**. The key is **never shipped in the
app** — fetch it from a licensing endpoint you control.

**Android (optional, prod licenses only):** for anti-piracy you bind the model to
your signed, published app via **Play Integrity**. Add it **only if you use a
`prod` license** — `dev` licenses unlock in debug builds/emulators without it:

```kotlin
// app/build.gradle.kts
dependencies {
    implementation("com.google.android.play:integrity:1.4.0")
}
```

> The trained model is **stable**. It is trained on the **CC0 / public-domain**
> Smartphone IMU Road Accident Detection dataset, so it is cleared for
> commercial use, and the load → SHA-verify → decrypt → gate pipeline (with
> rule-engine fallback) is production-ready ([#183](https://github.com/Ikolvi/Tracelet/issues/183)).

---

## Trying it without driving (simulation)

The example app's **Driving & Safety** page has *Simulate* buttons (Hard brake,
Rapid accel, Sharp turn, Crash, Vehicle mode) that feed synthetic data into the
**real** engines and show the events. In tests, the engines are callable
directly from Dart (flutter_rust_bridge) — see
`example/integration_test/behavior_simulation_test.dart`.

## Permissions

- **Driving events**: only your existing location permission — nothing extra.
- **Transport mode / crash / fall**: the accelerometer (already used on Android;
  add the Motion & Fitness usage description on iOS for best accuracy). See
  [PERMISSIONS.md](PERMISSIONS.md).

## Guarantees

- **Default-off** — config blocks at defaults ⇒ engines never created ⇒ behaviour
  identical to 3.2.x.
- **Side-channel** — never alters your locations, odometer, or sync.
- **On-device & cross-platform** — shared Rust core; identical on Android & iOS
  (driving events also work on Web).
