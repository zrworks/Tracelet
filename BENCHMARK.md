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


### 2026-05-27 — Commit 83ae482

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 84961 | 11.77 |
| schedule_isWithin_5_entries | 74019 | 13.51 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 471698 | 2.12 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 92764 | 10.78 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 454545 | 2.20 |
| config_toMap | 129701 | 7.71 |
| config_roundtrip | 98911 | 10.11 |
| state_fromMap | 425531 | 2.35 |
| state_toMap | 123304 | 8.11 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22381 | 44.68 |
| http_config_ssl_toMap | 787401 | 1.27 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 632911 | 1.58 |
| battery_budget_heavy_drain | 561642 | 1.78 |
| smart_motion_speed_change | 17681916 | 0.06 |
| battery_budget_60_samples | 1090011 | 0.92 |
| smart_motion_accel_change | 18681783 | 0.05 |
| battery_budget_single_sample | 21773297 | 0.05 |


### 2026-05-27 — Commit 57f99d8

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 80450 | 12.43 |
| schedule_isWithin_5_entries | 70077 | 14.27 |
| location_fromMap | 1408450 | 0.71 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 452488 | 2.21 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 89525 | 11.17 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 452488 | 2.21 |
| config_toMap | 127713 | 7.83 |
| config_roundtrip | 99206 | 10.08 |
| state_fromMap | 431034 | 2.32 |
| state_toMap | 123304 | 8.11 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21992 | 45.47 |
| http_config_ssl_toMap | 775193 | 1.29 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 641025 | 1.56 |
| battery_budget_heavy_drain | 579142 | 1.73 |
| smart_motion_accel_change | 19019184 | 0.05 |
| battery_budget_60_samples | 1127320 | 0.89 |
| smart_motion_speed_change | 18271556 | 0.05 |
| battery_budget_single_sample | 20008616 | 0.05 |


### 2026-05-27 — Commit 774358e

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 3571428 | 0.28 |
| schedule_matches | 104602 | 9.56 |
| schedule_isWithin_5_entries | 90909 | 11.00 |
| location_fromMap | 2173913 | 0.46 |
| location_toMap | 775193 | 1.29 |
| location_fromMap_toMap_roundtrip | 578034 | 1.73 |
| location_copyWithCoords | 14285714 | 0.07 |
| geofence_fromMap_circular | 5555555 | 0.18 |
| geofence_fromMap_polygon | 2000000 | 0.50 |
| carbon_trip_100_locations | 110864 | 9.02 |
| carbon_onLocation | 5000000 | 0.20 |
| carbon_setActivity | 11111111 | 0.09 |
| carbon_cumulative_report | 3030303 | 0.33 |
| persist_decider_location | 25000000 | 0.04 |
| persist_decider_geofence | 25000000 | 0.04 |
| config_fromMap | 584795 | 1.71 |
| config_toMap | 154559 | 6.47 |
| config_roundtrip | 120772 | 8.28 |
| state_fromMap | 552486 | 1.81 |
| state_toMap | 149031 | 6.71 |
| route_context_toMap | 3571428 | 0.28 |
| route_context_fromMap | 2702702 | 0.37 |
| route_context_roundtrip | 1639344 | 0.61 |
| sync_body_context_toMap_50 | 10000000 | 0.10 |
| sync_body_context_fromMap_50 | 26399 | 37.88 |
| http_config_ssl_toMap | 952380 | 1.05 |
| http_config_ssl_fromMap | 4000000 | 0.25 |
| http_config_ssl_roundtrip | 793650 | 1.26 |
| battery_budget_60_samples | 1452878 | 0.69 |
| smart_motion_accel_change | 24654441 | 0.04 |
| battery_budget_single_sample | 25790139 | 0.04 |
| battery_budget_heavy_drain | 750419 | 1.33 |
| smart_motion_speed_change | 23347929 | 0.04 |


### 2026-05-27 — Commit 84cf0ec

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 96618 | 10.35 |
| schedule_isWithin_5_entries | 90252 | 11.08 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 653594 | 1.53 |
| location_fromMap_toMap_roundtrip | 476190 | 2.10 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 90009 | 11.11 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 465116 | 2.15 |
| config_toMap | 128369 | 7.79 |
| config_roundtrip | 99601 | 10.04 |
| state_fromMap | 436681 | 2.29 |
| state_toMap | 123304 | 8.11 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1408450 | 0.71 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22558 | 44.33 |
| http_config_ssl_toMap | 769230 | 1.30 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 641025 | 1.56 |
| smart_motion_accel_change | 26170513 | 0.04 |
| battery_budget_60_samples | 1783127 | 0.56 |
| battery_budget_single_sample | 25078928 | 0.04 |
| smart_motion_speed_change | 25710411 | 0.04 |
| battery_budget_heavy_drain | 905672 | 1.10 |


### 2026-05-27 — Commit 373f712

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 3571428 | 0.28 |
| schedule_matches | 111358 | 8.98 |
| schedule_isWithin_5_entries | 103842 | 9.63 |
| location_fromMap | 2173913 | 0.46 |
| location_toMap | 833333 | 1.20 |
| location_fromMap_toMap_roundtrip | 613496 | 1.63 |
| location_copyWithCoords | 14285714 | 0.07 |
| geofence_fromMap_circular | 5555555 | 0.18 |
| geofence_fromMap_polygon | 2040816 | 0.49 |
| carbon_trip_100_locations | 112739 | 8.87 |
| carbon_onLocation | 5000000 | 0.20 |
| carbon_setActivity | 11111111 | 0.09 |
| carbon_cumulative_report | 3225806 | 0.31 |
| persist_decider_location | 25000000 | 0.04 |
| persist_decider_geofence | 25000000 | 0.04 |
| config_fromMap | 588235 | 1.70 |
| config_toMap | 165837 | 6.03 |
| config_roundtrip | 125628 | 7.96 |
| state_fromMap | 552486 | 1.81 |
| state_toMap | 157480 | 6.35 |
| route_context_toMap | 3846153 | 0.26 |
| route_context_fromMap | 2857142 | 0.35 |
| route_context_roundtrip | 1724137 | 0.58 |
| sync_body_context_toMap_50 | 10000000 | 0.10 |
| sync_body_context_fromMap_50 | 27808 | 35.96 |
| http_config_ssl_toMap | 1020408 | 0.98 |
| http_config_ssl_fromMap | 4166666 | 0.24 |
| http_config_ssl_roundtrip | 833333 | 1.20 |
| battery_budget_heavy_drain | 1253599 | 0.80 |
| smart_motion_accel_change | 31057680 | 0.03 |
| smart_motion_speed_change | 30787962 | 0.03 |
| battery_budget_single_sample | 29093633 | 0.03 |
| battery_budget_60_samples | 2413955 | 0.41 |


### 2026-05-27 — Commit b963032

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 93196 | 10.73 |
| schedule_isWithin_5_entries | 87642 | 11.41 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 462962 | 2.16 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 87796 | 11.39 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2439024 | 0.41 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 454545 | 2.20 |
| config_toMap | 127877 | 7.82 |
| config_roundtrip | 100401 | 9.96 |
| state_fromMap | 431034 | 2.32 |
| state_toMap | 124069 | 8.06 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1298701 | 0.77 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21607 | 46.28 |
| http_config_ssl_toMap | 769230 | 1.30 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 625000 | 1.60 |
| smart_motion_accel_change | 26109689 | 0.04 |
| battery_budget_60_samples | 1784637 | 0.56 |
| smart_motion_speed_change | 25421785 | 0.04 |
| battery_budget_heavy_drain | 920756 | 1.09 |
| battery_budget_single_sample | 24930724 | 0.04 |


### 2026-05-27 — Commit e53cda7

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 88417 | 11.31 |
| schedule_isWithin_5_entries | 81566 | 12.26 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 641025 | 1.56 |
| location_fromMap_toMap_roundtrip | 462962 | 2.16 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 91659 | 10.91 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 434782 | 2.30 |
| config_toMap | 127713 | 7.83 |
| config_roundtrip | 96805 | 10.33 |
| state_fromMap | 420168 | 2.38 |
| state_toMap | 123001 | 8.13 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21762 | 45.95 |
| http_config_ssl_toMap | 787401 | 1.27 |
| http_config_ssl_fromMap | 3125000 | 0.32 |
| http_config_ssl_roundtrip | 645161 | 1.55 |
| smart_motion_accel_change | 24085330 | 0.04 |
| smart_motion_speed_change | 23844255 | 0.04 |
| battery_budget_single_sample | 22567098 | 0.04 |
| battery_budget_heavy_drain | 972544 | 1.03 |
| battery_budget_60_samples | 1876975 | 0.53 |


