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

### 2026-06-06 — Commit 03147e0

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 84033 | 11.90 |
| schedule_isWithin_5_entries | 76804 | 13.02 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 653594 | 1.53 |
| location_fromMap_toMap_roundtrip | 473933 | 2.11 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 89847 | 11.13 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 438596 | 2.28 |
| config_toMap | 127064 | 7.87 |
| config_roundtrip | 96618 | 10.35 |
| state_fromMap | 411522 | 2.43 |
| state_toMap | 120627 | 8.29 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 22007 | 45.44 |
| http_config_ssl_toMap | 746268 | 1.34 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 598802 | 1.67 |
| smart_motion_accel_change | 22121334 | 0.05 |
| smart_motion_speed_change | 21921925 | 0.05 |
| battery_budget_single_sample | 22031231 | 0.05 |
| battery_budget_60_samples | 1283641 | 0.78 |
| battery_budget_heavy_drain | 664008 | 1.51 |


### 2026-06-06 — Commit 2ede380

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 92165 | 10.85 |
| schedule_isWithin_5_entries | 85034 | 11.76 |
| location_fromMap | 1587301 | 0.63 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 469483 | 2.13 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 90661 | 11.03 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 440528 | 2.27 |
| config_toMap | 126262 | 7.92 |
| config_roundtrip | 98135 | 10.19 |
| state_fromMap | 421940 | 2.37 |
| state_toMap | 119474 | 8.37 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1408450 | 0.71 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22732 | 43.99 |
| http_config_ssl_toMap | 729927 | 1.37 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 595238 | 1.68 |
| battery_budget_single_sample | 23732060 | 0.04 |
| battery_budget_60_samples | 1305300 | 0.77 |
| smart_motion_accel_change | 23463906 | 0.04 |
| smart_motion_speed_change | 23411879 | 0.04 |
| battery_budget_heavy_drain | 676513 | 1.48 |


### 2026-06-06 — Commit cf67cd5

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 85034 | 11.76 |
| schedule_isWithin_5_entries | 77399 | 12.92 |
| location_fromMap | 1587301 | 0.63 |
| location_toMap | 641025 | 1.56 |
| location_fromMap_toMap_roundtrip | 469483 | 2.13 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 90661 | 11.03 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2439024 | 0.41 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 434782 | 2.30 |
| config_toMap | 126262 | 7.92 |
| config_roundtrip | 96805 | 10.33 |
| state_fromMap | 409836 | 2.44 |
| state_toMap | 121654 | 8.22 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21748 | 45.98 |
| http_config_ssl_toMap | 735294 | 1.36 |
| http_config_ssl_fromMap | 2777777 | 0.36 |
| http_config_ssl_roundtrip | 584795 | 1.71 |
| battery_budget_single_sample | 21982314 | 0.05 |
| smart_motion_accel_change | 22184587 | 0.05 |
| smart_motion_speed_change | 22028521 | 0.05 |
| battery_budget_heavy_drain | 664456 | 1.50 |
| battery_budget_60_samples | 1288075 | 0.78 |


### 2026-06-06 — Commit 0fa23f8

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 82781 | 12.08 |
| schedule_isWithin_5_entries | 76923 | 13.00 |
| location_fromMap | 1612903 | 0.62 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 462962 | 2.16 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4166666 | 0.24 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 91491 | 10.93 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 8333333 | 0.12 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 425531 | 2.35 |
| config_toMap | 124533 | 8.03 |
| config_roundtrip | 96618 | 10.35 |
| state_fromMap | 403225 | 2.48 |
| state_toMap | 121212 | 8.25 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1315789 | 0.76 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21896 | 45.67 |
| http_config_ssl_toMap | 735294 | 1.36 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 598802 | 1.67 |
| battery_budget_heavy_drain | 663314 | 1.51 |
| battery_budget_60_samples | 1285391 | 0.78 |
| battery_budget_single_sample | 22002495 | 0.05 |
| smart_motion_accel_change | 22102818 | 0.05 |
| smart_motion_speed_change | 21981397 | 0.05 |


### 2026-06-06 — Commit 95ffba6

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 3125000 | 0.32 |
| schedule_matches | 148148 | 6.75 |
| schedule_isWithin_5_entries | 125786 | 7.95 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 657894 | 1.52 |
| location_fromMap_toMap_roundtrip | 476190 | 2.10 |
| location_copyWithCoords | 12500000 | 0.08 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1724137 | 0.58 |
| carbon_trip_100_locations | 114416 | 8.74 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 10000000 | 0.10 |
| carbon_cumulative_report | 2631578 | 0.38 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 458715 | 2.18 |
| config_toMap | 130718 | 7.65 |
| config_roundtrip | 102564 | 9.75 |
| state_fromMap | 458715 | 2.18 |
| state_toMap | 124533 | 8.03 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2380952 | 0.42 |
| route_context_roundtrip | 1408450 | 0.71 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22461 | 44.52 |
| http_config_ssl_toMap | 751879 | 1.33 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 613496 | 1.63 |
| battery_budget_single_sample | 24062110 | 0.04 |
| battery_budget_60_samples | 841972 | 1.19 |
| battery_budget_heavy_drain | 426531 | 2.34 |
| smart_motion_accel_change | 17637360 | 0.06 |
| smart_motion_speed_change | 17555470 | 0.06 |


### 2026-06-05 — Commit 9d4be5f

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 90826 | 11.01 |
| schedule_isWithin_5_entries | 82987 | 12.05 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 469483 | 2.13 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 91827 | 10.89 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 438596 | 2.28 |
| config_toMap | 125313 | 7.98 |
| config_roundtrip | 95785 | 10.44 |
| state_fromMap | 411522 | 2.43 |
| state_toMap | 119047 | 8.40 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22416 | 44.61 |
| http_config_ssl_toMap | 729927 | 1.37 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 598802 | 1.67 |
| battery_budget_single_sample | 23749077 | 0.04 |
| battery_budget_60_samples | 1307305 | 0.76 |
| battery_budget_heavy_drain | 677024 | 1.48 |
| smart_motion_accel_change | 23521822 | 0.04 |
| smart_motion_speed_change | 23447170 | 0.04 |


### 2026-06-05 — Commit 50511f3

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 92336 | 10.83 |
| schedule_isWithin_5_entries | 84745 | 11.80 |
| location_fromMap | 1724137 | 0.58 |
| location_toMap | 641025 | 1.56 |
| location_fromMap_toMap_roundtrip | 469483 | 2.13 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 92081 | 10.86 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 448430 | 2.23 |
| config_toMap | 127388 | 7.85 |
| config_roundtrip | 98135 | 10.19 |
| state_fromMap | 420168 | 2.38 |
| state_toMap | 120048 | 8.33 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1388888 | 0.72 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 21915 | 45.63 |
| http_config_ssl_toMap | 735294 | 1.36 |
| http_config_ssl_fromMap | 2941176 | 0.34 |
| http_config_ssl_roundtrip | 598802 | 1.67 |
| battery_budget_60_samples | 1303475 | 0.77 |
| smart_motion_speed_change | 23423719 | 0.04 |
| battery_budget_single_sample | 23772671 | 0.04 |
| battery_budget_heavy_drain | 677898 | 1.48 |
| smart_motion_accel_change | 23524023 | 0.04 |


### 2026-06-05 — Commit d0b198b

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2564102 | 0.39 |
| schedule_matches | 83612 | 11.96 |
| schedule_isWithin_5_entries | 77101 | 12.97 |
| location_fromMap | 1587301 | 0.63 |
| location_toMap | 628930 | 1.59 |
| location_fromMap_toMap_roundtrip | 462962 | 2.16 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1515151 | 0.66 |
| carbon_trip_100_locations | 90579 | 11.04 |
| carbon_onLocation | 3703703 | 0.27 |
| carbon_setActivity | 7692307 | 0.13 |
| carbon_cumulative_report | 2439024 | 0.41 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 431034 | 2.32 |
| config_toMap | 126422 | 7.91 |
| config_roundtrip | 98039 | 10.20 |
| state_fromMap | 408163 | 2.45 |
| state_toMap | 119904 | 8.34 |
| route_context_toMap | 2857142 | 0.35 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1282051 | 0.78 |
| sync_body_context_toMap_50 | 6666666 | 0.15 |
| sync_body_context_fromMap_50 | 19131 | 52.27 |
| http_config_ssl_toMap | 714285 | 1.40 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 584795 | 1.71 |
| smart_motion_accel_change | 22100438 | 0.05 |
| battery_budget_60_samples | 1287944 | 0.78 |
| battery_budget_heavy_drain | 665649 | 1.50 |
| battery_budget_single_sample | 21855942 | 0.05 |
| smart_motion_speed_change | 21976355 | 0.05 |


### 2026-06-05 — Commit 283d1d1

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 91157 | 10.97 |
| schedule_isWithin_5_entries | 83333 | 12.00 |
| location_fromMap | 1724137 | 0.58 |
| location_toMap | 641025 | 1.56 |
| location_fromMap_toMap_roundtrip | 452488 | 2.21 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4761904 | 0.21 |
| geofence_fromMap_polygon | 1515151 | 0.66 |
| carbon_trip_100_locations | 93720 | 10.67 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 438596 | 2.28 |
| config_toMap | 123152 | 8.12 |
| config_roundtrip | 95969 | 10.42 |
| state_fromMap | 408163 | 2.45 |
| state_toMap | 117785 | 8.49 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22011 | 45.43 |
| http_config_ssl_toMap | 724637 | 1.38 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 568181 | 1.76 |
| battery_budget_single_sample | 23758760 | 0.04 |
| battery_budget_60_samples | 1307655 | 0.76 |
| battery_budget_heavy_drain | 678181 | 1.47 |
| smart_motion_accel_change | 23515818 | 0.04 |
| smart_motion_speed_change | 23438397 | 0.04 |


### 2026-06-05 — Commit d6793c5

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 3571428 | 0.28 |
| schedule_matches | 110132 | 9.08 |
| schedule_isWithin_5_entries | 99800 | 10.02 |
| location_fromMap | 2127659 | 0.47 |
| location_toMap | 840336 | 1.19 |
| location_fromMap_toMap_roundtrip | 609756 | 1.64 |
| location_copyWithCoords | 12500000 | 0.08 |
| geofence_fromMap_circular | 5555555 | 0.18 |
| geofence_fromMap_polygon | 1960784 | 0.51 |
| carbon_trip_100_locations | 116144 | 8.61 |
| carbon_onLocation | 5000000 | 0.20 |
| carbon_setActivity | 11111111 | 0.09 |
| carbon_cumulative_report | 3225806 | 0.31 |
| persist_decider_location | 25000000 | 0.04 |
| persist_decider_geofence | 25000000 | 0.04 |
| config_fromMap | 568181 | 1.76 |
| config_toMap | 163934 | 6.10 |
| config_roundtrip | 125156 | 7.99 |
| state_fromMap | 534759 | 1.87 |
| state_toMap | 156006 | 6.41 |
| route_context_toMap | 3703703 | 0.27 |
| route_context_fromMap | 2777777 | 0.36 |
| route_context_roundtrip | 1694915 | 0.59 |
| sync_body_context_toMap_50 | 9090909 | 0.11 |
| sync_body_context_fromMap_50 | 28538 | 35.04 |
| http_config_ssl_toMap | 952380 | 1.05 |
| http_config_ssl_fromMap | 3571428 | 0.28 |
| http_config_ssl_roundtrip | 769230 | 1.30 |
| smart_motion_speed_change | 28360333 | 0.04 |
| smart_motion_accel_change | 28565341 | 0.04 |
| battery_budget_60_samples | 1654041 | 0.60 |
| battery_budget_heavy_drain | 857776 | 1.17 |
| battery_budget_single_sample | 28271961 | 0.04 |


### 2026-06-05 — Commit 141bbcd

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 92678 | 10.79 |
| schedule_isWithin_5_entries | 83612 | 11.96 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 641025 | 1.56 |
| location_fromMap_toMap_roundtrip | 467289 | 2.14 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4761904 | 0.21 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 93457 | 10.70 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2631578 | 0.38 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 432900 | 2.31 |
| config_toMap | 125313 | 7.98 |
| config_roundtrip | 95877 | 10.43 |
| state_fromMap | 413223 | 2.42 |
| state_toMap | 122399 | 8.17 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22177 | 45.09 |
| http_config_ssl_toMap | 724637 | 1.38 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 598802 | 1.67 |
| battery_budget_60_samples | 1290563 | 0.77 |
| smart_motion_accel_change | 21775424 | 0.05 |
| battery_budget_single_sample | 18676443 | 0.05 |
| smart_motion_speed_change | 20667015 | 0.05 |
| battery_budget_heavy_drain | 672519 | 1.49 |


### 2026-06-05 — Commit 71f60b7

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 91996 | 10.87 |
| schedule_isWithin_5_entries | 83402 | 11.99 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 641025 | 1.56 |
| location_fromMap_toMap_roundtrip | 467289 | 2.14 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 92506 | 10.81 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 429184 | 2.33 |
| config_toMap | 124223 | 8.05 |
| config_roundtrip | 96061 | 10.41 |
| state_fromMap | 403225 | 2.48 |
| state_toMap | 118483 | 8.44 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 21905 | 45.65 |
| http_config_ssl_toMap | 714285 | 1.40 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 584795 | 1.71 |
| battery_budget_single_sample | 23581071 | 0.04 |
| battery_budget_60_samples | 1307123 | 0.77 |
| smart_motion_accel_change | 23490673 | 0.04 |
| smart_motion_speed_change | 23022252 | 0.04 |
| battery_budget_heavy_drain | 677690 | 1.48 |


### 2026-06-05 — Commit efcc8fa

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 85616 | 11.68 |
| schedule_isWithin_5_entries | 78308 | 12.77 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 469483 | 2.13 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 90909 | 11.00 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 16666666 | 0.06 |
| persist_decider_geofence | 16666666 | 0.06 |
| config_fromMap | 432900 | 2.31 |
| config_toMap | 124378 | 8.04 |
| config_roundtrip | 95877 | 10.43 |
| state_fromMap | 413223 | 2.42 |
| state_toMap | 120336 | 8.31 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21877 | 45.71 |
| http_config_ssl_toMap | 740740 | 1.35 |
| http_config_ssl_fromMap | 2777777 | 0.36 |
| http_config_ssl_roundtrip | 595238 | 1.68 |
| battery_budget_heavy_drain | 664209 | 1.51 |
| smart_motion_speed_change | 21953655 | 0.05 |
| battery_budget_60_samples | 1284701 | 0.78 |
| smart_motion_accel_change | 22122097 | 0.05 |
| battery_budget_single_sample | 22032034 | 0.05 |


### 2026-06-05 — Commit 51f142c

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 83263 | 12.01 |
| schedule_isWithin_5_entries | 73800 | 13.55 |
| location_fromMap | 1612903 | 0.62 |
| location_toMap | 632911 | 1.58 |
| location_fromMap_toMap_roundtrip | 467289 | 2.14 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4166666 | 0.24 |
| geofence_fromMap_polygon | 1515151 | 0.66 |
| carbon_trip_100_locations | 89285 | 11.20 |
| carbon_onLocation | 3846153 | 0.26 |
| carbon_setActivity | 8333333 | 0.12 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 16666666 | 0.06 |
| config_fromMap | 438596 | 2.28 |
| config_toMap | 125628 | 7.96 |
| config_roundtrip | 97276 | 10.28 |
| state_fromMap | 411522 | 2.43 |
| state_toMap | 119617 | 8.36 |
| route_context_toMap | 2857142 | 0.35 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1298701 | 0.77 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21772 | 45.93 |
| http_config_ssl_toMap | 724637 | 1.38 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 595238 | 1.68 |
| battery_budget_single_sample | 22018740 | 0.05 |
| battery_budget_60_samples | 1288966 | 0.78 |
| battery_budget_heavy_drain | 665887 | 1.50 |
| smart_motion_speed_change | 21944251 | 0.05 |
| smart_motion_accel_change | 22152309 | 0.05 |


### 2026-06-04 — Commit aa62bc6

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 83542 | 11.97 |
| schedule_isWithin_5_entries | 77519 | 12.90 |
| location_fromMap | 1612903 | 0.62 |
| location_toMap | 628930 | 1.59 |
| location_fromMap_toMap_roundtrip | 465116 | 2.15 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4166666 | 0.24 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 90252 | 11.08 |
| carbon_onLocation | 3846153 | 0.26 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 434782 | 2.30 |
| config_toMap | 124688 | 8.02 |
| config_roundtrip | 96993 | 10.31 |
| state_fromMap | 409836 | 2.44 |
| state_toMap | 119904 | 8.34 |
| route_context_toMap | 2857142 | 0.35 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21729 | 46.02 |
| http_config_ssl_toMap | 724637 | 1.38 |
| http_config_ssl_fromMap | 2777777 | 0.36 |
| http_config_ssl_roundtrip | 591715 | 1.69 |
| battery_budget_60_samples | 1287015 | 0.78 |
| battery_budget_single_sample | 21834375 | 0.05 |
| smart_motion_accel_change | 22127532 | 0.05 |
| smart_motion_speed_change | 21956199 | 0.05 |
| battery_budget_heavy_drain | 662792 | 1.51 |


### 2026-06-04 — Commit bcd52ed

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 93023 | 10.75 |
| schedule_isWithin_5_entries | 84317 | 11.86 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 653594 | 1.53 |
| location_fromMap_toMap_roundtrip | 471698 | 2.12 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 90579 | 11.04 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 450450 | 2.22 |
| config_toMap | 126103 | 7.93 |
| config_roundtrip | 97087 | 10.30 |
| state_fromMap | 414937 | 2.41 |
| state_toMap | 117508 | 8.51 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22634 | 44.18 |
| http_config_ssl_toMap | 729927 | 1.37 |
| http_config_ssl_fromMap | 2941176 | 0.34 |
| http_config_ssl_roundtrip | 591715 | 1.69 |
| battery_budget_heavy_drain | 677182 | 1.48 |
| smart_motion_speed_change | 23400151 | 0.04 |
| battery_budget_single_sample | 23596274 | 0.04 |
| battery_budget_60_samples | 1308285 | 0.76 |
| smart_motion_accel_change | 23522210 | 0.04 |


### 2026-06-04 — Commit 9d2abd4

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 93109 | 10.74 |
| schedule_isWithin_5_entries | 84745 | 11.80 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 657894 | 1.52 |
| location_fromMap_toMap_roundtrip | 465116 | 2.15 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 94517 | 10.58 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2631578 | 0.38 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 440528 | 2.27 |
| config_toMap | 124378 | 8.04 |
| config_roundtrip | 97943 | 10.21 |
| state_fromMap | 427350 | 2.34 |
| state_toMap | 121506 | 8.23 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1388888 | 0.72 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22232 | 44.98 |
| http_config_ssl_toMap | 735294 | 1.36 |
| http_config_ssl_fromMap | 2777777 | 0.36 |
| http_config_ssl_roundtrip | 591715 | 1.69 |
| battery_budget_single_sample | 23763344 | 0.04 |
| battery_budget_60_samples | 1306342 | 0.77 |
| smart_motion_speed_change | 23448125 | 0.04 |
| battery_budget_heavy_drain | 676701 | 1.48 |
| smart_motion_accel_change | 23553905 | 0.04 |


### 2026-06-04 — Commit 052235c

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 84175 | 11.88 |
| schedule_isWithin_5_entries | 77160 | 12.96 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 469483 | 2.13 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4166666 | 0.24 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 90991 | 10.99 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 436681 | 2.29 |
| config_toMap | 126903 | 7.88 |
| config_roundtrip | 97847 | 10.22 |
| state_fromMap | 414937 | 2.41 |
| state_toMap | 120481 | 8.30 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 7142857 | 0.14 |
| sync_body_context_fromMap_50 | 21417 | 46.69 |
| http_config_ssl_toMap | 735294 | 1.36 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 598802 | 1.67 |
| battery_budget_60_samples | 1289362 | 0.78 |
| battery_budget_heavy_drain | 662252 | 1.51 |
| smart_motion_speed_change | 22001184 | 0.05 |
| battery_budget_single_sample | 22012840 | 0.05 |
| smart_motion_accel_change | 21928618 | 0.05 |


### 2026-06-04 — Commit 3ee2aaa

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 82576 | 12.11 |
| schedule_isWithin_5_entries | 77579 | 12.89 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 462962 | 2.16 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 91743 | 10.90 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 421940 | 2.37 |
| config_toMap | 125786 | 7.95 |
| config_roundtrip | 97087 | 10.30 |
| state_fromMap | 406504 | 2.46 |
| state_toMap | 120336 | 8.31 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21645 | 46.20 |
| http_config_ssl_toMap | 735294 | 1.36 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 591715 | 1.69 |
| smart_motion_speed_change | 20874649 | 0.05 |
| battery_budget_single_sample | 22031713 | 0.05 |
| battery_budget_heavy_drain | 649512 | 1.54 |
| battery_budget_60_samples | 1239186 | 0.81 |
| smart_motion_accel_change | 22164333 | 0.05 |


### 2026-06-04 — Commit cbe3477

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 92936 | 10.76 |
| schedule_isWithin_5_entries | 84388 | 11.85 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 653594 | 1.53 |
| location_fromMap_toMap_roundtrip | 462962 | 2.16 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 92165 | 10.85 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2631578 | 0.38 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 448430 | 2.23 |
| config_toMap | 125944 | 7.94 |
| config_roundtrip | 97181 | 10.29 |
| state_fromMap | 420168 | 2.38 |
| state_toMap | 119904 | 8.34 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22563 | 44.32 |
| http_config_ssl_toMap | 719424 | 1.39 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 598802 | 1.67 |
| smart_motion_speed_change | 23492252 | 0.04 |
| smart_motion_accel_change | 23357250 | 0.04 |
| battery_budget_heavy_drain | 667255 | 1.50 |
| battery_budget_single_sample | 23780860 | 0.04 |
| battery_budget_60_samples | 1307062 | 0.77 |


### 2026-06-04 — Commit 697f6bd

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 84388 | 11.85 |
| schedule_isWithin_5_entries | 75872 | 13.18 |
| location_fromMap | 1612903 | 0.62 |
| location_toMap | 606060 | 1.65 |
| location_fromMap_toMap_roundtrip | 446428 | 2.24 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 90826 | 11.01 |
| carbon_onLocation | 3703703 | 0.27 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2380952 | 0.42 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 436681 | 2.29 |
| config_toMap | 119760 | 8.35 |
| config_roundtrip | 93370 | 10.71 |
| state_fromMap | 416666 | 2.40 |
| state_toMap | 115207 | 8.68 |
| route_context_toMap | 2857142 | 0.35 |
| route_context_fromMap | 2127659 | 0.47 |
| route_context_roundtrip | 1298701 | 0.77 |
| sync_body_context_toMap_50 | 7142857 | 0.14 |
| sync_body_context_fromMap_50 | 21376 | 46.78 |
| http_config_ssl_toMap | 724637 | 1.38 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 581395 | 1.72 |
| battery_budget_60_samples | 1232882 | 0.81 |
| battery_budget_heavy_drain | 652211 | 1.53 |
| smart_motion_accel_change | 22140630 | 0.05 |
| smart_motion_speed_change | 21992822 | 0.05 |
| battery_budget_single_sample | 22028154 | 0.05 |


### 2026-06-04 — Commit 5db2d32

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 90415 | 11.06 |
| schedule_isWithin_5_entries | 83263 | 12.01 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 467289 | 2.14 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 90497 | 11.05 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 434782 | 2.30 |
| config_toMap | 124223 | 8.05 |
| config_roundtrip | 95419 | 10.48 |
| state_fromMap | 413223 | 2.42 |
| state_toMap | 117924 | 8.48 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21997 | 45.46 |
| http_config_ssl_toMap | 729927 | 1.37 |
| http_config_ssl_fromMap | 2777777 | 0.36 |
| http_config_ssl_roundtrip | 591715 | 1.69 |
| battery_budget_single_sample | 23583964 | 0.04 |
| battery_budget_heavy_drain | 663131 | 1.51 |
| smart_motion_accel_change | 23703589 | 0.04 |
| smart_motion_speed_change | 23319073 | 0.04 |
| battery_budget_60_samples | 1285578 | 0.78 |


### 2026-06-04 — Commit eb6e76b

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 84745 | 11.80 |
| schedule_isWithin_5_entries | 77279 | 12.94 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 628930 | 1.59 |
| location_fromMap_toMap_roundtrip | 460829 | 2.17 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1515151 | 0.66 |
| carbon_trip_100_locations | 91996 | 10.87 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 423728 | 2.36 |
| config_toMap | 127388 | 7.85 |
| config_roundtrip | 96805 | 10.33 |
| state_fromMap | 398406 | 2.51 |
| state_toMap | 119047 | 8.40 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21853 | 45.76 |
| http_config_ssl_toMap | 740740 | 1.35 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 598802 | 1.67 |
| battery_budget_60_samples | 1290160 | 0.78 |
| smart_motion_accel_change | 22067074 | 0.05 |
| battery_budget_single_sample | 21865912 | 0.05 |
| battery_budget_heavy_drain | 664451 | 1.51 |
| smart_motion_speed_change | 21732891 | 0.05 |


### 2026-06-04 — Commit 6cf2b0f

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 3571428 | 0.28 |
| schedule_matches | 110987 | 9.01 |
| schedule_isWithin_5_entries | 99502 | 10.05 |
| location_fromMap | 2173913 | 0.46 |
| location_toMap | 847457 | 1.18 |
| location_fromMap_toMap_roundtrip | 609756 | 1.64 |
| location_copyWithCoords | 14285714 | 0.07 |
| geofence_fromMap_circular | 5555555 | 0.18 |
| geofence_fromMap_polygon | 2040816 | 0.49 |
| carbon_trip_100_locations | 118764 | 8.42 |
| carbon_onLocation | 5263157 | 0.19 |
| carbon_setActivity | 11111111 | 0.09 |
| carbon_cumulative_report | 3225806 | 0.31 |
| persist_decider_location | 25000000 | 0.04 |
| persist_decider_geofence | 25000000 | 0.04 |
| config_fromMap | 571428 | 1.75 |
| config_toMap | 161550 | 6.19 |
| config_roundtrip | 125944 | 7.94 |
| state_fromMap | 540540 | 1.85 |
| state_toMap | 155038 | 6.45 |
| route_context_toMap | 3846153 | 0.26 |
| route_context_fromMap | 2857142 | 0.35 |
| route_context_roundtrip | 1754385 | 0.57 |
| sync_body_context_toMap_50 | 10000000 | 0.10 |
| sync_body_context_fromMap_50 | 28034 | 35.67 |
| http_config_ssl_toMap | 952380 | 1.05 |
| http_config_ssl_fromMap | 3571428 | 0.28 |
| http_config_ssl_roundtrip | 763358 | 1.31 |
| battery_budget_60_samples | 1662316 | 0.60 |
| battery_budget_heavy_drain | 850780 | 1.18 |
| battery_budget_single_sample | 28187500 | 0.04 |
| smart_motion_speed_change | 28239931 | 0.04 |
| smart_motion_accel_change | 28498690 | 0.04 |


### 2026-06-04 — Commit d923aad

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 85689 | 11.67 |
| schedule_isWithin_5_entries | 77700 | 12.87 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 476190 | 2.10 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 91074 | 10.98 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 440528 | 2.27 |
| config_toMap | 126582 | 7.90 |
| config_roundtrip | 97656 | 10.24 |
| state_fromMap | 413223 | 2.42 |
| state_toMap | 120336 | 8.31 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 22002 | 45.45 |
| http_config_ssl_toMap | 735294 | 1.36 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 598802 | 1.67 |
| battery_budget_single_sample | 21862145 | 0.05 |
| smart_motion_speed_change | 21919105 | 0.05 |
| battery_budget_heavy_drain | 664039 | 1.51 |
| smart_motion_accel_change | 22063229 | 0.05 |
| battery_budget_60_samples | 1290760 | 0.77 |


### 2026-06-04 — Commit 04de295

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 83333 | 12.00 |
| schedule_isWithin_5_entries | 76452 | 13.08 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 465116 | 2.15 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 88967 | 11.24 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 434782 | 2.30 |
| config_toMap | 125944 | 7.94 |
| config_roundtrip | 95510 | 10.47 |
| state_fromMap | 408163 | 2.45 |
| state_toMap | 117924 | 8.48 |
| route_context_toMap | 2857142 | 0.35 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1315789 | 0.76 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21303 | 46.94 |
| http_config_ssl_toMap | 719424 | 1.39 |
| http_config_ssl_fromMap | 2777777 | 0.36 |
| http_config_ssl_roundtrip | 591715 | 1.69 |
| battery_budget_60_samples | 1290375 | 0.77 |
| battery_budget_single_sample | 21864195 | 0.05 |
| smart_motion_speed_change | 21742457 | 0.05 |
| battery_budget_heavy_drain | 664655 | 1.50 |
| smart_motion_accel_change | 22053051 | 0.05 |


### 2026-06-04 — Commit 3304c3b

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 3125000 | 0.32 |
| schedule_matches | 147710 | 6.77 |
| schedule_isWithin_5_entries | 122850 | 8.14 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 632911 | 1.58 |
| location_fromMap_toMap_roundtrip | 469483 | 2.13 |
| location_copyWithCoords | 12500000 | 0.08 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1694915 | 0.59 |
| carbon_trip_100_locations | 113122 | 8.84 |
| carbon_onLocation | 4347826 | 0.23 |
| carbon_setActivity | 10000000 | 0.10 |
| carbon_cumulative_report | 2702702 | 0.37 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 462962 | 2.16 |
| config_toMap | 132275 | 7.56 |
| config_roundtrip | 103519 | 9.66 |
| state_fromMap | 442477 | 2.26 |
| state_toMap | 127064 | 7.87 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2380952 | 0.42 |
| route_context_roundtrip | 1408450 | 0.71 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 23191 | 43.12 |
| http_config_ssl_toMap | 763358 | 1.31 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 613496 | 1.63 |
| battery_budget_heavy_drain | 425235 | 2.35 |
| battery_budget_single_sample | 24171611 | 0.04 |
| smart_motion_accel_change | 17288880 | 0.06 |
| smart_motion_speed_change | 17437308 | 0.06 |
| battery_budget_60_samples | 835123 | 1.20 |


### 2026-06-04 — Commit 68b5b52

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 84817 | 11.79 |
| schedule_isWithin_5_entries | 77101 | 12.97 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 471698 | 2.12 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 91659 | 10.91 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 444444 | 2.25 |
| config_toMap | 126582 | 7.90 |
| config_roundtrip | 97943 | 10.21 |
| state_fromMap | 416666 | 2.40 |
| state_toMap | 121951 | 8.20 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1282051 | 0.78 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21767 | 45.94 |
| http_config_ssl_toMap | 769230 | 1.30 |
| http_config_ssl_fromMap | 3125000 | 0.32 |
| http_config_ssl_roundtrip | 628930 | 1.59 |
| smart_motion_speed_change | 22546892 | 0.04 |
| battery_budget_single_sample | 22713223 | 0.04 |
| battery_budget_60_samples | 1344800 | 0.74 |
| smart_motion_accel_change | 22908979 | 0.04 |
| battery_budget_heavy_drain | 683418 | 1.46 |


### 2026-06-03 — Commit 4b74b66

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 81967 | 12.20 |
| schedule_isWithin_5_entries | 76628 | 13.05 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 636942 | 1.57 |
| location_fromMap_toMap_roundtrip | 454545 | 2.20 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1515151 | 0.66 |
| carbon_trip_100_locations | 89285 | 11.20 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 444444 | 2.25 |
| config_toMap | 125628 | 7.96 |
| config_roundtrip | 98135 | 10.19 |
| state_fromMap | 423728 | 2.36 |
| state_toMap | 120772 | 8.28 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21729 | 46.02 |
| http_config_ssl_toMap | 775193 | 1.29 |
| http_config_ssl_fromMap | 3030303 | 0.33 |
| http_config_ssl_roundtrip | 628930 | 1.59 |
| battery_budget_heavy_drain | 690810 | 1.45 |
| smart_motion_accel_change | 22873502 | 0.04 |
| battery_budget_60_samples | 1341815 | 0.75 |
| smart_motion_speed_change | 22561278 | 0.04 |
| battery_budget_single_sample | 22744506 | 0.04 |


### 2026-06-03 — Commit 9584c52

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 85543 | 11.69 |
| schedule_isWithin_5_entries | 77579 | 12.89 |
| location_fromMap | 1612903 | 0.62 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 465116 | 2.15 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 91407 | 10.94 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 446428 | 2.24 |
| config_toMap | 127064 | 7.87 |
| config_roundtrip | 98231 | 10.18 |
| state_fromMap | 420168 | 2.38 |
| state_toMap | 122850 | 8.14 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21862 | 45.74 |
| http_config_ssl_toMap | 757575 | 1.32 |
| http_config_ssl_fromMap | 3030303 | 0.33 |
| http_config_ssl_roundtrip | 621118 | 1.61 |
| smart_motion_accel_change | 22920959 | 0.04 |
| battery_budget_heavy_drain | 690677 | 1.45 |
| smart_motion_speed_change | 22546553 | 0.04 |
| battery_budget_60_samples | 1340120 | 0.75 |
| battery_budget_single_sample | 22693307 | 0.04 |


### 2026-06-03 — Commit 38a54e0

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 82781 | 12.08 |
| schedule_isWithin_5_entries | 76045 | 13.15 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 467289 | 2.14 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 89686 | 11.15 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 420168 | 2.38 |
| config_toMap | 126742 | 7.89 |
| config_roundtrip | 97181 | 10.29 |
| state_fromMap | 403225 | 2.48 |
| state_toMap | 121359 | 8.24 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21810 | 45.85 |
| http_config_ssl_toMap | 775193 | 1.29 |
| http_config_ssl_fromMap | 3030303 | 0.33 |
| http_config_ssl_roundtrip | 632911 | 1.58 |
| battery_budget_single_sample | 22732115 | 0.04 |
| smart_motion_accel_change | 22755555 | 0.04 |
| battery_budget_60_samples | 1339952 | 0.75 |
| battery_budget_heavy_drain | 678901 | 1.47 |
| smart_motion_speed_change | 22421312 | 0.04 |


### 2026-06-03 — Commit 4bfb6f3

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 84175 | 11.88 |
| schedule_isWithin_5_entries | 76511 | 13.07 |
| location_fromMap | 1612903 | 0.62 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 469483 | 2.13 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 89206 | 11.21 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 450450 | 2.22 |
| config_toMap | 127877 | 7.82 |
| config_roundtrip | 97656 | 10.24 |
| state_fromMap | 420168 | 2.38 |
| state_toMap | 123001 | 8.13 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21795 | 45.88 |
| http_config_ssl_toMap | 769230 | 1.30 |
| http_config_ssl_fromMap | 3030303 | 0.33 |
| http_config_ssl_roundtrip | 625000 | 1.60 |
| battery_budget_60_samples | 1339144 | 0.75 |
| smart_motion_accel_change | 22922922 | 0.04 |
| smart_motion_speed_change | 22529791 | 0.04 |
| battery_budget_single_sample | 22678992 | 0.04 |
| battery_budget_heavy_drain | 690657 | 1.45 |


### 2026-06-03 — Commit 793cd93

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 87719 | 11.40 |
| schedule_isWithin_5_entries | 81103 | 12.33 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 625000 | 1.60 |
| location_fromMap_toMap_roundtrip | 450450 | 2.22 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1515151 | 0.66 |
| carbon_trip_100_locations | 88731 | 11.27 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 436681 | 2.29 |
| config_toMap | 126422 | 7.91 |
| config_roundtrip | 97370 | 10.27 |
| state_fromMap | 418410 | 2.39 |
| state_toMap | 120627 | 8.29 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 21588 | 46.32 |
| http_config_ssl_toMap | 757575 | 1.32 |
| http_config_ssl_fromMap | 3125000 | 0.32 |
| http_config_ssl_roundtrip | 625000 | 1.60 |
| smart_motion_accel_change | 24482985 | 0.04 |
| smart_motion_speed_change | 24138490 | 0.04 |
| battery_budget_60_samples | 1389721 | 0.72 |
| battery_budget_single_sample | 24122379 | 0.04 |
| battery_budget_heavy_drain | 719928 | 1.39 |


### 2026-06-03 — Commit b8445a8

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 90579 | 11.04 |
| schedule_isWithin_5_entries | 82781 | 12.08 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 628930 | 1.59 |
| location_fromMap_toMap_roundtrip | 471698 | 2.12 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 91575 | 10.92 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2439024 | 0.41 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 432900 | 2.31 |
| config_toMap | 124223 | 8.05 |
| config_roundtrip | 95969 | 10.42 |
| state_fromMap | 404858 | 2.47 |
| state_toMap | 120627 | 8.29 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 21992 | 45.47 |
| http_config_ssl_toMap | 769230 | 1.30 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 641025 | 1.56 |
| battery_budget_heavy_drain | 722323 | 1.38 |
| smart_motion_speed_change | 24160573 | 0.04 |
| battery_budget_60_samples | 1393973 | 0.72 |
| battery_budget_single_sample | 24210896 | 0.04 |
| smart_motion_accel_change | 24514557 | 0.04 |


### 2026-06-03 — Commit 978810b

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 84175 | 11.88 |
| schedule_isWithin_5_entries | 76335 | 13.10 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 636942 | 1.57 |
| location_fromMap_toMap_roundtrip | 471698 | 2.12 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 91743 | 10.90 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 452488 | 2.21 |
| config_toMap | 127551 | 7.84 |
| config_roundtrip | 99403 | 10.06 |
| state_fromMap | 431034 | 2.32 |
| state_toMap | 120627 | 8.29 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21939 | 45.58 |
| http_config_ssl_toMap | 793650 | 1.26 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 645161 | 1.55 |
| battery_budget_60_samples | 1339178 | 0.75 |
| battery_budget_single_sample | 22741246 | 0.04 |
| battery_budget_heavy_drain | 691979 | 1.45 |
| smart_motion_accel_change | 22923391 | 0.04 |
| smart_motion_speed_change | 22554257 | 0.04 |


### 2026-06-03 — Commit cb7d5b3

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 90497 | 11.05 |
| schedule_isWithin_5_entries | 82644 | 12.10 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 657894 | 1.52 |
| location_fromMap_toMap_roundtrip | 471698 | 2.12 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 89206 | 11.21 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 448430 | 2.23 |
| config_toMap | 127388 | 7.85 |
| config_roundtrip | 99304 | 10.07 |
| state_fromMap | 420168 | 2.38 |
| state_toMap | 123001 | 8.13 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22050 | 45.35 |
| http_config_ssl_toMap | 787401 | 1.27 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 628930 | 1.59 |
| battery_budget_heavy_drain | 724109 | 1.38 |
| smart_motion_speed_change | 24136491 | 0.04 |
| battery_budget_60_samples | 1391350 | 0.72 |
| smart_motion_accel_change | 24476246 | 0.04 |
| battery_budget_single_sample | 24202081 | 0.04 |


### 2026-06-03 — Commit fadfb64

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 85106 | 11.75 |
| schedule_isWithin_5_entries | 77160 | 12.96 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 467289 | 2.14 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1612903 | 0.62 |
| carbon_trip_100_locations | 90579 | 11.04 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 452488 | 2.21 |
| config_toMap | 128040 | 7.81 |
| config_roundtrip | 99304 | 10.07 |
| state_fromMap | 429184 | 2.33 |
| state_toMap | 121359 | 8.24 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21640 | 46.21 |
| http_config_ssl_toMap | 787401 | 1.27 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 649350 | 1.54 |
| battery_budget_single_sample | 22720578 | 0.04 |
| smart_motion_accel_change | 22914057 | 0.04 |
| smart_motion_speed_change | 22546826 | 0.04 |
| battery_budget_60_samples | 1339535 | 0.75 |
| battery_budget_heavy_drain | 690716 | 1.45 |


### 2026-06-03 — Commit 92f73cb

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 91240 | 10.96 |
| schedule_isWithin_5_entries | 83333 | 12.00 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 653594 | 1.53 |
| location_fromMap_toMap_roundtrip | 473933 | 2.11 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 93896 | 10.65 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 465116 | 2.15 |
| config_toMap | 128534 | 7.78 |
| config_roundtrip | 101214 | 9.88 |
| state_fromMap | 440528 | 2.27 |
| state_toMap | 122699 | 8.15 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1388888 | 0.72 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22311 | 44.82 |
| http_config_ssl_toMap | 775193 | 1.29 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 632911 | 1.58 |
| battery_budget_single_sample | 24233086 | 0.04 |
| battery_budget_60_samples | 1392730 | 0.72 |
| battery_budget_heavy_drain | 724366 | 1.38 |
| smart_motion_accel_change | 24411407 | 0.04 |
| smart_motion_speed_change | 24151193 | 0.04 |


### 2026-06-03 — Commit cc7d028

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 89445 | 11.18 |
| schedule_isWithin_5_entries | 82781 | 12.08 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 636942 | 1.57 |
| location_fromMap_toMap_roundtrip | 465116 | 2.15 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 92336 | 10.83 |
| carbon_onLocation | 3846153 | 0.26 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2439024 | 0.41 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 458715 | 2.18 |
| config_toMap | 125628 | 7.96 |
| config_roundtrip | 98425 | 10.16 |
| state_fromMap | 440528 | 2.27 |
| state_toMap | 119331 | 8.38 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21896 | 45.67 |
| http_config_ssl_toMap | 763358 | 1.31 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 636942 | 1.57 |
| battery_budget_single_sample | 24184137 | 0.04 |
| battery_budget_heavy_drain | 723819 | 1.38 |
| battery_budget_60_samples | 1387621 | 0.72 |
| smart_motion_accel_change | 24469927 | 0.04 |
| smart_motion_speed_change | 24149475 | 0.04 |


### 2026-06-03 — Commit 493b061

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 83612 | 11.96 |
| schedule_isWithin_5_entries | 76863 | 13.01 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 469483 | 2.13 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 91407 | 10.94 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 446428 | 2.24 |
| config_toMap | 126582 | 7.90 |
| config_roundtrip | 98425 | 10.16 |
| state_fromMap | 418410 | 2.39 |
| state_toMap | 122399 | 8.17 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21886 | 45.69 |
| http_config_ssl_toMap | 781250 | 1.28 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 641025 | 1.56 |
| smart_motion_accel_change | 22897507 | 0.04 |
| smart_motion_speed_change | 22549116 | 0.04 |
| battery_budget_single_sample | 22703080 | 0.04 |
| battery_budget_heavy_drain | 689382 | 1.45 |
| battery_budget_60_samples | 1340340 | 0.75 |


### 2026-06-03 — Commit 2b32cc5

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 84817 | 11.79 |
| schedule_isWithin_5_entries | 77821 | 12.85 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 467289 | 2.14 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 91491 | 10.93 |
| carbon_onLocation | 3846153 | 0.26 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 446428 | 2.24 |
| config_toMap | 127713 | 7.83 |
| config_roundtrip | 99108 | 10.09 |
| state_fromMap | 420168 | 2.38 |
| state_toMap | 122699 | 8.15 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1315789 | 0.76 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21958 | 45.54 |
| http_config_ssl_toMap | 787401 | 1.27 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 645161 | 1.55 |
| battery_budget_heavy_drain | 690120 | 1.45 |
| battery_budget_single_sample | 22747373 | 0.04 |
| smart_motion_speed_change | 22566696 | 0.04 |
| battery_budget_60_samples | 1340956 | 0.75 |
| smart_motion_accel_change | 22923647 | 0.04 |


### 2026-06-03 — Commit 6e6e9dd

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 89445 | 11.18 |
| schedule_isWithin_5_entries | 83752 | 11.94 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 641025 | 1.56 |
| location_fromMap_toMap_roundtrip | 465116 | 2.15 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 91157 | 10.97 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 471698 | 2.12 |
| config_toMap | 123762 | 8.08 |
| config_roundtrip | 97847 | 10.22 |
| state_fromMap | 438596 | 2.28 |
| state_toMap | 118343 | 8.45 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21910 | 45.64 |
| http_config_ssl_toMap | 757575 | 1.32 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 625000 | 1.60 |
| battery_budget_single_sample | 24228968 | 0.04 |
| battery_budget_60_samples | 1365499 | 0.73 |
| battery_budget_heavy_drain | 716751 | 1.40 |
| smart_motion_accel_change | 24502927 | 0.04 |
| smart_motion_speed_change | 24120967 | 0.04 |


### 2026-06-03 — Commit 1c28915

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 3030303 | 0.33 |
| schedule_matches | 144508 | 6.92 |
| schedule_isWithin_5_entries | 122399 | 8.17 |
| location_fromMap | 1538461 | 0.65 |
| location_toMap | 641025 | 1.56 |
| location_fromMap_toMap_roundtrip | 454545 | 2.20 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4166666 | 0.24 |
| geofence_fromMap_polygon | 1428571 | 0.70 |
| carbon_trip_100_locations | 107991 | 9.26 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 10000000 | 0.10 |
| carbon_cumulative_report | 2631578 | 0.38 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 487804 | 2.05 |
| config_toMap | 132802 | 7.53 |
| config_roundtrip | 102986 | 9.71 |
| state_fromMap | 454545 | 2.20 |
| state_toMap | 127226 | 7.86 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 1886792 | 0.53 |
| route_context_roundtrip | 1162790 | 0.86 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22153 | 45.14 |
| http_config_ssl_toMap | 793650 | 1.26 |
| http_config_ssl_fromMap | 3125000 | 0.32 |
| http_config_ssl_roundtrip | 641025 | 1.56 |
| battery_budget_60_samples | 854199 | 1.17 |
| battery_budget_single_sample | 24210728 | 0.04 |
| smart_motion_speed_change | 17126193 | 0.06 |
| smart_motion_accel_change | 17417358 | 0.06 |
| battery_budget_heavy_drain | 434830 | 2.30 |


### 2026-06-02 — Commit 4595d6e

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 84175 | 11.88 |
| schedule_isWithin_5_entries | 76863 | 13.01 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 473933 | 2.11 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 91491 | 10.93 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 448430 | 2.23 |
| config_toMap | 127064 | 7.87 |
| config_roundtrip | 98522 | 10.15 |
| state_fromMap | 420168 | 2.38 |
| state_toMap | 121802 | 8.21 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21523 | 46.46 |
| http_config_ssl_toMap | 787401 | 1.27 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 645161 | 1.55 |
| smart_motion_speed_change | 22556940 | 0.04 |
| battery_budget_heavy_drain | 690590 | 1.45 |
| battery_budget_60_samples | 1340590 | 0.75 |
| smart_motion_accel_change | 22921213 | 0.04 |
| battery_budget_single_sample | 22735608 | 0.04 |


### 2026-06-02 — Commit a63a23e

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 84674 | 11.81 |
| schedule_isWithin_5_entries | 77101 | 12.97 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 444444 | 2.25 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 91074 | 10.98 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 460829 | 2.17 |
| config_toMap | 127226 | 7.86 |
| config_roundtrip | 98814 | 10.12 |
| state_fromMap | 434782 | 2.30 |
| state_toMap | 121506 | 8.23 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1298701 | 0.77 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21772 | 45.93 |
| http_config_ssl_toMap | 775193 | 1.29 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 636942 | 1.57 |
| smart_motion_speed_change | 22568020 | 0.04 |
| battery_budget_single_sample | 22739484 | 0.04 |
| battery_budget_60_samples | 1341740 | 0.75 |
| smart_motion_accel_change | 22932869 | 0.04 |
| battery_budget_heavy_drain | 690814 | 1.45 |


### 2026-06-02 — Commit b53b7cb

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 83542 | 11.97 |
| schedule_isWithin_5_entries | 77160 | 12.96 |
| location_fromMap | 1612903 | 0.62 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 465116 | 2.15 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 89686 | 11.15 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 454545 | 2.20 |
| config_toMap | 128040 | 7.81 |
| config_roundtrip | 99900 | 10.01 |
| state_fromMap | 425531 | 2.35 |
| state_toMap | 122699 | 8.15 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 22128 | 45.19 |
| http_config_ssl_toMap | 787401 | 1.27 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 657894 | 1.52 |
| battery_budget_single_sample | 22736071 | 0.04 |
| smart_motion_accel_change | 22913245 | 0.04 |
| battery_budget_60_samples | 1339908 | 0.75 |
| smart_motion_speed_change | 22555022 | 0.04 |
| battery_budget_heavy_drain | 690855 | 1.45 |


### 2026-06-02 — Commit 82c6ef4

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 84388 | 11.85 |
| schedule_isWithin_5_entries | 77041 | 12.98 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 613496 | 1.63 |
| location_fromMap_toMap_roundtrip | 467289 | 2.14 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 90497 | 11.05 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2439024 | 0.41 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 450450 | 2.22 |
| config_toMap | 124688 | 8.02 |
| config_roundtrip | 95238 | 10.50 |
| state_fromMap | 396825 | 2.52 |
| state_toMap | 119189 | 8.39 |
| route_context_toMap | 2702702 | 0.37 |
| route_context_fromMap | 2083333 | 0.48 |
| route_context_roundtrip | 1298701 | 0.77 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21468 | 46.58 |
| http_config_ssl_toMap | 740740 | 1.35 |
| http_config_ssl_fromMap | 3125000 | 0.32 |
| http_config_ssl_roundtrip | 609756 | 1.64 |
| battery_budget_heavy_drain | 694329 | 1.44 |
| smart_motion_speed_change | 22517032 | 0.04 |
| battery_budget_single_sample | 22733557 | 0.04 |
| battery_budget_60_samples | 1347252 | 0.74 |
| smart_motion_accel_change | 22085898 | 0.05 |


### 2026-06-02 — Commit 99f0f81

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 3571428 | 0.28 |
| schedule_matches | 110011 | 9.09 |
| schedule_isWithin_5_entries | 99502 | 10.05 |
| location_fromMap | 2083333 | 0.48 |
| location_toMap | 819672 | 1.22 |
| location_fromMap_toMap_roundtrip | 595238 | 1.68 |
| location_copyWithCoords | 12500000 | 0.08 |
| geofence_fromMap_circular | 5555555 | 0.18 |
| geofence_fromMap_polygon | 2000000 | 0.50 |
| carbon_trip_100_locations | 117233 | 8.53 |
| carbon_onLocation | 5000000 | 0.20 |
| carbon_setActivity | 11111111 | 0.09 |
| carbon_cumulative_report | 3225806 | 0.31 |
| persist_decider_location | 25000000 | 0.04 |
| persist_decider_geofence | 25000000 | 0.04 |
| config_fromMap | 588235 | 1.70 |
| config_toMap | 162337 | 6.16 |
| config_roundtrip | 129032 | 7.75 |
| state_fromMap | 555555 | 1.80 |
| state_toMap | 159235 | 6.28 |
| route_context_toMap | 3703703 | 0.27 |
| route_context_fromMap | 2857142 | 0.35 |
| route_context_roundtrip | 1724137 | 0.58 |
| sync_body_context_toMap_50 | 10000000 | 0.10 |
| sync_body_context_fromMap_50 | 28264 | 35.38 |
| http_config_ssl_toMap | 1000000 | 1.00 |
| http_config_ssl_fromMap | 4000000 | 0.25 |
| http_config_ssl_roundtrip | 819672 | 1.22 |
| battery_budget_single_sample | 29283981 | 0.03 |
| smart_motion_speed_change | 29075160 | 0.03 |
| battery_budget_heavy_drain | 889434 | 1.12 |
| smart_motion_accel_change | 29545413 | 0.03 |
| battery_budget_60_samples | 1726881 | 0.58 |


### 2026-06-02 — Commit 67e5c2c

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 94339 | 10.60 |
| schedule_isWithin_5_entries | 84602 | 11.82 |
| location_fromMap | 1724137 | 0.58 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 476190 | 2.10 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 93023 | 10.75 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 460829 | 2.17 |
| config_toMap | 127064 | 7.87 |
| config_roundtrip | 98425 | 10.16 |
| state_fromMap | 434782 | 2.30 |
| state_toMap | 122100 | 8.19 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22502 | 44.44 |
| http_config_ssl_toMap | 769230 | 1.30 |
| http_config_ssl_fromMap | 3333333 | 0.30 |
| http_config_ssl_roundtrip | 653594 | 1.53 |
| battery_budget_single_sample | 24127109 | 0.04 |
| smart_motion_speed_change | 24088285 | 0.04 |
| battery_budget_60_samples | 1385319 | 0.72 |
| battery_budget_heavy_drain | 719409 | 1.39 |
| smart_motion_accel_change | 24469909 | 0.04 |


### 2026-06-02 — Commit 85f5786

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 83963 | 11.91 |
| schedule_isWithin_5_entries | 77339 | 12.93 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 458715 | 2.18 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 89525 | 11.17 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 458715 | 2.18 |
| config_toMap | 128534 | 7.78 |
| config_roundtrip | 99009 | 10.10 |
| state_fromMap | 429184 | 2.33 |
| state_toMap | 120772 | 8.28 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21579 | 46.34 |
| http_config_ssl_toMap | 781250 | 1.28 |
| http_config_ssl_fromMap | 3030303 | 0.33 |
| http_config_ssl_roundtrip | 632911 | 1.58 |
| battery_budget_60_samples | 1343210 | 0.74 |
| smart_motion_speed_change | 22464156 | 0.04 |
| smart_motion_accel_change | 22901985 | 0.04 |
| battery_budget_heavy_drain | 686376 | 1.46 |
| battery_budget_single_sample | 22728777 | 0.04 |


