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
| `delta_encode_10` | Delta-encode batch of 10 locations | HTTP sync |
| `delta_encode_100` | Delta-encode batch of 100 locations | HTTP sync |
| `delta_encode_500` | Delta-encode batch of 500 locations | Bulk sync |
| `delta_decode_10` | Delta-decode batch of 10 locations | Server restore |
| `delta_decode_100` | Delta-decode batch of 100 locations | Server restore |
| `delta_decode_500` | Delta-decode batch of 500 locations | Bulk restore |
| `delta_roundtrip_100` | Full encode→decode round-trip, 100 locations | Correctness path |
| `battery_budget_single_sample` | Single battery sample processing | Every battery read |
| `battery_budget_60_samples` | 60 samples (1-hour simulation) | Sustained tracking |
| `battery_budget_heavy_drain` | 120 samples with aggressive drain | Worst-case budget |
| `carbon_trip_100_locations` | Full trip with 100 GPS fixes | Trip completion |
| `carbon_onLocation` | Per-location carbon accounting | Every GPS fix |
| `carbon_setActivity` | Activity type switching | Activity change |
| `carbon_cumulative_report` | Generate cumulative report (10 trips) | Report request |
| `persist_decider_location` | Location persist decision (all modes) | Every GPS fix |
| `persist_decider_geofence` | Geofence persist decision (all modes) | Geofence event |
| `config_fromMap` | Deserialize full Config from map | Config restore |
| `config_toMap` | Serialize full Config to map | Config persist |
| `config_roundtrip` | Full Config serialization round-trip | Config update |
| `state_fromMap` | Deserialize State from map | State restore |
| `state_toMap` | Serialize State to map | State persist |
| `route_context_toMap` | Serialize RouteContext to map | Route context attach |
| `route_context_fromMap` | Deserialize RouteContext from map | Route context restore |
| `route_context_roundtrip` | Full RouteContext serialization round-trip | Route context update |
| `sync_body_context_toMap_50` | Serialize SyncBodyContext with 50 locations | Sync body build |
| `sync_body_context_fromMap_50` | Deserialize SyncBodyContext with 50 locations | Sync body restore |
| `http_config_ssl_toMap` | Serialize HttpConfig with SSL pinning fields | Config persist |
| `http_config_ssl_fromMap` | Deserialize HttpConfig with SSL pinning fields | Config restore |
| `http_config_ssl_roundtrip` | Full HttpConfig+SSL serialization round-trip | Config update |

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

### 2026-05-21 — Commit f7fc07c

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7013083 | 0.14 |
| kalman_process_100_fixes | 101470 | 9.86 |
| kalman_process_1k_fixes | 10258 | 97.48 |
| kalman_reset | 6581106 | 0.15 |
| haversine_single | 7668516 | 0.13 |
| haversine_1k_pairs | 13678 | 73.11 |
| pip_4v | 12707241 | 0.08 |
| pip_10v | 9541770 | 0.10 |
| pip_50v | 3655255 | 0.27 |
| pip_100v | 1966971 | 0.51 |
| pip_500v | 382089 | 2.62 |
| geofence_eval_10_circular | 664090 | 1.51 |
| geofence_eval_100_circular | 70955 | 14.09 |
| geofence_eval_500_circular | 13884 | 72.03 |
| geofence_eval_10_polygon_6v | 414961 | 2.41 |
| geofence_eval_50_polygon_6v | 84451 | 11.84 |
| processor_1k_fixes | 9458 | 105.73 |
| processor_1k_adaptive | 8708 | 114.83 |
| trip_manager_5k_waypoints | 62 | 16136.69 |
| schedule_parse | 2873917 | 0.35 |
| schedule_matches | 113338 | 8.82 |
| schedule_isWithin_5_entries | 105145 | 9.51 |
| adaptive_compute | 12851410 | 0.08 |
| location_fromMap | 1678184 | 0.60 |
| location_toMap | 684686 | 1.46 |
| location_fromMap_toMap_roundtrip | 489483 | 2.04 |
| location_copyWithCoords | 11411555 | 0.09 |
| geofence_fromMap_circular | 4297215 | 0.23 |
| geofence_fromMap_polygon | 1592598 | 0.63 |
| delta_encode_10 | 15254 | 65.56 |
| delta_decode_10 | 92756 | 10.78 |
| delta_encode_100 | 2691 | 371.61 |
| delta_decode_100 | 11337 | 88.20 |
| delta_encode_500 | 536 | 1866.88 |
| delta_decode_500 | 2123 | 471.00 |
| delta_roundtrip_100 | 2136 | 468.20 |
| battery_budget_single_sample | 8421184 | 0.12 |
| battery_budget_60_samples | 283996 | 3.52 |
| battery_budget_heavy_drain | 144086 | 6.94 |
| carbon_trip_100_locations | 86871 | 11.51 |
| carbon_onLocation | 4236228 | 0.24 |
| carbon_setActivity | 9635957 | 0.10 |
| carbon_cumulative_report | 2650522 | 0.38 |
| persist_decider_location | 19032717 | 0.05 |
| persist_decider_geofence | 19133312 | 0.05 |
| config_fromMap | 493807 | 2.03 |
| config_toMap | 144728 | 6.91 |
| config_roundtrip | 110947 | 9.01 |
| state_fromMap | 462741 | 2.16 |
| state_toMap | 137379 | 7.28 |
| route_context_toMap | 3022867 | 0.33 |
| route_context_fromMap | 2301718 | 0.43 |
| route_context_roundtrip | 1399720 | 0.71 |
| sync_body_context_toMap_50 | 8276942 | 0.12 |
| sync_body_context_fromMap_50 | 22104 | 45.24 |
| http_config_ssl_toMap | 821895 | 1.22 |
| http_config_ssl_fromMap | 3250613 | 0.31 |
| http_config_ssl_roundtrip | 671613 | 1.49 |


### 2026-05-20 — Commit 91ce040

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 6739908 | 0.15 |
| kalman_process_100_fixes | 102442 | 9.76 |
| kalman_process_1k_fixes | 10332 | 96.79 |
| kalman_reset | 6390556 | 0.16 |
| haversine_single | 7860303 | 0.13 |
| haversine_1k_pairs | 13554 | 73.78 |
| pip_4v | 12839115 | 0.08 |
| pip_10v | 9605805 | 0.10 |
| pip_50v | 3407937 | 0.29 |
| pip_100v | 1839547 | 0.54 |
| pip_500v | 383299 | 2.61 |
| geofence_eval_10_circular | 662386 | 1.51 |
| geofence_eval_100_circular | 71387 | 14.01 |
| geofence_eval_500_circular | 13743 | 72.76 |
| geofence_eval_10_polygon_6v | 409602 | 2.44 |
| geofence_eval_50_polygon_6v | 85701 | 11.67 |
| processor_1k_fixes | 9281 | 107.74 |
| processor_1k_adaptive | 8624 | 115.95 |
| trip_manager_5k_waypoints | 62 | 16226.36 |
| schedule_parse | 2892258 | 0.35 |
| schedule_matches | 113407 | 8.82 |
| schedule_isWithin_5_entries | 107081 | 9.34 |
| adaptive_compute | 13037066 | 0.08 |
| location_fromMap | 1684626 | 0.59 |
| location_toMap | 671497 | 1.49 |
| location_fromMap_toMap_roundtrip | 483670 | 2.07 |
| location_copyWithCoords | 11163569 | 0.09 |
| geofence_fromMap_circular | 4287126 | 0.23 |
| geofence_fromMap_polygon | 1580979 | 0.63 |
| delta_encode_10 | 15250 | 65.57 |
| delta_decode_10 | 92146 | 10.85 |
| delta_encode_100 | 2594 | 385.49 |
| delta_decode_100 | 11277 | 88.68 |
| delta_encode_500 | 542 | 1846.39 |
| delta_decode_500 | 2167 | 461.43 |
| delta_roundtrip_100 | 2154 | 464.15 |
| battery_budget_single_sample | 8536613 | 0.12 |
| battery_budget_60_samples | 276568 | 3.62 |
| battery_budget_heavy_drain | 137866 | 7.25 |
| carbon_trip_100_locations | 86673 | 11.54 |
| carbon_onLocation | 4148227 | 0.24 |
| carbon_setActivity | 9639152 | 0.10 |
| carbon_cumulative_report | 2686962 | 0.37 |
| persist_decider_location | 19238220 | 0.05 |
| persist_decider_geofence | 19411059 | 0.05 |
| config_fromMap | 491798 | 2.03 |
| config_toMap | 141695 | 7.06 |
| config_roundtrip | 107765 | 9.28 |
| state_fromMap | 448962 | 2.23 |
| state_toMap | 135185 | 7.40 |
| route_context_toMap | 3046162 | 0.33 |
| route_context_fromMap | 2420811 | 0.41 |
| route_context_roundtrip | 1435110 | 0.70 |
| sync_body_context_toMap_50 | 8200717 | 0.12 |
| sync_body_context_fromMap_50 | 22607 | 44.23 |
| http_config_ssl_toMap | 814574 | 1.23 |
| http_config_ssl_fromMap | 3233284 | 0.31 |
| http_config_ssl_roundtrip | 666093 | 1.50 |


### 2026-05-20 — Commit ba33eeb

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

(no table captured)


### 2026-05-19 — Commit 6a5ef60

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

(no table captured)


### 2026-05-18 — Commit 106fdde

**Environment:** Dart 3.11.5, ubuntu-latest (CI)

(no table captured)


### 2026-05-16 — Commit ec97681

**Environment:** Dart 3.11.5, ubuntu-latest (CI)

(no table captured)


