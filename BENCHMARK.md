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

### 2026-05-29 — Commit 403ebc0

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 84674 | 11.81 |
| schedule_isWithin_5_entries | 76161 | 13.13 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 653594 | 1.53 |
| location_fromMap_toMap_roundtrip | 471698 | 2.12 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4761904 | 0.21 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 91659 | 10.91 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 471698 | 2.12 |
| config_toMap | 127877 | 7.82 |
| config_roundtrip | 100000 | 10.00 |
| state_fromMap | 440528 | 2.27 |
| state_toMap | 123001 | 8.13 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1388888 | 0.72 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22456 | 44.53 |
| http_config_ssl_toMap | 769230 | 1.30 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 632911 | 1.58 |
| battery_budget_single_sample | 21752956 | 0.05 |
| battery_budget_heavy_drain | 561596 | 1.78 |
| battery_budget_60_samples | 1090736 | 0.92 |
| smart_motion_accel_change | 17941321 | 0.06 |
| smart_motion_speed_change | 17845331 | 0.06 |


### 2026-05-29 — Commit 1204f75

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 85470 | 11.70 |
| schedule_isWithin_5_entries | 74906 | 13.35 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 628930 | 1.59 |
| location_fromMap_toMap_roundtrip | 465116 | 2.15 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 92764 | 10.78 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 469483 | 2.13 |
| config_toMap | 123915 | 8.07 |
| config_roundtrip | 96899 | 10.32 |
| state_fromMap | 442477 | 2.26 |
| state_toMap | 118343 | 8.45 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22222 | 45.00 |
| http_config_ssl_toMap | 769230 | 1.30 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 632911 | 1.58 |
| battery_budget_60_samples | 1089574 | 0.92 |
| battery_budget_single_sample | 21736372 | 0.05 |
| smart_motion_accel_change | 19033109 | 0.05 |
| smart_motion_speed_change | 17877424 | 0.06 |
| battery_budget_heavy_drain | 561615 | 1.78 |


### 2026-05-29 — Commit db73966

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 3030303 | 0.33 |
| schedule_matches | 135869 | 7.36 |
| schedule_isWithin_5_entries | 111111 | 9.00 |
| location_fromMap | 1724137 | 0.58 |
| location_toMap | 662251 | 1.51 |
| location_fromMap_toMap_roundtrip | 483091 | 2.07 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4761904 | 0.21 |
| geofence_fromMap_polygon | 1724137 | 0.58 |
| carbon_trip_100_locations | 111358 | 8.98 |
| carbon_onLocation | 4545454 | 0.22 |
| carbon_setActivity | 10000000 | 0.10 |
| carbon_cumulative_report | 2702702 | 0.37 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 480769 | 2.08 |
| config_toMap | 132275 | 7.56 |
| config_roundtrip | 103626 | 9.65 |
| state_fromMap | 448430 | 2.23 |
| state_toMap | 127226 | 7.86 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1408450 | 0.71 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22799 | 43.86 |
| http_config_ssl_toMap | 806451 | 1.24 |
| http_config_ssl_fromMap | 3333333 | 0.30 |
| http_config_ssl_roundtrip | 671140 | 1.49 |
| battery_budget_single_sample | 21971227 | 0.05 |
| smart_motion_speed_change | 16058478 | 0.06 |
| battery_budget_heavy_drain | 386723 | 2.59 |
| smart_motion_accel_change | 16177902 | 0.06 |
| battery_budget_60_samples | 765772 | 1.31 |


### 2026-05-29 — Commit cd251e4

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 82372 | 12.14 |
| schedule_isWithin_5_entries | 72939 | 13.71 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 632911 | 1.58 |
| location_fromMap_toMap_roundtrip | 460829 | 2.17 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 92336 | 10.83 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 478468 | 2.09 |
| config_toMap | 126262 | 7.92 |
| config_roundtrip | 98231 | 10.18 |
| state_fromMap | 438596 | 2.28 |
| state_toMap | 121359 | 8.24 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 22065 | 45.32 |
| http_config_ssl_toMap | 757575 | 1.32 |
| http_config_ssl_fromMap | 3333333 | 0.30 |
| http_config_ssl_roundtrip | 636942 | 1.57 |
| smart_motion_speed_change | 17865894 | 0.06 |
| battery_budget_heavy_drain | 562011 | 1.78 |
| battery_budget_60_samples | 1094477 | 0.91 |
| smart_motion_accel_change | 19114083 | 0.05 |
| battery_budget_single_sample | 21742772 | 0.05 |


### 2026-05-29 — Commit 6b23fe9

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 84104 | 11.89 |
| schedule_isWithin_5_entries | 73583 | 13.59 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 625000 | 1.60 |
| location_fromMap_toMap_roundtrip | 462962 | 2.16 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 87183 | 11.47 |
| carbon_onLocation | 3846153 | 0.26 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 450450 | 2.22 |
| config_toMap | 124533 | 8.03 |
| config_roundtrip | 98039 | 10.20 |
| state_fromMap | 427350 | 2.34 |
| state_toMap | 119760 | 8.35 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21593 | 46.31 |
| http_config_ssl_toMap | 757575 | 1.32 |
| http_config_ssl_fromMap | 3333333 | 0.30 |
| http_config_ssl_roundtrip | 625000 | 1.60 |
| battery_budget_single_sample | 21725618 | 0.05 |
| battery_budget_60_samples | 1090672 | 0.92 |
| battery_budget_heavy_drain | 559930 | 1.79 |
| smart_motion_accel_change | 18785328 | 0.05 |
| smart_motion_speed_change | 17726244 | 0.06 |


### 2026-05-29 — Commit 165096e

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 78678 | 12.71 |
| schedule_isWithin_5_entries | 69637 | 14.36 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 636942 | 1.57 |
| location_fromMap_toMap_roundtrip | 448430 | 2.23 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1612903 | 0.62 |
| carbon_trip_100_locations | 90744 | 11.02 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 456621 | 2.19 |
| config_toMap | 125628 | 7.96 |
| config_roundtrip | 95877 | 10.43 |
| state_fromMap | 429184 | 2.33 |
| state_toMap | 118203 | 8.46 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2127659 | 0.47 |
| route_context_roundtrip | 1298701 | 0.77 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 20321 | 49.21 |
| http_config_ssl_toMap | 787401 | 1.27 |
| http_config_ssl_fromMap | 3125000 | 0.32 |
| http_config_ssl_roundtrip | 645161 | 1.55 |
| battery_budget_60_samples | 1130333 | 0.88 |
| battery_budget_heavy_drain | 581947 | 1.72 |
| smart_motion_speed_change | 18310271 | 0.05 |
| smart_motion_accel_change | 18954135 | 0.05 |
| battery_budget_single_sample | 19965791 | 0.05 |


### 2026-05-29 — Commit 27ef02b

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 85470 | 11.70 |
| schedule_isWithin_5_entries | 74850 | 13.36 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 628930 | 1.59 |
| location_fromMap_toMap_roundtrip | 456621 | 2.19 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4761904 | 0.21 |
| geofence_fromMap_polygon | 1492537 | 0.67 |
| carbon_trip_100_locations | 93457 | 10.70 |
| carbon_onLocation | 3846153 | 0.26 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 471698 | 2.12 |
| config_toMap | 127877 | 7.82 |
| config_roundtrip | 100603 | 9.94 |
| state_fromMap | 448430 | 2.23 |
| state_toMap | 120048 | 8.33 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21963 | 45.53 |
| http_config_ssl_toMap | 769230 | 1.30 |
| http_config_ssl_fromMap | 3333333 | 0.30 |
| http_config_ssl_roundtrip | 632911 | 1.58 |
| battery_budget_60_samples | 1091918 | 0.92 |
| smart_motion_accel_change | 18845475 | 0.05 |
| smart_motion_speed_change | 17841961 | 0.06 |
| battery_budget_single_sample | 21732934 | 0.05 |
| battery_budget_heavy_drain | 561882 | 1.78 |


### 2026-05-29 — Commit 24559ca

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2631578 | 0.38 |
| schedule_matches | 80580 | 12.41 |
| schedule_isWithin_5_entries | 70821 | 14.12 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 641025 | 1.56 |
| location_fromMap_toMap_roundtrip | 471698 | 2.12 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 90090 | 11.10 |
| carbon_onLocation | 3703703 | 0.27 |
| carbon_setActivity | 7692307 | 0.13 |
| carbon_cumulative_report | 2380952 | 0.42 |
| persist_decider_location | 16666666 | 0.06 |
| persist_decider_geofence | 16666666 | 0.06 |
| config_fromMap | 454545 | 2.20 |
| config_toMap | 127713 | 7.83 |
| config_roundtrip | 99700 | 10.03 |
| state_fromMap | 434782 | 2.30 |
| state_toMap | 122100 | 8.19 |
| route_context_toMap | 2857142 | 0.35 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 6666666 | 0.15 |
| sync_body_context_fromMap_50 | 21715 | 46.05 |
| http_config_ssl_toMap | 781250 | 1.28 |
| http_config_ssl_fromMap | 3125000 | 0.32 |
| http_config_ssl_roundtrip | 641025 | 1.56 |
| battery_budget_single_sample | 19988801 | 0.05 |
| battery_budget_60_samples | 1129547 | 0.89 |
| smart_motion_accel_change | 19404019 | 0.05 |
| battery_budget_heavy_drain | 582880 | 1.72 |
| smart_motion_speed_change | 18231357 | 0.05 |


### 2026-05-29 — Commit 80d65bf

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 3030303 | 0.33 |
| schedule_matches | 137741 | 7.26 |
| schedule_isWithin_5_entries | 109890 | 9.10 |
| location_fromMap | 1724137 | 0.58 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 476190 | 2.10 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1666666 | 0.60 |
| carbon_trip_100_locations | 111982 | 8.93 |
| carbon_onLocation | 4347826 | 0.23 |
| carbon_setActivity | 10000000 | 0.10 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 478468 | 2.09 |
| config_toMap | 134408 | 7.44 |
| config_roundtrip | 102669 | 9.74 |
| state_fromMap | 450450 | 2.22 |
| state_toMap | 128205 | 7.80 |
| route_context_toMap | 2857142 | 0.35 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22588 | 44.27 |
| http_config_ssl_toMap | 800000 | 1.25 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 657894 | 1.52 |
| battery_budget_single_sample | 21990775 | 0.05 |
| smart_motion_accel_change | 16156394 | 0.06 |
| battery_budget_60_samples | 766539 | 1.30 |
| battery_budget_heavy_drain | 387009 | 2.58 |
| smart_motion_speed_change | 16021329 | 0.06 |


### 2026-05-28 — Commit 82c66a7

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 84388 | 11.85 |
| schedule_isWithin_5_entries | 74349 | 13.45 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 632911 | 1.58 |
| location_fromMap_toMap_roundtrip | 456621 | 2.19 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 92850 | 10.77 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 469483 | 2.13 |
| config_toMap | 126903 | 7.88 |
| config_roundtrip | 97276 | 10.28 |
| state_fromMap | 440528 | 2.27 |
| state_toMap | 122100 | 8.19 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1388888 | 0.72 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 22177 | 45.09 |
| http_config_ssl_toMap | 763358 | 1.31 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 636942 | 1.57 |
| battery_budget_60_samples | 1017686 | 0.98 |
| battery_budget_heavy_drain | 518989 | 1.93 |
| smart_motion_accel_change | 18709473 | 0.05 |
| smart_motion_speed_change | 17682185 | 0.06 |
| battery_budget_single_sample | 21727469 | 0.05 |


