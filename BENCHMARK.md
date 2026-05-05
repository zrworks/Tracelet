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

### 2026-05-05 — Commit 9fea812

**Environment:** Dart 3.11.5, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 8926047 | 0.11 |
| kalman_process_100_fixes | 130406 | 7.67 |
| kalman_process_1k_fixes | 13189 | 75.82 |
| kalman_reset | 8294282 | 0.12 |
| haversine_single | 10463374 | 0.10 |
| haversine_1k_pairs | 17612 | 56.78 |
| pip_4v | 16616122 | 0.06 |
| pip_10v | 12365458 | 0.08 |
| pip_50v | 4351187 | 0.23 |
| pip_100v | 2447100 | 0.41 |
| pip_500v | 488359 | 2.05 |
| geofence_eval_10_circular | 843630 | 1.19 |
| geofence_eval_100_circular | 91498 | 10.93 |
| geofence_eval_500_circular | 17918 | 55.81 |
| geofence_eval_10_polygon_6v | 521571 | 1.92 |
| geofence_eval_50_polygon_6v | 108397 | 9.23 |
| processor_1k_fixes | 11998 | 83.35 |
| processor_1k_adaptive | 11279 | 88.66 |
| trip_manager_5k_waypoints | 83 | 12070.81 |
| schedule_parse | 3739783 | 0.27 |
| schedule_matches | 151885 | 6.58 |
| schedule_isWithin_5_entries | 141992 | 7.04 |
| adaptive_compute | 16705056 | 0.06 |
| location_fromMap | 2149723 | 0.47 |
| location_toMap | 837640 | 1.19 |
| location_fromMap_toMap_roundtrip | 631422 | 1.58 |
| location_copyWithCoords | 14681852 | 0.07 |
| geofence_fromMap_circular | 5538129 | 0.18 |
| geofence_fromMap_polygon | 2035720 | 0.49 |
| delta_encode_10 | 41030 | 24.37 |
| delta_decode_10 | 126445 | 7.91 |
| delta_encode_100 | 5690 | 175.74 |
| delta_decode_100 | 14624 | 68.38 |
| delta_encode_500 | 1099 | 910.10 |
| delta_decode_500 | 2774 | 360.53 |
| delta_roundtrip_100 | 4070 | 245.72 |
| battery_budget_single_sample | 11153448 | 0.09 |
| battery_budget_60_samples | 351075 | 2.85 |
| battery_budget_heavy_drain | 179615 | 5.57 |
| carbon_trip_100_locations | 113560 | 8.81 |
| carbon_onLocation | 5262985 | 0.19 |
| carbon_setActivity | 12390516 | 0.08 |
| carbon_cumulative_report | 3478752 | 0.29 |
| persist_decider_location | 24941350 | 0.04 |
| persist_decider_geofence | 25127611 | 0.04 |
| config_fromMap | 539216 | 1.85 |
| config_toMap | 203422 | 4.92 |
| config_roundtrip | 144931 | 6.90 |
| state_fromMap | 515488 | 1.94 |
| state_toMap | 193281 | 5.17 |
| route_context_toMap | 3887877 | 0.26 |
| route_context_fromMap | 3014020 | 0.33 |
| route_context_roundtrip | 1821809 | 0.55 |
| sync_body_context_toMap_50 | 10644380 | 0.09 |
| sync_body_context_fromMap_50 | 28974 | 34.51 |
| http_config_ssl_toMap | 987739 | 1.01 |
| http_config_ssl_fromMap | 1777303 | 0.56 |
| http_config_ssl_roundtrip | 651679 | 1.53 |


