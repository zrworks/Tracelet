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

### 2026-05-05 — Commit 41a7223

**Environment:** Dart 3.11.5, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7395950 | 0.14 |
| kalman_process_100_fixes | 84910 | 11.78 |
| kalman_process_1k_fixes | 8529 | 117.25 |
| kalman_reset | 6888664 | 0.15 |
| haversine_single | 8090662 | 0.12 |
| haversine_1k_pairs | 13933 | 71.77 |
| pip_4v | 13345910 | 0.07 |
| pip_10v | 10193586 | 0.10 |
| pip_50v | 3997996 | 0.25 |
| pip_100v | 2145833 | 0.47 |
| pip_500v | 421222 | 2.37 |
| geofence_eval_10_circular | 639648 | 1.56 |
| geofence_eval_100_circular | 69274 | 14.44 |
| geofence_eval_500_circular | 13445 | 74.38 |
| geofence_eval_10_polygon_6v | 417793 | 2.39 |
| geofence_eval_50_polygon_6v | 84259 | 11.87 |
| processor_1k_fixes | 9030 | 110.75 |
| processor_1k_adaptive | 8443 | 118.44 |
| trip_manager_5k_waypoints | 73 | 13656.90 |
| schedule_parse | 2833876 | 0.35 |
| schedule_matches | 130885 | 7.64 |
| schedule_isWithin_5_entries | 121985 | 8.20 |
| adaptive_compute | 13519909 | 0.07 |
| location_fromMap | 1693287 | 0.59 |
| location_toMap | 672530 | 1.49 |
| location_fromMap_toMap_roundtrip | 479473 | 2.09 |
| location_copyWithCoords | 12074903 | 0.08 |
| geofence_fromMap_circular | 4483918 | 0.22 |
| geofence_fromMap_polygon | 1611698 | 0.62 |
| delta_encode_10 | 29645 | 33.73 |
| delta_decode_10 | 95784 | 10.44 |
| delta_encode_100 | 3969 | 251.98 |
| delta_decode_100 | 10891 | 91.82 |
| delta_encode_500 | 804 | 1244.54 |
| delta_decode_500 | 2325 | 430.02 |
| delta_roundtrip_100 | 2971 | 336.55 |
| battery_budget_single_sample | 9038277 | 0.11 |
| battery_budget_60_samples | 292165 | 3.42 |
| battery_budget_heavy_drain | 147367 | 6.79 |
| carbon_trip_100_locations | 89931 | 11.12 |
| carbon_onLocation | 4134294 | 0.24 |
| carbon_setActivity | 9745962 | 0.10 |
| carbon_cumulative_report | 2730886 | 0.37 |
| persist_decider_location | 19892564 | 0.05 |
| persist_decider_geofence | 19913518 | 0.05 |
| config_fromMap | 419133 | 2.39 |
| config_toMap | 156548 | 6.39 |
| config_roundtrip | 112266 | 8.91 |
| state_fromMap | 394345 | 2.54 |
| state_toMap | 147514 | 6.78 |
| route_context_toMap | 3029656 | 0.33 |
| route_context_fromMap | 2395699 | 0.42 |
| route_context_roundtrip | 1457990 | 0.69 |
| sync_body_context_toMap_50 | 8350128 | 0.12 |
| sync_body_context_fromMap_50 | 23078 | 43.33 |
| http_config_ssl_toMap | 754742 | 1.32 |
| http_config_ssl_fromMap | 1401206 | 0.71 |
| http_config_ssl_roundtrip | 491122 | 2.04 |


