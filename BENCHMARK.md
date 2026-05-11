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

### 2026-05-11 — Commit 851af91

**Environment:** Dart 3.11.5, ubuntu-latest (CI)

(no table captured)


### 2026-05-05 — Commit 3222e4f

**Environment:** Dart 3.11.5, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 6174764 | 0.16 |
| kalman_process_100_fixes | 93697 | 10.67 |
| kalman_process_1k_fixes | 9455 | 105.77 |
| kalman_reset | 5768568 | 0.17 |
| haversine_single | 7028469 | 0.14 |
| haversine_1k_pairs | 13749 | 72.73 |
| pip_4v | 10844855 | 0.09 |
| pip_10v | 8780714 | 0.11 |
| pip_50v | 3669020 | 0.27 |
| pip_100v | 2054064 | 0.49 |
| pip_500v | 423135 | 2.36 |
| geofence_eval_10_circular | 634296 | 1.58 |
| geofence_eval_100_circular | 69441 | 14.40 |
| geofence_eval_500_circular | 13394 | 74.66 |
| geofence_eval_10_polygon_6v | 412924 | 2.42 |
| geofence_eval_50_polygon_6v | 82198 | 12.17 |
| processor_1k_fixes | 8872 | 112.72 |
| processor_1k_adaptive | 8458 | 118.23 |
| trip_manager_5k_waypoints | 74 | 13591.55 |
| schedule_parse | 2697547 | 0.37 |
| schedule_matches | 130959 | 7.64 |
| schedule_isWithin_5_entries | 124514 | 8.03 |
| adaptive_compute | 10642222 | 0.09 |
| location_fromMap | 1558732 | 0.64 |
| location_toMap | 665188 | 1.50 |
| location_fromMap_toMap_roundtrip | 476668 | 2.10 |
| location_copyWithCoords | 9524430 | 0.10 |
| geofence_fromMap_circular | 3974374 | 0.25 |
| geofence_fromMap_polygon | 1497462 | 0.67 |
| delta_encode_10 | 29280 | 34.15 |
| delta_decode_10 | 96723 | 10.34 |
| delta_encode_100 | 4020 | 248.75 |
| delta_decode_100 | 10962 | 91.23 |
| delta_encode_500 | 837 | 1194.63 |
| delta_decode_500 | 2121 | 471.53 |
| delta_roundtrip_100 | 2977 | 335.95 |
| battery_budget_single_sample | 7312828 | 0.14 |
| battery_budget_60_samples | 291050 | 3.44 |
| battery_budget_heavy_drain | 144147 | 6.94 |
| carbon_trip_100_locations | 88542 | 11.29 |
| carbon_onLocation | 3820894 | 0.26 |
| carbon_setActivity | 7962763 | 0.13 |
| carbon_cumulative_report | 2492331 | 0.40 |
| persist_decider_location | 12768865 | 0.08 |
| persist_decider_geofence | 12733003 | 0.08 |
| config_fromMap | 410815 | 2.43 |
| config_toMap | 158530 | 6.31 |
| config_roundtrip | 111644 | 8.96 |
| state_fromMap | 378939 | 2.64 |
| state_toMap | 147650 | 6.77 |
| route_context_toMap | 2844830 | 0.35 |
| route_context_fromMap | 2258642 | 0.44 |
| route_context_roundtrip | 1327216 | 0.75 |
| sync_body_context_toMap_50 | 7314491 | 0.14 |
| sync_body_context_fromMap_50 | 22952 | 43.57 |
| http_config_ssl_toMap | 739593 | 1.35 |
| http_config_ssl_fromMap | 1391216 | 0.72 |
| http_config_ssl_roundtrip | 488492 | 2.05 |


