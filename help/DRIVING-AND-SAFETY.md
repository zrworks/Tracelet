# Driving & Safety (Telematics, Transport Mode, Crash/Fall)

> Added in **3.3.0**. All three features are **opt-in and default-off** — they
> never run, allocate, or affect tracking unless you explicitly enable them.

Tracelet 3.3.0 adds three on-device behavior engines that turn the location +
accelerometer stream into higher-level signals:

| Feature | Config | Events |
|---|---|---|
| Driving-behavior (telematics) | `TelematicsConfig` | `Tracelet.onDrivingEvent` |
| Transport-mode classifier | `ClassifierConfig` | `Tracelet.onModeChange` |
| Crash / fall detection | `ImpactConfig` | `Tracelet.onImpact` |

All detection runs **on device** in the Rust core (no cloud, deterministic).
Thresholds are expressed in **g** (1 g ≈ 9.81 m/s²) and are fully tunable.

---

## 1. Driving-behavior events (telematics)

GPS-derived detection of `harsh_braking`, `harsh_acceleration`,
`harsh_cornering`, and `speeding` — no extra sensors required.

```dart
await Tracelet.ready(Config(
  telematics: TelematicsConfig(
    enableDrivingEvents: true,
    harshBrakingG: 0.40,        // deceleration threshold (g)
    harshAccelerationG: 0.35,
    harshCorneringG: 0.40,
    speedLimitKmh: 50,          // 0 disables speeding
    speedingToleranceKmh: 5,
    speedingMinDurationMs: 3000,
  ),
));

Tracelet.onDrivingEvent((e) {
  print('${e.kind}  severity=${e.severity}  value=${e.value}');
  // e.kind: harsh_braking | harsh_acceleration | harsh_cornering | speeding
  // e.value: g for harsh events, km/h-over-limit for speeding
});
```

GPS speed is ~1 Hz and noisy, so the engine favors **specificity over
sensitivity** (high thresholds, gap rejection, one-event-per-maneuver debounce).
Each event carries a normalized `severity` (0–1). A rolling driving score is
maintained internally per tracking session.

## 2. Transport-mode classifier

Fuses accelerometer features (variance, cadence) with GPS speed to classify
`still` / `walking` / `running` / `cycling` / `vehicle`, with hysteresis so a
mode must persist before it commits.

```dart
await Tracelet.ready(Config(
  classifier: ClassifierConfig(
    enableFusedClassifier: true,
    fusedClassifierAuthoritative: false, // annotate, don't override platform
    modeSwitchDwellMs: 8000,
    minModeConfidence: 0.6,
  ),
));

Tracelet.onModeChange((e) => print('mode: ${e.mode} (${e.confidence})'));
```

By default the classifier **annotates** — the platform Activity-Recognition
value stays authoritative. Set `fusedClassifierAuthoritative: true` to let the
fused mode drive sampling decisions.

## 3. Crash & fall detection

Safety-critical, so detection is **corroborated** (a high-g spike alone is never
a crash) and uses a **cancel-countdown** confirmation flow.

```dart
await Tracelet.ready(Config(
  impact: ImpactConfig(
    enableCrashDetection: true,
    enableFallDetection: false,  // best-effort; default off
    crashGThreshold: 3.0,        // impact magnitude (g)
    crashMinSpeedKmh: 25,        // must have been moving
    confirmWindowMs: 15000,      // countdown before auto-confirm
  ),
));

Tracelet.onImpact((e) {
  if (e.isPotential) {
    // Show a countdown UI; if the user is fine, cancel it:
    // await Tracelet.cancelImpact(e.id);
    // To escalate immediately:
    // await Tracelet.confirmImpact(e.id);
  } else {
    // e.kind == 'crash' (or 'fall') — confirmed emergency
  }
});
```

- A **crash** requires an impact above `crashGThreshold` **while moving** above
  `crashMinSpeedKmh`.
- A `potential_crash`/`potential_fall` fires first with a `confirmDeadline`;
  if not cancelled within `confirmWindowMs`, the confirmed `crash`/`fall` fires.
- Tracelet provides the **trigger + cancel window** — it never places emergency
  calls. That's the host app's responsibility.

---

## Permissions

- **Driving events** need only the location permission you already grant for
  tracking — **no new permission**.
- **Classifier** and **crash/fall** use the accelerometer. On Android the
  accelerometer is already used by motion detection (no extra permission); on
  iOS, Motion & Fitness (`NSMotionUsageDescription`) improves fidelity. See
  [PERMISSIONS.md](PERMISSIONS.md).

## Guarantees

- **Default-off:** with the three config blocks at their defaults, no engine is
  instantiated and behavior is byte-for-byte identical to 3.2.x.
- **Side-channel:** these events never alter the location pipeline, odometer, or
  `onLocation` payload.
- **Cross-platform:** identical engines (shared Rust core) on Android and iOS;
  driving events also work on Web (GPS-derived).
