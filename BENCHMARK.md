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

### 2026-05-05 — Commit e17d479

**Environment:** Dart 3.11.5, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7184617 | 0.14 |
| kalman_process_100_fixes | 95151 | 10.51 |
| kalman_process_1k_fixes | 9492 | 105.36 |
| kalman_reset | 6764260 | 0.15 |
| haversine_single | 8040372 | 0.12 |
| haversine_1k_pairs | 13767 | 72.64 |
| pip_4v | 13139344 | 0.08 |
| pip_10v | 10109994 | 0.10 |
| pip_50v | 3777591 | 0.26 |
| pip_100v | 1951564 | 0.51 |
| pip_500v | 422263 | 2.37 |
| geofence_eval_10_circular | 645188 | 1.55 |
| geofence_eval_100_circular | 69868 | 14.31 |
| geofence_eval_500_circular | 13462 | 74.28 |
| geofence_eval_10_polygon_6v | 405433 | 2.47 |
| geofence_eval_50_polygon_6v | 84277 | 11.87 |
| processor_1k_fixes | 8905 | 112.29 |
| processor_1k_adaptive | 8378 | 119.36 |
| trip_manager_5k_waypoints | 72 | 13929.38 |
| schedule_parse | 2781939 | 0.36 |
| schedule_matches | 132025 | 7.57 |
| schedule_isWithin_5_entries | 125504 | 7.97 |
| adaptive_compute | 13814484 | 0.07 |
| location_fromMap | 1739704 | 0.57 |
| location_toMap | 689104 | 1.45 |
| location_fromMap_toMap_roundtrip | 492341 | 2.03 |
| location_copyWithCoords | 11532228 | 0.09 |
| geofence_fromMap_circular | 4407443 | 0.23 |
| geofence_fromMap_polygon | 1578242 | 0.63 |
| delta_encode_10 | 28254 | 35.39 |
| delta_decode_10 | 98712 | 10.13 |
| delta_encode_100 | 3931 | 254.40 |
| delta_decode_100 | 11033 | 90.64 |
| delta_encode_500 | 780 | 1282.08 |
| delta_decode_500 | 2404 | 415.90 |
| delta_roundtrip_100 | 2884 | 346.77 |
| battery_budget_single_sample | 8938596 | 0.11 |
| battery_budget_60_samples | 290850 | 3.44 |
| battery_budget_heavy_drain | 148065 | 6.75 |
| carbon_trip_100_locations | 88859 | 11.25 |
| carbon_onLocation | 4131014 | 0.24 |
| carbon_setActivity | 9736352 | 0.10 |
| carbon_cumulative_report | 2769135 | 0.36 |
| persist_decider_location | 19898971 | 0.05 |
| persist_decider_geofence | 19869131 | 0.05 |
| config_fromMap | 414024 | 2.42 |
| config_toMap | 157732 | 6.34 |
| config_roundtrip | 114509 | 8.73 |
| state_fromMap | 388541 | 2.57 |
| state_toMap | 149240 | 6.70 |
| route_context_toMap | 3087819 | 0.32 |
| route_context_fromMap | 2280502 | 0.44 |
| route_context_roundtrip | 1410472 | 0.71 |
| sync_body_context_toMap_50 | 8527201 | 0.12 |
| sync_body_context_fromMap_50 | 22979 | 43.52 |
| http_config_ssl_toMap | 749054 | 1.34 |
| http_config_ssl_fromMap | 1365947 | 0.73 |
| http_config_ssl_roundtrip | 502889 | 1.99 |


