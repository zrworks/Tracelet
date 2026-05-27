# Adaptive Sampling

Tracelet's adaptive sampling engine automatically adjusts the `distanceFilter`
based on three real-time factors — **detected activity**, **battery state**,
and **device speed**. This replaces the simple speed-only elasticity with a
holistic approach that maximizes track resolution when it matters and conserves
battery when it doesn't.

---

## Quick Start

```dart
await Tracelet.ready(Config.balanced().copyWith(
  geo: GeoConfig(
    distanceFilter: 10.0,          // Base distance filter
    enableAdaptiveMode: true,      // Enable adaptive sampling
    elasticityMultiplier: 1.0,     // Used as fallback when activity is unknown
  ),
));
```

That's it. Tracelet will now automatically scale the distance filter based on
context. No additional permissions are needed beyond what you already have.

---

## How It Works

Each time a location is evaluated, the engine computes an **effective distance
filter** using three factors in priority order:

```
effectiveDistanceFilter = baseDistanceFilter × factor × batteryScaling
```

### 1. Activity-Based Profiles (Primary)

When activity recognition reports a known activity with medium or high
confidence, the engine uses an activity-specific distance target:

| Activity      | Distance Filter | Rationale                                |
|---------------|-----------------|------------------------------------------|
| `still`       | 500 m           | Minimal sampling — device isn't moving   |
| `walking`     | 50 m            | Pedestrian-grade accuracy                |
| `onFoot`      | 50 m            | Same as walking                          |
| `running`     | 30 m            | Higher cadence than walking              |
| `onBicycle`   | 25 m            | Cyclist speeds need denser sampling      |
| `inVehicle`   | 10 m            | Vehicle tracking needs high density      |

The distance is expressed as a factor relative to your configured
`distanceFilter`, so battery scaling still applies on top.

### 2. Speed-Based Fallback

When activity type is `unknown` or confidence is `low`, the engine falls back
to speed-based elasticity:

```
speedFactor = clamp(speed ÷ 10, 1.0, 10.0) × elasticityMultiplier
effectiveFilter = distanceFilter × speedFactor × batteryScaling
```

This is the same formula used by Tracelet's standard elasticity, ensuring
smooth behavior when activity recognition is unavailable.

### 3. Battery Scaling (Always Applied)

Battery scaling is applied multiplicatively to both activity-based and
speed-based results:

| Battery Level | Factor | Effect on Distance             |
|---------------|--------|--------------------------------|
| > 50%         | 1.0×   | No change                      |
| 20–50%        | 1.5×   | 50% wider filter               |
| 10–20%        | 2.5×   | 150% wider filter              |
| < 10%         | 5.0×   | 400% wider filter              |
| Charging      | 1.0×   | No scaling (plugged in)        |
| Unknown       | 1.0×   | No scaling (can't determine)   |

This means a walking user at 30% battery gets a 75 m filter (50 m × 1.5),
while a walking user at 8% battery gets a 250 m filter (50 m × 5.0).

---

## Examples

### Fleet Tracking (Enterprise)

```dart
GeoConfig(
  distanceFilter: 10.0,
  enableAdaptiveMode: true,
  elasticityMultiplier: 1.0,
)
```

- **Driving**: 10 m filter — high-density route tracking
- **Parked (still)**: 500 m filter — almost no GPS polling
- **Low battery (8%)**: Filter × 5 — prevents fleet device from dying

### Fitness App

```dart
GeoConfig(
  distanceFilter: 5.0,
  enableAdaptiveMode: true,
  elasticityMultiplier: 0.5,
)
```

- **Running**: 15 m filter (30 m profile × 5 m base ÷ 10 m)
- **Walking**: 25 m filter
- **Still (rest break)**: 250 m filter — saves battery during rest

### Battery-Conscious Delivery App

```dart
GeoConfig(
  distanceFilter: 20.0,
  enableAdaptiveMode: true,
  elasticityMultiplier: 2.0,
)
```

- **Driving**: 20 m filter — maintains resolution on routes
- **Walking delivery**: 100 m filter — good enough for delivery zones
- **Idle at hub (still)**: 1000 m filter — nearly zero battery drain

---

## Interaction with Other Features

| Feature               | Interaction                                                 |
|-----------------------|-------------------------------------------------------------|
| **Elasticity**        | Adaptive mode replaces standard elasticity when enabled. If `disableElasticity: true` AND `enableAdaptiveMode: false`, the distance filter is fixed. |
| **Kalman Filter**     | Works independently. Kalman smooths coordinates; adaptive controls how often they're recorded. |
| **Location Filter**   | Applied after adaptive sampling. A location that passes the adaptive distance filter can still be rejected by accuracy/speed thresholds. |
| **Geofence-only mode**| Adaptive sampling applies to location updates, not geofence monitoring. |
| **Trip detection**    | Trips benefit from adaptive sampling — denser points during movement, sparse during stops. |

---

## Debugging

The `AdaptiveSamplingResult` includes a full factor breakdown that Tracelet
logs at `verbose` level:

```
AdaptiveSamplingResult(effective=75.0m, base=10.0m,
  activity=5.0, battery=1.5, speed=1.0, source=activity)
```

Fields:
- `effective` — The computed distance filter in meters
- `base` — Your configured `distanceFilter`
- `activity` — Multiplier from activity profile (1.0 if not used)
- `battery` — Multiplier from battery state (1.0 if charging or >50%)
- `speed` — Multiplier from speed elasticity (1.0 if activity was used)
- `source` — Which factor drove the calculation: `activity`, `speed`, or `static`

---

## When NOT to Use Adaptive Sampling

- **Fixed-interval recording** — If your use case requires locations at
  exact intervals regardless of context, keep `enableAdaptiveMode: false`.
- **Very low distance filters** — With `distanceFilter: 1.0`, the still
  profile (500 m) might be too aggressive. Consider a higher base.
- **No activity recognition** — If `disableMotionActivityUpdates: true`,
  the engine always falls back to speed-based elasticity, which is
  essentially the same as standard elasticity.

---

## Configuration Reference

| Property | Type | Default | Description |
|---|---|---|---|
| `enableAdaptiveMode` | `bool` | `false` | Enable multi-factor adaptive sampling |
| `distanceFilter` | `double` | `10.0` | Base distance filter (scaled by engine) |
| `elasticityMultiplier` | `double` | `1.0` | Speed fallback multiplier |
| `disableElasticity` | `bool` | `false` | Only applies when adaptive mode is off |
