# Tracelet Performance Benchmarks

Automated performance tracking for Tracelet's core Dart algorithms.
Benchmarks run on every commit via CI and results are appended below.

## How to Run Locally

```bash
cd benchmark && flutter pub get && flutter test test/tracelet_benchmark_test.dart --reporter expanded
```

## Benchmark Descriptions

| Benchmark | Description | Hot Path |
|---|---|---|
| `kalman_process_single` | Single Kalman filter predict+update cycle | Every GPS fix |
| `kalman_process_100_fixes` | 100 sequential GPS fixes through Kalman filter | Sustained tracking |
| `kalman_process_1k_fixes` | 1000 sequential GPS fixes through Kalman filter | Long session |
| `kalman_reset` | Reset filter state (Float64List fillRange) | Mode change |
| `haversine_single` | Single haversine distance calculation | Every GPS fix (3+ calls) |
| `haversine_1k_pairs` | 1000 sequential haversine calculations | Batch processing |
| `pip_4v` | Point-in-polygon, 4-vertex polygon | Simple geofence |
| `pip_10v` | Point-in-polygon, 10-vertex polygon | Medium polygon |
| `pip_50v` | Point-in-polygon, 50-vertex polygon | Complex polygon |
| `pip_100v` | Point-in-polygon, 100-vertex polygon | Detailed boundary |
| `pip_500v` | Point-in-polygon, 500-vertex polygon | High-detail polygon |
| `geofence_eval_10_circular` | Evaluate 10 circular geofences | Small deployment |
| `geofence_eval_100_circular` | Evaluate 100 circular geofences | Medium deployment |
| `geofence_eval_500_circular` | Evaluate 500 circular geofences | Large deployment |
| `geofence_eval_10_polygon_6v` | Evaluate 10 polygon geofences (6 vertices each) | Polygon zones |
| `geofence_eval_50_polygon_6v` | Evaluate 50 polygon geofences (6 vertices each) | Many polygon zones |
| `processor_1k_fixes` | Full LocationProcessor pipeline, 1000 fixes | Core tracking loop |
| `processor_1k_adaptive` | LocationProcessor with adaptive mode, 1000 fixes | Battery-aware tracking |
| `trip_manager_5k_waypoints` | TripManager accumulating 5000 waypoints | Long trip |
| `schedule_parse` | Parse a schedule string | Schedule evaluation |
| `schedule_matches` | Check if time matches a schedule | Schedule evaluation |
| `schedule_isWithin_5_entries` | Check 5 schedule entries | Multi-schedule |
| `adaptive_compute` | AdaptiveSamplingEngine single computation | Every GPS fix (adaptive) |
| `location_fromMap` | Deserialize Location from platform map | Every GPS fix |
| `location_toMap` | Serialize Location to map | Persistence/HTTP |
| `location_fromMap_toMap_roundtrip` | Full serialization round-trip | Legacy path |
| `location_copyWithCoords` | Copy Location with new coords (optimized) | Kalman output |
| `geofence_fromMap_circular` | Deserialize circular geofence | Geofence loading |
| `geofence_fromMap_polygon` | Deserialize polygon geofence with vertices | Polygon loading |

## Performance Thresholds

Critical operations that run on **every GPS fix** (1 Hz) must complete in < 1ms total:

| Operation | Budget | Typical |
|---|---|---|
| Kalman filter process | < 1 µs | ~0.1 µs |
| Haversine distance | < 1 µs | ~0.09 µs |
| Point-in-polygon (4v) | < 1 µs | ~0.06 µs |
| Location.fromMap() | < 5 µs | ~0.5 µs |
| Location.copyWithCoords() | < 1 µs | ~0.06 µs |
| Full processor pipeline (per fix) | < 100 µs | ~83 µs/1k ≈ 0.08 µs/fix |

---

## Results History

### 2025-06-02 — Baseline (v0.12.0, post-performance-audit)

**Environment:** Dart 3.11.0, macOS arm64

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 9,101,629 | 0.11 |
| kalman_process_100_fixes | 129,597 | 7.72 |
| kalman_process_1k_fixes | 13,503 | 74.06 |
| kalman_reset | 8,247,498 | 0.12 |
| haversine_single | 11,307,247 | 0.09 |
| haversine_1k_pairs | 31,066 | 32.19 |
| pip_4v | 17,288,752 | 0.06 |
| pip_10v | 13,799,457 | 0.07 |
| pip_50v | 5,670,817 | 0.18 |
| pip_100v | 2,926,690 | 0.34 |
| pip_500v | 720,601 | 1.39 |
| geofence_eval_10_circular | 840,408 | 1.19 |
| geofence_eval_100_circular | 94,396 | 10.59 |
| geofence_eval_500_circular | 18,161 | 55.06 |
| geofence_eval_10_polygon_6v | 529,724 | 1.89 |
| geofence_eval_50_polygon_6v | 105,278 | 9.50 |
| processor_1k_fixes | 11,991 | 83.39 |
| processor_1k_adaptive | 12,019 | 83.20 |
| trip_manager_5k_waypoints | 594 | 1,684.81 |
| schedule_parse | 3,908,346 | 0.26 |
| schedule_matches | 1,174,266 | 0.85 |
| schedule_isWithin_5_entries | 882,997 | 1.13 |
| adaptive_compute | 18,353,277 | 0.05 |
| location_fromMap | 1,905,601 | 0.52 |
| location_toMap | 655,167 | 1.53 |
| location_fromMap_toMap_roundtrip | 519,043 | 1.93 |
| location_copyWithCoords | 17,705,080 | 0.06 |
| geofence_fromMap_circular | 5,458,465 | 0.18 |
| geofence_fromMap_polygon | 1,734,853 | 0.58 |

**Key insights:**
- Kalman filter: **0.11 µs/fix** — 9.1M ops/sec, well within 1 µs budget
- Haversine: **0.09 µs** — 11.3M ops/sec
- Point-in-polygon scales linearly: 0.06 µs (4v) → 1.39 µs (500v)
- `copyWithCoords` is **32× faster** than full `fromMap→toMap` roundtrip (0.06 vs 1.93 µs)
- Full processor pipeline: **83 µs for 1000 fixes** = 0.083 µs per fix
- Adaptive mode adds **zero overhead** (83.20 vs 83.39 µs — within noise)
- All critical per-fix operations complete in **< 1 µs** individually
