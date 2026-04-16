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

### 2026-04-16 — Commit f86beef

**Environment:** Dart 3.11.4, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7417213 | 0.13 |
| kalman_process_100_fixes | 96733 | 10.34 |
| kalman_process_1k_fixes | 9714 | 102.94 |
| kalman_reset | 6906111 | 0.14 |
| haversine_single | 8027879 | 0.12 |
| haversine_1k_pairs | 13877 | 72.06 |
| pip_4v | 12935922 | 0.08 |
| pip_10v | 9467827 | 0.11 |
| pip_50v | 3413542 | 0.29 |
| pip_100v | 1954792 | 0.51 |
| pip_500v | 418319 | 2.39 |
| geofence_eval_10_circular | 635654 | 1.57 |
| geofence_eval_100_circular | 68965 | 14.50 |
| geofence_eval_500_circular | 13354 | 74.88 |
| geofence_eval_10_polygon_6v | 411840 | 2.43 |
| geofence_eval_50_polygon_6v | 82756 | 12.08 |
| processor_1k_fixes | 8916 | 112.15 |
| processor_1k_adaptive | 8349 | 119.77 |
| trip_manager_5k_waypoints | 74 | 13553.61 |
| schedule_parse | 2828008 | 0.35 |
| schedule_matches | 133692 | 7.48 |
| schedule_isWithin_5_entries | 126731 | 7.89 |
| adaptive_compute | 13495710 | 0.07 |
| location_fromMap | 1670818 | 0.60 |
| location_toMap | 675318 | 1.48 |
| location_fromMap_toMap_roundtrip | 489310 | 2.04 |
| location_copyWithCoords | 11959252 | 0.08 |
| geofence_fromMap_circular | 4309158 | 0.23 |
| geofence_fromMap_polygon | 1580834 | 0.63 |
| delta_encode_10 | 29023 | 34.45 |
| delta_decode_10 | 96257 | 10.39 |
| delta_encode_100 | 3960 | 252.52 |
| delta_decode_100 | 10766 | 92.89 |
| delta_encode_500 | 824 | 1214.22 |
| delta_decode_500 | 2109 | 474.06 |
| delta_roundtrip_100 | 2983 | 335.24 |
| battery_budget_single_sample | 9103254 | 0.11 |
| battery_budget_60_samples | 291955 | 3.43 |
| battery_budget_heavy_drain | 144538 | 6.92 |
| carbon_trip_100_locations | 88457 | 11.30 |
| carbon_onLocation | 4252377 | 0.24 |
| carbon_setActivity | 9778889 | 0.10 |
| carbon_cumulative_report | 2784538 | 0.36 |
| persist_decider_location | 19888545 | 0.05 |
| persist_decider_geofence | 19820893 | 0.05 |
| config_fromMap | 430145 | 2.32 |
| config_toMap | 160317 | 6.24 |
| config_roundtrip | 114465 | 8.74 |
| state_fromMap | 403556 | 2.48 |
| state_toMap | 150886 | 6.63 |
| route_context_toMap | 3113304 | 0.32 |
| route_context_fromMap | 2415609 | 0.41 |
| route_context_roundtrip | 1444100 | 0.69 |
| sync_body_context_toMap_50 | 8469181 | 0.12 |
| sync_body_context_fromMap_50 | 23202 | 43.10 |
| http_config_ssl_toMap | 762864 | 1.31 |
| http_config_ssl_fromMap | 1403826 | 0.71 |
| http_config_ssl_roundtrip | 501316 | 1.99 |


