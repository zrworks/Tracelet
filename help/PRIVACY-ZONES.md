# Privacy Zones — Enterprise Feature

Privacy Zones define geographic areas where location tracking behaviour
changes automatically. When the device enters a registered privacy zone the
plugin applies the configured action — **exclude**, **degrade**, or
**event-only** — transparently, on both Android and iOS, even in the
background.

> **Enterprise feature** — Privacy Zones are designed for organisations that
> must comply with GDPR "right to be forgotten", employee-privacy regulations
> (e.g. no home-location tracking), or data-minimisation policies.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Configuration](#configuration)
3. [Privacy Zone Actions](#privacy-zone-actions)
4. [API Reference](#api-reference)
5. [How It Works](#how-it-works)
6. [Best Practices](#best-practices)
7. [Platform Notes](#platform-notes)

---

## Quick Start

```dart
import 'package:tracelet/tracelet.dart';

// 1. Enable privacy zones in your Config
await Tracelet.ready(Config.balanced().copyWith(
  privacyZone: PrivacyZoneConfig(enabled: true),
  // ... other config
));

// 2. Register a privacy zone
await Tracelet.addPrivacyZone(PrivacyZone(
  identifier: 'home',
  latitude: 37.7749,
  longitude: -122.4194,
  radius: 200, // metres
  action: PrivacyZoneAction.exclude,
));

// 3. Start tracking — locations inside the zone are automatically handled
await Tracelet.start();
```

---

## Configuration

Privacy zones are controlled by a master toggle in the `Config` object.
Individual zones are registered at runtime via the Tracelet API.

```dart
Config(
  privacyZone: PrivacyZoneConfig(
    enabled: true, // Master toggle (default: false)
  ),
)
```

| Property  | Type   | Default | Description |
|-----------|--------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. When `false`, all zones are ignored. |

When `enabled` is `false` (the default), registered zones remain stored in
the database but are not evaluated. This lets you toggle the feature on/off
without losing zone definitions.

---

## Privacy Zone Actions

Each zone has an `action` that determines what happens when a location falls
inside it:

| Action | Enum Value | Behaviour |
|--------|------------|-----------|
| **Exclude** | `PrivacyZoneAction.exclude` | Location is dropped entirely — not persisted, not dispatched, not audited. |
| **Degrade** | `PrivacyZoneAction.degrade` | Coordinates are snapped to a coarse grid (configurable via `degradedAccuracyMeters`). The degraded location IS persisted and dispatched. |
| **Event-only** | `PrivacyZoneAction.eventOnly` | Location is dispatched to Dart listeners (e.g. `onLocation`) but NOT persisted to the database. |

### Exclude (default)

The most restrictive action. Ideal for employee home addresses or
legally restricted areas. The location never reaches Dart code, is never
stored, and is never part of the audit trail.

### Degrade

Reduces coordinate precision by snapping latitude/longitude to a grid
whose cell size approximates `degradedAccuracyMeters` (default: 1 000 m).
The accuracy field is set to the degraded value, so downstream code knows
the precision has been intentionally reduced.

```dart
PrivacyZone(
  identifier: 'home',
  latitude: 37.7749,
  longitude: -122.4194,
  radius: 200,
  action: PrivacyZoneAction.degrade,
  degradedAccuracyMeters: 2000.0, // ~ 2 km grid
)
```

### Event-only

Dispatches the full-precision location to Dart listeners for real-time
display or geofence logic, but does NOT persist it to the database. Use
this when you need in-app awareness but must not store the precise
location for compliance reasons.

---

## API Reference

All methods are static on the `Tracelet` class. Privacy zone data is
persisted in the native database, so zones survive app restarts.

### `addPrivacyZone(PrivacyZone zone)`

Adds a single privacy zone. If a zone with the same `identifier` already
exists it is replaced (upsert).

```dart
await Tracelet.addPrivacyZone(PrivacyZone(
  identifier: 'office',
  latitude: 40.7128,
  longitude: -74.0060,
  radius: 500,
  action: PrivacyZoneAction.degrade,
  degradedAccuracyMeters: 1000.0,
));
```

### `addPrivacyZones(List<PrivacyZone> zones)`

Adds multiple zones in one call.

```dart
await Tracelet.addPrivacyZones([
  PrivacyZone(identifier: 'home', ...),
  PrivacyZone(identifier: 'office', ...),
]);
```

### `removePrivacyZone(String identifier)`

Removes a single zone by identifier.

```dart
await Tracelet.removePrivacyZone('home');
```

### `removePrivacyZones()`

Removes all privacy zones.

```dart
await Tracelet.removePrivacyZones();
```

### `getPrivacyZones()`

Returns all registered privacy zones.

```dart
final zones = await Tracelet.getPrivacyZones();
for (final zone in zones) {
  print('${zone.identifier}: ${zone.action.name} (r=${zone.radius}m)');
}
```

---

## How It Works

### Evaluation Flow

Privacy zone evaluation is injected into the native location dispatch
pipeline **after** location enrichment (UUID, battery, activity) but
**before** audit trail, database persistence, and Dart dispatch:

```
CLLocation / FusedLocation
  │
  ▼
enrichLocation()         ← UUID, battery, sensors, odometer
  │
  ▼
╔═══════════════════════╗
║  Privacy Zone Check   ║  ← Haversine distance check
║  (if enabled)         ║
╚═══════════════════════╝
  │         │         │
  │ exclude │ degrade │ event-only
  │         │         │
  ▼         ▼         ▼
 DROP    DEGRADE    DISPATCH
          │           │
          ▼           ╰──────╮
   Audit Trail               │
      │                       │
      ▼                       │
   Persist                    │
      │                       │
      ▼                       ▼
   Dispatch to Dart      (no persist)
```

### Distance Calculation

Uses the **Haversine formula** for great-circle distance — accurate to
within ±0.3% on Earth. This is a single trigonometric computation per
zone per location, which has negligible battery impact.

### Overlapping Zones

When a location falls inside multiple privacy zones, the **most
restrictive** action wins:

```
exclude (most restrictive) > event-only > degrade (least restrictive)
```

### Degrade Algorithm

Coordinates are snapped to a grid where each cell is approximately
`degradedAccuracyMeters` wide:

```
gridDeg = accuracyMeters / 111_320  (1° ≈ 111.32 km)
snappedLat = round(lat / gridDeg) * gridDeg
snappedLng = round(lng / gridDeg) * gridDeg
```

The `accuracy` field on the location is updated to match the degradation
level, so consuming code can detect degraded locations.

---

## Best Practices

1. **Use meaningful identifiers** — Zone identifiers persist across
   restarts. Use stable, descriptive names (`home`, `office-nyc`).

2. **Combine with Audit Trail** — When using `exclude` zones, the audit
   trail will not contain entries for dropped locations. If you need to
   prove that locations were intentionally excluded, keep an external log
   of when zones were added/removed.

3. **Prefer `degrade` over `exclude`** when you still need rough location
   data (e.g. "employee is in the residential area") but must not store
   exact coordinates.

4. **Test zone boundaries** — Use `getPrivacyZones()` to verify zones are
   registered. Test with known GPS coordinates to confirm the radius
   covers the intended area.

5. **Toggle vs. delete** — Use `PrivacyZoneConfig(enabled: false)` to
   temporarily disable all zones without deleting them. Zones remain in
   the database and can be re-activated by setting `enabled: true`.

---

## Platform Notes

### Android
- Privacy zones are stored in the `privacy_zones` SQLite table.
- Evaluation happens on the same thread as location dispatch
  (single-thread write executor).
- The `PrivacyZoneManager` is initialized in `onAttachedToEngine` and
  wired into `LocationEngine`.

### iOS
- Privacy zones are stored in the `privacy_zones` SQLite table.
- Evaluation runs on the `LocationEngine`'s dispatch path, protected
  by the background task helper (`BackgroundTaskHelper.shared`).
- The `PrivacyZoneManager` is initialized during plugin registration.

### Web
- Privacy zones are **not supported** on web. The API methods return
  `false` / empty list but do not throw. This matches the web platform's
  lack of persistent background tracking.

---

## Related

- [Configuration](CONFIGURATION.md)
- [Background Tracking](BACKGROUND-TRACKING.md)
- [Audit Trail](AUDIT-TRAIL.md) — Tamper-proof location hash chain
- [API Reference](API.md)
