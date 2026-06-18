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

### 2026-06-18 — Commit caa8d201

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 91911 | 10.88 |
| schedule_isWithin_5_entries | 81766 | 12.23 |
| location_fromMap | 1612903 | 0.62 |
| location_toMap | 636942 | 1.57 |
| location_fromMap_toMap_roundtrip | 462962 | 2.16 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 92165 | 10.85 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 361010 | 2.77 |
| config_toMap | 104712 | 9.55 |
| config_roundtrip | 80906 | 12.36 |
| state_fromMap | 350877 | 2.85 |
| state_toMap | 99009 | 10.10 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 6666666 | 0.15 |
| sync_body_context_fromMap_50 | 21677 | 46.13 |
| http_config_ssl_toMap | 671140 | 1.49 |
| http_config_ssl_fromMap | 2631578 | 0.38 |
| http_config_ssl_roundtrip | 555555 | 1.80 |
| battery_budget_heavy_drain | 676525 | 1.48 |
| battery_budget_single_sample | 23735820 | 0.04 |
| battery_budget_60_samples | 1305930 | 0.77 |
| smart_motion_accel_change | 23487431 | 0.04 |
| smart_motion_speed_change | 23426834 | 0.04 |


### 2026-06-18 — Commit b6f2a224

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 85324 | 11.72 |
| schedule_isWithin_5_entries | 77220 | 12.95 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 467289 | 2.14 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1612903 | 0.62 |
| carbon_trip_100_locations | 92336 | 10.83 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 353356 | 2.83 |
| config_toMap | 107642 | 9.29 |
| config_roundtrip | 82101 | 12.18 |
| state_fromMap | 338983 | 2.95 |
| state_toMap | 104602 | 9.56 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 6666666 | 0.15 |
| sync_body_context_fromMap_50 | 21663 | 46.16 |
| http_config_ssl_toMap | 704225 | 1.42 |
| http_config_ssl_fromMap | 2564102 | 0.39 |
| http_config_ssl_roundtrip | 564971 | 1.77 |
| smart_motion_speed_change | 21960805 | 0.05 |
| battery_budget_heavy_drain | 665537 | 1.50 |
| smart_motion_accel_change | 22151397 | 0.05 |
| battery_budget_single_sample | 22029519 | 0.05 |
| battery_budget_60_samples | 1288545 | 0.78 |


### 2026-06-18 — Commit ab549621

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 92421 | 10.82 |
| schedule_isWithin_5_entries | 83194 | 12.02 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 473933 | 2.11 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 91911 | 10.88 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 364963 | 2.74 |
| config_toMap | 106382 | 9.40 |
| config_roundtrip | 82644 | 12.10 |
| state_fromMap | 350877 | 2.85 |
| state_toMap | 101832 | 9.82 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22558 | 44.33 |
| http_config_ssl_toMap | 709219 | 1.41 |
| http_config_ssl_fromMap | 2631578 | 0.38 |
| http_config_ssl_roundtrip | 561797 | 1.78 |
| battery_budget_60_samples | 1307840 | 0.76 |
| battery_budget_heavy_drain | 677183 | 1.48 |
| battery_budget_single_sample | 23772363 | 0.04 |
| smart_motion_accel_change | 23530646 | 0.04 |
| smart_motion_speed_change | 23442452 | 0.04 |


### 2026-06-18 — Commit 9a7ec47c

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 85543 | 11.69 |
| schedule_isWithin_5_entries | 77579 | 12.89 |
| location_fromMap | 1587301 | 0.63 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 460829 | 2.17 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1515151 | 0.66 |
| carbon_trip_100_locations | 91240 | 10.96 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 343642 | 2.91 |
| config_toMap | 107181 | 9.33 |
| config_roundtrip | 80580 | 12.41 |
| state_fromMap | 340136 | 2.94 |
| state_toMap | 104493 | 9.57 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21431 | 46.66 |
| http_config_ssl_toMap | 704225 | 1.42 |
| http_config_ssl_fromMap | 2564102 | 0.39 |
| http_config_ssl_roundtrip | 558659 | 1.79 |
| battery_budget_60_samples | 1286211 | 0.78 |
| battery_budget_heavy_drain | 665269 | 1.50 |
| battery_budget_single_sample | 22033303 | 0.05 |
| smart_motion_accel_change | 22157346 | 0.05 |
| smart_motion_speed_change | 21954504 | 0.05 |


### 2026-06-18 — Commit bd256d04

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 90826 | 11.01 |
| schedule_isWithin_5_entries | 83542 | 11.97 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 467289 | 2.14 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4761904 | 0.21 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 93720 | 10.67 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 350877 | 2.85 |
| config_toMap | 106157 | 9.42 |
| config_roundtrip | 80906 | 12.36 |
| state_fromMap | 322580 | 3.10 |
| state_toMap | 104931 | 9.53 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1388888 | 0.72 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 21317 | 46.91 |
| http_config_ssl_toMap | 699300 | 1.43 |
| http_config_ssl_fromMap | 2631578 | 0.38 |
| http_config_ssl_roundtrip | 564971 | 1.77 |
| smart_motion_speed_change | 19860570 | 0.05 |
| smart_motion_accel_change | 19406843 | 0.05 |
| battery_budget_single_sample | 23582707 | 0.04 |
| battery_budget_60_samples | 1293006 | 0.77 |
| battery_budget_heavy_drain | 671943 | 1.49 |


### 2026-06-17 — Commit 86e91e7c

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 93457 | 10.70 |
| schedule_isWithin_5_entries | 84459 | 11.84 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 471698 | 2.12 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 92081 | 10.86 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 363636 | 2.75 |
| config_toMap | 106044 | 9.43 |
| config_roundtrip | 82034 | 12.19 |
| state_fromMap | 349650 | 2.86 |
| state_toMap | 102880 | 9.72 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1408450 | 0.71 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22482 | 44.48 |
| http_config_ssl_toMap | 694444 | 1.44 |
| http_config_ssl_fromMap | 2631578 | 0.38 |
| http_config_ssl_roundtrip | 558659 | 1.79 |
| smart_motion_accel_change | 23504251 | 0.04 |
| battery_budget_60_samples | 1306707 | 0.77 |
| smart_motion_speed_change | 23444506 | 0.04 |
| battery_budget_heavy_drain | 677163 | 1.48 |
| battery_budget_single_sample | 23771190 | 0.04 |


### 2026-06-17 — Commit 89fb1912

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 85616 | 11.68 |
| schedule_isWithin_5_entries | 78431 | 12.75 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 653594 | 1.53 |
| location_fromMap_toMap_roundtrip | 469483 | 2.13 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 89766 | 11.14 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2380952 | 0.42 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 361010 | 2.77 |
| config_toMap | 109170 | 9.16 |
| config_roundtrip | 82440 | 12.13 |
| state_fromMap | 346020 | 2.89 |
| state_toMap | 104275 | 9.59 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21514 | 46.48 |
| http_config_ssl_toMap | 709219 | 1.41 |
| http_config_ssl_fromMap | 2564102 | 0.39 |
| http_config_ssl_roundtrip | 568181 | 1.76 |
| smart_motion_speed_change | 21958011 | 0.05 |
| battery_budget_heavy_drain | 665661 | 1.50 |
| smart_motion_accel_change | 22135699 | 0.05 |
| battery_budget_60_samples | 1288030 | 0.78 |
| battery_budget_single_sample | 21987075 | 0.05 |


### 2026-06-17 — Commit 491d5b83

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 90334 | 11.07 |
| schedule_isWithin_5_entries | 84530 | 11.83 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 649350 | 1.54 |
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
| config_fromMap | 369003 | 2.71 |
| config_toMap | 108459 | 9.22 |
| config_roundtrip | 83402 | 11.99 |
| state_fromMap | 355871 | 2.81 |
| state_toMap | 102564 | 9.75 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1388888 | 0.72 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22371 | 44.70 |
| http_config_ssl_toMap | 689655 | 1.45 |
| http_config_ssl_fromMap | 2631578 | 0.38 |
| http_config_ssl_roundtrip | 552486 | 1.81 |
| smart_motion_accel_change | 23495824 | 0.04 |
| smart_motion_speed_change | 23370702 | 0.04 |
| battery_budget_60_samples | 1305813 | 0.77 |
| battery_budget_single_sample | 23594179 | 0.04 |
| battery_budget_heavy_drain | 676355 | 1.48 |


### 2026-06-17 — Commit a2ecd611

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 91074 | 10.98 |
| schedule_isWithin_5_entries | 81499 | 12.27 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 641025 | 1.56 |
| location_fromMap_toMap_roundtrip | 471698 | 2.12 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 93370 | 10.71 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 352112 | 2.84 |
| config_toMap | 107296 | 9.32 |
| config_roundtrip | 82169 | 12.17 |
| state_fromMap | 335570 | 2.98 |
| state_toMap | 103199 | 9.69 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1388888 | 0.72 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 22578 | 44.29 |
| http_config_ssl_toMap | 694444 | 1.44 |
| http_config_ssl_fromMap | 2564102 | 0.39 |
| http_config_ssl_roundtrip | 558659 | 1.79 |
| battery_budget_heavy_drain | 675692 | 1.48 |
| smart_motion_speed_change | 23344228 | 0.04 |
| battery_budget_60_samples | 1307162 | 0.77 |
| smart_motion_accel_change | 23530400 | 0.04 |
| battery_budget_single_sample | 23582922 | 0.04 |


### 2026-06-17 — Commit 62047a54

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 3030303 | 0.33 |
| schedule_matches | 143472 | 6.97 |
| schedule_isWithin_5_entries | 124843 | 8.01 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 628930 | 1.59 |
| location_fromMap_toMap_roundtrip | 462962 | 2.16 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1612903 | 0.62 |
| carbon_trip_100_locations | 112233 | 8.91 |
| carbon_onLocation | 4347826 | 0.23 |
| carbon_setActivity | 10000000 | 0.10 |
| carbon_cumulative_report | 2702702 | 0.37 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 359712 | 2.78 |
| config_toMap | 110011 | 9.09 |
| config_roundtrip | 85034 | 11.76 |
| state_fromMap | 355871 | 2.81 |
| state_toMap | 106044 | 9.43 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1388888 | 0.72 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 21739 | 46.00 |
| http_config_ssl_toMap | 714285 | 1.40 |
| http_config_ssl_fromMap | 2564102 | 0.39 |
| http_config_ssl_roundtrip | 561797 | 1.78 |
| battery_budget_60_samples | 843602 | 1.19 |
| battery_budget_single_sample | 24019850 | 0.04 |
| smart_motion_accel_change | 17507339 | 0.06 |
| battery_budget_heavy_drain | 426749 | 2.34 |
| smart_motion_speed_change | 17576229 | 0.06 |


### 2026-06-17 — Commit 0627e1e1

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 91575 | 10.92 |
| schedule_isWithin_5_entries | 83892 | 11.92 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 465116 | 2.15 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4761904 | 0.21 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 93370 | 10.71 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2631578 | 0.38 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 358422 | 2.79 |
| config_toMap | 109409 | 9.14 |
| config_roundtrip | 84175 | 11.88 |
| state_fromMap | 347222 | 2.88 |
| state_toMap | 103950 | 9.62 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1408450 | 0.71 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22276 | 44.89 |
| http_config_ssl_toMap | 699300 | 1.43 |
| http_config_ssl_fromMap | 2439024 | 0.41 |
| http_config_ssl_roundtrip | 558659 | 1.79 |
| battery_budget_heavy_drain | 676714 | 1.48 |
| battery_budget_60_samples | 1306992 | 0.77 |
| battery_budget_single_sample | 23590315 | 0.04 |
| smart_motion_accel_change | 23490251 | 0.04 |
| smart_motion_speed_change | 23458364 | 0.04 |


### 2026-06-17 — Commit 6ba45843

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 94073 | 10.63 |
| schedule_isWithin_5_entries | 84388 | 11.85 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 476190 | 2.10 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 91659 | 10.91 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 374531 | 2.67 |
| config_toMap | 109409 | 9.14 |
| config_roundtrip | 83472 | 11.98 |
| state_fromMap | 350877 | 2.85 |
| state_toMap | 103092 | 9.70 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1408450 | 0.71 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22431 | 44.58 |
| http_config_ssl_toMap | 694444 | 1.44 |
| http_config_ssl_fromMap | 2564102 | 0.39 |
| http_config_ssl_roundtrip | 558659 | 1.79 |
| battery_budget_single_sample | 23767959 | 0.04 |
| smart_motion_speed_change | 23436880 | 0.04 |
| battery_budget_60_samples | 1307820 | 0.76 |
| smart_motion_accel_change | 23513064 | 0.04 |
| battery_budget_heavy_drain | 676257 | 1.48 |


### 2026-06-17 — Commit 74214c1d

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 85910 | 11.64 |
| schedule_isWithin_5_entries | 78308 | 12.77 |
| location_fromMap | 1612903 | 0.62 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 467289 | 2.14 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 91827 | 10.89 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 359712 | 2.78 |
| config_toMap | 108225 | 9.24 |
| config_roundtrip | 82712 | 12.09 |
| state_fromMap | 340136 | 2.94 |
| state_toMap | 102986 | 9.71 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 22021 | 45.41 |
| http_config_ssl_toMap | 704225 | 1.42 |
| http_config_ssl_fromMap | 2500000 | 0.40 |
| http_config_ssl_roundtrip | 564971 | 1.77 |
| smart_motion_speed_change | 21930987 | 0.05 |
| battery_budget_single_sample | 22026000 | 0.05 |
| battery_budget_heavy_drain | 665353 | 1.50 |
| battery_budget_60_samples | 1284214 | 0.78 |
| smart_motion_accel_change | 22147803 | 0.05 |


### 2026-06-17 — Commit caf28d38

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 91407 | 10.94 |
| schedule_isWithin_5_entries | 82372 | 12.14 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 476190 | 2.10 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 91491 | 10.93 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 374531 | 2.67 |
| config_toMap | 107296 | 9.32 |
| config_roundtrip | 83402 | 11.99 |
| state_fromMap | 357142 | 2.80 |
| state_toMap | 102354 | 9.77 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22376 | 44.69 |
| http_config_ssl_toMap | 689655 | 1.45 |
| http_config_ssl_fromMap | 2631578 | 0.38 |
| http_config_ssl_roundtrip | 552486 | 1.81 |
| battery_budget_60_samples | 1306645 | 0.77 |
| battery_budget_single_sample | 23747446 | 0.04 |
| battery_budget_heavy_drain | 676890 | 1.48 |
| smart_motion_speed_change | 23428900 | 0.04 |
| smart_motion_accel_change | 23489803 | 0.04 |


### 2026-06-17 — Commit 8dc764d8

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 3125000 | 0.32 |
| schedule_matches | 146842 | 6.81 |
| schedule_isWithin_5_entries | 125000 | 8.00 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 662251 | 1.51 |
| location_fromMap_toMap_roundtrip | 480769 | 2.08 |
| location_copyWithCoords | 12500000 | 0.08 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1694915 | 0.59 |
| carbon_trip_100_locations | 110619 | 9.04 |
| carbon_onLocation | 4347826 | 0.23 |
| carbon_setActivity | 10000000 | 0.10 |
| carbon_cumulative_report | 2702702 | 0.37 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 375939 | 2.66 |
| config_toMap | 115874 | 8.63 |
| config_roundtrip | 88652 | 11.28 |
| state_fromMap | 358422 | 2.79 |
| state_toMap | 111358 | 8.98 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2439024 | 0.41 |
| route_context_roundtrip | 1408450 | 0.71 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 23223 | 43.06 |
| http_config_ssl_toMap | 735294 | 1.36 |
| http_config_ssl_fromMap | 2631578 | 0.38 |
| http_config_ssl_roundtrip | 581395 | 1.72 |
| battery_budget_heavy_drain | 432715 | 2.31 |
| smart_motion_accel_change | 17581254 | 0.06 |
| smart_motion_speed_change | 17556899 | 0.06 |
| battery_budget_60_samples | 854817 | 1.17 |
| battery_budget_single_sample | 22927516 | 0.04 |


### 2026-06-17 — Commit 9b3313df

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 88573 | 11.29 |
| schedule_isWithin_5_entries | 80321 | 12.45 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 476190 | 2.10 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 89445 | 11.18 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 367647 | 2.72 |
| config_toMap | 107526 | 9.30 |
| config_roundtrip | 82987 | 12.05 |
| state_fromMap | 350877 | 2.85 |
| state_toMap | 104058 | 9.61 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1388888 | 0.72 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 22251 | 44.94 |
| http_config_ssl_toMap | 704225 | 1.42 |
| http_config_ssl_fromMap | 2631578 | 0.38 |
| http_config_ssl_roundtrip | 558659 | 1.79 |
| battery_budget_single_sample | 23756274 | 0.04 |
| smart_motion_accel_change | 23408235 | 0.04 |
| battery_budget_60_samples | 1307002 | 0.77 |
| smart_motion_speed_change | 23422594 | 0.04 |
| battery_budget_heavy_drain | 673257 | 1.49 |


### 2026-06-17 — Commit f7b09450

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 90744 | 11.02 |
| schedule_isWithin_5_entries | 83682 | 11.95 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 657894 | 1.52 |
| location_fromMap_toMap_roundtrip | 469483 | 2.13 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1515151 | 0.66 |
| carbon_trip_100_locations | 91996 | 10.87 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 367647 | 2.72 |
| config_toMap | 108225 | 9.24 |
| config_roundtrip | 84245 | 11.87 |
| state_fromMap | 361010 | 2.77 |
| state_toMap | 105820 | 9.45 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1408450 | 0.71 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22779 | 43.90 |
| http_config_ssl_toMap | 704225 | 1.42 |
| http_config_ssl_fromMap | 2500000 | 0.40 |
| http_config_ssl_roundtrip | 558659 | 1.79 |
| battery_budget_single_sample | 23600152 | 0.04 |
| smart_motion_speed_change | 23286283 | 0.04 |
| battery_budget_60_samples | 1309355 | 0.76 |
| battery_budget_heavy_drain | 678841 | 1.47 |
| smart_motion_accel_change | 23271460 | 0.04 |


### 2026-06-17 — Commit d1280495

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 90009 | 11.11 |
| schedule_isWithin_5_entries | 83125 | 12.03 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 653594 | 1.53 |
| location_fromMap_toMap_roundtrip | 473933 | 2.11 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4761904 | 0.21 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 93283 | 10.72 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 362318 | 2.76 |
| config_toMap | 107296 | 9.32 |
| config_roundtrip | 83612 | 11.96 |
| state_fromMap | 341296 | 2.93 |
| state_toMap | 103199 | 9.69 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1408450 | 0.71 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22401 | 44.64 |
| http_config_ssl_toMap | 699300 | 1.43 |
| http_config_ssl_fromMap | 2702702 | 0.37 |
| http_config_ssl_roundtrip | 561797 | 1.78 |
| battery_budget_single_sample | 23561250 | 0.04 |
| smart_motion_accel_change | 23432234 | 0.04 |
| battery_budget_60_samples | 1306974 | 0.77 |
| smart_motion_speed_change | 23380542 | 0.04 |
| battery_budget_heavy_drain | 677411 | 1.48 |


### 2026-06-16 — Commit ecfd192c

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 85616 | 11.68 |
| schedule_isWithin_5_entries | 78125 | 12.80 |
| location_fromMap | 1612903 | 0.62 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 469483 | 2.13 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 90090 | 11.10 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 358422 | 2.79 |
| config_toMap | 106609 | 9.38 |
| config_roundtrip | 80450 | 12.43 |
| state_fromMap | 338983 | 2.95 |
| state_toMap | 103519 | 9.66 |
| route_context_toMap | 2857142 | 0.35 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21815 | 45.84 |
| http_config_ssl_toMap | 704225 | 1.42 |
| http_config_ssl_fromMap | 2564102 | 0.39 |
| http_config_ssl_roundtrip | 564971 | 1.77 |
| smart_motion_accel_change | 21004994 | 0.05 |
| smart_motion_speed_change | 20584814 | 0.05 |
| battery_budget_single_sample | 21997639 | 0.05 |
| battery_budget_60_samples | 1281485 | 0.78 |
| battery_budget_heavy_drain | 659951 | 1.52 |


### 2026-06-16 — Commit 29d16708

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 85324 | 11.72 |
| schedule_isWithin_5_entries | 77519 | 12.90 |
| location_fromMap | 1149425 | 0.87 |
| location_toMap | 636942 | 1.57 |
| location_fromMap_toMap_roundtrip | 416666 | 2.40 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 91996 | 10.87 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 361010 | 2.77 |
| config_toMap | 107642 | 9.29 |
| config_roundtrip | 83263 | 12.01 |
| state_fromMap | 348432 | 2.87 |
| state_toMap | 104493 | 9.57 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21958 | 45.54 |
| http_config_ssl_toMap | 704225 | 1.42 |
| http_config_ssl_fromMap | 2564102 | 0.39 |
| http_config_ssl_roundtrip | 564971 | 1.77 |
| battery_budget_single_sample | 21918411 | 0.05 |
| battery_budget_60_samples | 1283866 | 0.78 |
| smart_motion_accel_change | 22172258 | 0.05 |
| battery_budget_heavy_drain | 663390 | 1.51 |
| smart_motion_speed_change | 21975390 | 0.05 |


### 2026-06-16 — Commit ab5959bf

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 82850 | 12.07 |
| schedule_isWithin_5_entries | 77041 | 12.98 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 465116 | 2.15 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 91491 | 10.93 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 363636 | 2.75 |
| config_toMap | 107526 | 9.30 |
| config_roundtrip | 81900 | 12.21 |
| state_fromMap | 342465 | 2.92 |
| state_toMap | 103626 | 9.65 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21810 | 45.85 |
| http_config_ssl_toMap | 704225 | 1.42 |
| http_config_ssl_fromMap | 2564102 | 0.39 |
| http_config_ssl_roundtrip | 564971 | 1.77 |
| battery_budget_heavy_drain | 643387 | 1.55 |
| battery_budget_single_sample | 22028361 | 0.05 |
| battery_budget_60_samples | 1259271 | 0.79 |
| smart_motion_accel_change | 22170404 | 0.05 |
| smart_motion_speed_change | 21945475 | 0.05 |


### 2026-06-16 — Commit 01b39661

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 3571428 | 0.28 |
| schedule_matches | 110864 | 9.02 |
| schedule_isWithin_5_entries | 100908 | 9.91 |
| location_fromMap | 2127659 | 0.47 |
| location_toMap | 833333 | 1.20 |
| location_fromMap_toMap_roundtrip | 591715 | 1.69 |
| location_copyWithCoords | 14285714 | 0.07 |
| geofence_fromMap_circular | 5555555 | 0.18 |
| geofence_fromMap_polygon | 2000000 | 0.50 |
| carbon_trip_100_locations | 118203 | 8.46 |
| carbon_onLocation | 5263157 | 0.19 |
| carbon_setActivity | 11111111 | 0.09 |
| carbon_cumulative_report | 3333333 | 0.30 |
| persist_decider_location | 25000000 | 0.04 |
| persist_decider_geofence | 25000000 | 0.04 |
| config_fromMap | 469483 | 2.13 |
| config_toMap | 139275 | 7.18 |
| config_roundtrip | 105932 | 9.44 |
| state_fromMap | 448430 | 2.23 |
| state_toMap | 134589 | 7.43 |
| route_context_toMap | 3846153 | 0.26 |
| route_context_fromMap | 2777777 | 0.36 |
| route_context_roundtrip | 1724137 | 0.58 |
| sync_body_context_toMap_50 | 10000000 | 0.10 |
| sync_body_context_fromMap_50 | 28264 | 35.38 |
| http_config_ssl_toMap | 917431 | 1.09 |
| http_config_ssl_fromMap | 3333333 | 0.30 |
| http_config_ssl_roundtrip | 735294 | 1.36 |
| battery_budget_single_sample | 28403550 | 0.04 |
| smart_motion_accel_change | 28611461 | 0.03 |
| battery_budget_60_samples | 1662024 | 0.60 |
| battery_budget_heavy_drain | 858089 | 1.17 |
| smart_motion_speed_change | 28403598 | 0.04 |


### 2026-06-16 — Commit de958edb

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 91827 | 10.89 |
| schedule_isWithin_5_entries | 83963 | 11.91 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 462962 | 2.16 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 92764 | 10.78 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 373134 | 2.68 |
| config_toMap | 105820 | 9.45 |
| config_roundtrip | 84104 | 11.89 |
| state_fromMap | 366300 | 2.73 |
| state_toMap | 106157 | 9.42 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1428571 | 0.70 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22517 | 44.41 |
| http_config_ssl_toMap | 704225 | 1.42 |
| http_config_ssl_fromMap | 2631578 | 0.38 |
| http_config_ssl_roundtrip | 558659 | 1.79 |
| battery_budget_heavy_drain | 676841 | 1.48 |
| smart_motion_accel_change | 23494216 | 0.04 |
| battery_budget_single_sample | 23765189 | 0.04 |
| battery_budget_60_samples | 1307306 | 0.76 |
| smart_motion_speed_change | 23440631 | 0.04 |


### 2026-06-16 — Commit 1938c0c5

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 92850 | 10.77 |
| schedule_isWithin_5_entries | 83822 | 11.93 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 465116 | 2.15 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 93720 | 10.67 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 369003 | 2.71 |
| config_toMap | 107874 | 9.27 |
| config_roundtrip | 82781 | 12.08 |
| state_fromMap | 352112 | 2.84 |
| state_toMap | 104602 | 9.56 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22763 | 43.93 |
| http_config_ssl_toMap | 704225 | 1.42 |
| http_config_ssl_fromMap | 2631578 | 0.38 |
| http_config_ssl_roundtrip | 558659 | 1.79 |
| battery_budget_single_sample | 23567038 | 0.04 |
| battery_budget_heavy_drain | 675495 | 1.48 |
| smart_motion_accel_change | 23379321 | 0.04 |
| battery_budget_60_samples | 1305057 | 0.77 |
| smart_motion_speed_change | 23405251 | 0.04 |


### 2026-06-16 — Commit 873474fa

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 84388 | 11.85 |
| schedule_isWithin_5_entries | 77459 | 12.91 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 471698 | 2.12 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 88731 | 11.27 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 358422 | 2.79 |
| config_toMap | 107066 | 9.34 |
| config_roundtrip | 81168 | 12.32 |
| state_fromMap | 340136 | 2.94 |
| state_toMap | 101317 | 9.87 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21556 | 46.39 |
| http_config_ssl_toMap | 704225 | 1.42 |
| http_config_ssl_fromMap | 2564102 | 0.39 |
| http_config_ssl_roundtrip | 561797 | 1.78 |
| battery_budget_60_samples | 1288573 | 0.78 |
| battery_budget_heavy_drain | 664923 | 1.50 |
| smart_motion_accel_change | 22142959 | 0.05 |
| smart_motion_speed_change | 21882078 | 0.05 |
| battery_budget_single_sample | 21995852 | 0.05 |


### 2026-06-15 — Commit 9c9b2e45

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 92850 | 10.77 |
| schedule_isWithin_5_entries | 84245 | 11.87 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 653594 | 1.53 |
| location_fromMap_toMap_roundtrip | 476190 | 2.10 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 93632 | 10.68 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 359712 | 2.78 |
| config_toMap | 109170 | 9.16 |
| config_roundtrip | 82169 | 12.17 |
| state_fromMap | 347222 | 2.88 |
| state_toMap | 103950 | 9.62 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1408450 | 0.71 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22851 | 43.76 |
| http_config_ssl_toMap | 709219 | 1.41 |
| http_config_ssl_fromMap | 2631578 | 0.38 |
| http_config_ssl_roundtrip | 564971 | 1.77 |
| battery_budget_60_samples | 1307934 | 0.76 |
| battery_budget_heavy_drain | 677209 | 1.48 |
| battery_budget_single_sample | 23581590 | 0.04 |
| smart_motion_accel_change | 23529363 | 0.04 |
| smart_motion_speed_change | 23413498 | 0.04 |


### 2026-06-15 — Commit 15dca1c1

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 85034 | 11.76 |
| schedule_isWithin_5_entries | 74626 | 13.40 |
| location_fromMap | 1612903 | 0.62 |
| location_toMap | 628930 | 1.59 |
| location_fromMap_toMap_roundtrip | 467289 | 2.14 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 90090 | 11.10 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 364963 | 2.74 |
| config_toMap | 107874 | 9.27 |
| config_roundtrip | 82508 | 12.12 |
| state_fromMap | 347222 | 2.88 |
| state_toMap | 104602 | 9.56 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21701 | 46.08 |
| http_config_ssl_toMap | 704225 | 1.42 |
| http_config_ssl_fromMap | 2564102 | 0.39 |
| http_config_ssl_roundtrip | 555555 | 1.80 |
| smart_motion_speed_change | 21885212 | 0.05 |
| battery_budget_60_samples | 1286737 | 0.78 |
| battery_budget_single_sample | 22015073 | 0.05 |
| smart_motion_accel_change | 22153704 | 0.05 |
| battery_budget_heavy_drain | 665296 | 1.50 |


### 2026-06-15 — Commit 28d7bc9a

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 3125000 | 0.32 |
| schedule_matches | 179211 | 5.58 |
| schedule_isWithin_5_entries | 142045 | 7.04 |
| location_fromMap | 1923076 | 0.52 |
| location_toMap | 746268 | 1.34 |
| location_fromMap_toMap_roundtrip | 531914 | 1.88 |
| location_copyWithCoords | 12500000 | 0.08 |
| geofence_fromMap_circular | 5555555 | 0.18 |
| geofence_fromMap_polygon | 2083333 | 0.48 |
| carbon_trip_100_locations | 144508 | 6.92 |
| carbon_onLocation | 5263157 | 0.19 |
| carbon_setActivity | 11111111 | 0.09 |
| carbon_cumulative_report | 3030303 | 0.33 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 421940 | 2.37 |
| config_toMap | 125156 | 7.99 |
| config_roundtrip | 93457 | 10.70 |
| state_fromMap | 401606 | 2.49 |
| state_toMap | 119904 | 8.34 |
| route_context_toMap | 3448275 | 0.29 |
| route_context_fromMap | 2857142 | 0.35 |
| route_context_roundtrip | 1639344 | 0.61 |
| sync_body_context_toMap_50 | 9090909 | 0.11 |
| sync_body_context_fromMap_50 | 27240 | 36.71 |
| http_config_ssl_toMap | 813008 | 1.23 |
| http_config_ssl_fromMap | 3030303 | 0.33 |
| http_config_ssl_roundtrip | 645161 | 1.55 |
| battery_budget_single_sample | 21088212 | 0.05 |
| battery_budget_heavy_drain | 411219 | 2.43 |
| smart_motion_accel_change | 16238631 | 0.06 |
| smart_motion_speed_change | 16296703 | 0.06 |
| battery_budget_60_samples | 816465 | 1.22 |


### 2026-06-15 — Commit fa5d6fa0

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 89047 | 11.23 |
| schedule_isWithin_5_entries | 81766 | 12.23 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 653594 | 1.53 |
| location_fromMap_toMap_roundtrip | 473933 | 2.11 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1515151 | 0.66 |
| carbon_trip_100_locations | 90909 | 11.00 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 16666666 | 0.06 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 354609 | 2.82 |
| config_toMap | 107296 | 9.32 |
| config_roundtrip | 80971 | 12.35 |
| state_fromMap | 335570 | 2.98 |
| state_toMap | 102986 | 9.71 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 22326 | 44.79 |
| http_config_ssl_toMap | 689655 | 1.45 |
| http_config_ssl_fromMap | 2500000 | 0.40 |
| http_config_ssl_roundtrip | 558659 | 1.79 |
| smart_motion_accel_change | 23474203 | 0.04 |
| smart_motion_speed_change | 22617401 | 0.04 |
| battery_budget_single_sample | 23754337 | 0.04 |
| battery_budget_heavy_drain | 677017 | 1.48 |
| battery_budget_60_samples | 1305398 | 0.77 |


### 2026-06-15 — Commit 5004330a

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 90579 | 11.04 |
| schedule_isWithin_5_entries | 81300 | 12.30 |
| location_fromMap | 1612903 | 0.62 |
| location_toMap | 636942 | 1.57 |
| location_fromMap_toMap_roundtrip | 469483 | 2.13 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 90744 | 11.02 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 364963 | 2.74 |
| config_toMap | 106382 | 9.40 |
| config_roundtrip | 81967 | 12.20 |
| state_fromMap | 352112 | 2.84 |
| state_toMap | 101832 | 9.82 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 21777 | 45.92 |
| http_config_ssl_toMap | 689655 | 1.45 |
| http_config_ssl_fromMap | 2631578 | 0.38 |
| http_config_ssl_roundtrip | 558659 | 1.79 |
| smart_motion_accel_change | 23444554 | 0.04 |
| smart_motion_speed_change | 23232839 | 0.04 |
| battery_budget_60_samples | 1307201 | 0.76 |
| battery_budget_heavy_drain | 677643 | 1.48 |
| battery_budget_single_sample | 23566746 | 0.04 |


### 2026-06-15 — Commit d5d744a0

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 84889 | 11.78 |
| schedule_isWithin_5_entries | 77160 | 12.96 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 628930 | 1.59 |
| location_fromMap_toMap_roundtrip | 471698 | 2.12 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 89206 | 11.21 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 363636 | 2.75 |
| config_toMap | 107991 | 9.26 |
| config_roundtrip | 83612 | 11.96 |
| state_fromMap | 350877 | 2.85 |
| state_toMap | 103950 | 9.62 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21724 | 46.03 |
| http_config_ssl_toMap | 689655 | 1.45 |
| http_config_ssl_fromMap | 2500000 | 0.40 |
| http_config_ssl_roundtrip | 558659 | 1.79 |
| battery_budget_single_sample | 22026435 | 0.05 |
| battery_budget_heavy_drain | 665969 | 1.50 |
| smart_motion_speed_change | 21990885 | 0.05 |
| battery_budget_60_samples | 1282013 | 0.78 |
| smart_motion_accel_change | 22201844 | 0.05 |


### 2026-06-15 — Commit 358c6ac3

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 85106 | 11.75 |
| schedule_isWithin_5_entries | 77279 | 12.94 |
| location_fromMap | 1612903 | 0.62 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 469483 | 2.13 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 88652 | 11.28 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 364963 | 2.74 |
| config_toMap | 108225 | 9.24 |
| config_roundtrip | 82236 | 12.16 |
| state_fromMap | 349650 | 2.86 |
| state_toMap | 104058 | 9.61 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21640 | 46.21 |
| http_config_ssl_toMap | 704225 | 1.42 |
| http_config_ssl_fromMap | 2500000 | 0.40 |
| http_config_ssl_roundtrip | 555555 | 1.80 |
| battery_budget_60_samples | 1268689 | 0.79 |
| battery_budget_single_sample | 21944721 | 0.05 |
| smart_motion_speed_change | 21844424 | 0.05 |
| smart_motion_accel_change | 22027053 | 0.05 |
| battery_budget_heavy_drain | 657640 | 1.52 |


### 2026-06-15 — Commit bc52d780

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 91240 | 10.96 |
| schedule_isWithin_5_entries | 83752 | 11.94 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 452488 | 2.21 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4761904 | 0.21 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 93283 | 10.72 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 353356 | 2.83 |
| config_toMap | 107874 | 9.27 |
| config_roundtrip | 83682 | 11.95 |
| state_fromMap | 344827 | 2.90 |
| state_toMap | 103842 | 9.63 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1408450 | 0.71 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22466 | 44.51 |
| http_config_ssl_toMap | 694444 | 1.44 |
| http_config_ssl_fromMap | 2631578 | 0.38 |
| http_config_ssl_roundtrip | 561797 | 1.78 |
| battery_budget_single_sample | 23704796 | 0.04 |
| battery_budget_60_samples | 1304926 | 0.77 |
| battery_budget_heavy_drain | 676544 | 1.48 |
| smart_motion_accel_change | 23522496 | 0.04 |
| smart_motion_speed_change | 23433425 | 0.04 |


### 2026-06-15 — Commit af547e15

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 92936 | 10.76 |
| schedule_isWithin_5_entries | 83822 | 11.93 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 469483 | 2.13 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4761904 | 0.21 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 94517 | 10.58 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2631578 | 0.38 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 367647 | 2.72 |
| config_toMap | 107642 | 9.29 |
| config_roundtrip | 83542 | 11.97 |
| state_fromMap | 347222 | 2.88 |
| state_toMap | 103199 | 9.69 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1408450 | 0.71 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22168 | 45.11 |
| http_config_ssl_toMap | 694444 | 1.44 |
| http_config_ssl_fromMap | 2631578 | 0.38 |
| http_config_ssl_roundtrip | 564971 | 1.77 |
| battery_budget_single_sample | 23771612 | 0.04 |
| battery_budget_heavy_drain | 672961 | 1.49 |
| battery_budget_60_samples | 1307130 | 0.77 |
| smart_motion_accel_change | 23506643 | 0.04 |
| smart_motion_speed_change | 23291964 | 0.04 |


### 2026-06-15 — Commit b196ee9b

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 84530 | 11.83 |
| schedule_isWithin_5_entries | 76923 | 13.00 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 471698 | 2.12 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 92081 | 10.86 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 367647 | 2.72 |
| config_toMap | 108577 | 9.21 |
| config_roundtrip | 81699 | 12.24 |
| state_fromMap | 347222 | 2.88 |
| state_toMap | 103626 | 9.65 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 22016 | 45.42 |
| http_config_ssl_toMap | 704225 | 1.42 |
| http_config_ssl_fromMap | 2564102 | 0.39 |
| http_config_ssl_roundtrip | 561797 | 1.78 |
| battery_budget_single_sample | 22023239 | 0.05 |
| battery_budget_heavy_drain | 663759 | 1.51 |
| smart_motion_speed_change | 21982281 | 0.05 |
| battery_budget_60_samples | 1284728 | 0.78 |
| smart_motion_accel_change | 22116010 | 0.05 |


### 2026-06-14 — Commit 0f53001d

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 88652 | 11.28 |
| schedule_isWithin_5_entries | 83194 | 12.02 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 469483 | 2.13 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 90090 | 11.10 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 352112 | 2.84 |
| config_toMap | 105932 | 9.44 |
| config_roundtrip | 82440 | 12.13 |
| state_fromMap | 352112 | 2.84 |
| state_toMap | 104275 | 9.59 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22143 | 45.16 |
| http_config_ssl_toMap | 689655 | 1.45 |
| http_config_ssl_fromMap | 2631578 | 0.38 |
| http_config_ssl_roundtrip | 558659 | 1.79 |
| battery_budget_60_samples | 1292793 | 0.77 |
| battery_budget_heavy_drain | 673883 | 1.48 |
| battery_budget_single_sample | 23772146 | 0.04 |
| smart_motion_speed_change | 22589818 | 0.04 |
| smart_motion_accel_change | 21626356 | 0.05 |


### 2026-06-14 — Commit 9ca7d509

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 83472 | 11.98 |
| schedule_isWithin_5_entries | 77519 | 12.90 |
| location_fromMap | 1612903 | 0.62 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 476190 | 2.10 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 90497 | 11.05 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 364963 | 2.74 |
| config_toMap | 107411 | 9.31 |
| config_roundtrip | 82712 | 12.09 |
| state_fromMap | 353356 | 2.83 |
| state_toMap | 104275 | 9.59 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21925 | 45.61 |
| http_config_ssl_toMap | 699300 | 1.43 |
| http_config_ssl_fromMap | 2500000 | 0.40 |
| http_config_ssl_roundtrip | 555555 | 1.80 |
| smart_motion_accel_change | 22148279 | 0.05 |
| battery_budget_single_sample | 22024054 | 0.05 |
| battery_budget_60_samples | 1289066 | 0.78 |
| battery_budget_heavy_drain | 665231 | 1.50 |
| smart_motion_speed_change | 21977117 | 0.05 |


### 2026-06-14 — Commit 2cc83fc9

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 93283 | 10.72 |
| schedule_isWithin_5_entries | 85034 | 11.76 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 653594 | 1.53 |
| location_fromMap_toMap_roundtrip | 467289 | 2.14 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 93283 | 10.72 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 344827 | 2.90 |
| config_toMap | 107181 | 9.33 |
| config_roundtrip | 82304 | 12.15 |
| state_fromMap | 333333 | 3.00 |
| state_toMap | 104384 | 9.58 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1388888 | 0.72 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22451 | 44.54 |
| http_config_ssl_toMap | 699300 | 1.43 |
| http_config_ssl_fromMap | 2631578 | 0.38 |
| http_config_ssl_roundtrip | 561797 | 1.78 |
| battery_budget_heavy_drain | 675979 | 1.48 |
| smart_motion_accel_change | 23514428 | 0.04 |
| battery_budget_60_samples | 1305843 | 0.77 |
| smart_motion_speed_change | 22390486 | 0.04 |
| battery_budget_single_sample | 23581827 | 0.04 |


### 2026-06-14 — Commit 895ef70d

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 83963 | 11.91 |
| schedule_isWithin_5_entries | 76923 | 13.00 |
| location_fromMap | 1612903 | 0.62 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 473933 | 2.11 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 89847 | 11.13 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 363636 | 2.75 |
| config_toMap | 107296 | 9.32 |
| config_roundtrip | 82440 | 12.13 |
| state_fromMap | 350877 | 2.85 |
| state_toMap | 104058 | 9.61 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21968 | 45.52 |
| http_config_ssl_toMap | 709219 | 1.41 |
| http_config_ssl_fromMap | 2564102 | 0.39 |
| http_config_ssl_roundtrip | 564971 | 1.77 |
| battery_budget_single_sample | 21981996 | 0.05 |
| smart_motion_speed_change | 22013848 | 0.05 |
| battery_budget_60_samples | 1252597 | 0.80 |
| smart_motion_accel_change | 22182921 | 0.05 |
| battery_budget_heavy_drain | 665458 | 1.50 |


### 2026-06-14 — Commit 889c4b0a

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 92336 | 10.83 |
| schedule_isWithin_5_entries | 85470 | 11.70 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 462962 | 2.16 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 93023 | 10.75 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 373134 | 2.68 |
| config_toMap | 106951 | 9.35 |
| config_roundtrip | 82236 | 12.16 |
| state_fromMap | 354609 | 2.82 |
| state_toMap | 102354 | 9.77 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1408450 | 0.71 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22109 | 45.23 |
| http_config_ssl_toMap | 694444 | 1.44 |
| http_config_ssl_fromMap | 2631578 | 0.38 |
| http_config_ssl_roundtrip | 552486 | 1.81 |
| battery_budget_single_sample | 23583185 | 0.04 |
| battery_budget_60_samples | 1308223 | 0.76 |
| smart_motion_accel_change | 23204348 | 0.04 |
| smart_motion_speed_change | 23462703 | 0.04 |
| battery_budget_heavy_drain | 677735 | 1.48 |


### 2026-06-14 — Commit 1aa51d4d

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 91575 | 10.92 |
| schedule_isWithin_5_entries | 84388 | 11.85 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 641025 | 1.56 |
| location_fromMap_toMap_roundtrip | 469483 | 2.13 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 92764 | 10.78 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 354609 | 2.82 |
| config_toMap | 105708 | 9.46 |
| config_roundtrip | 81433 | 12.28 |
| state_fromMap | 342465 | 2.92 |
| state_toMap | 102564 | 9.75 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22065 | 45.32 |
| http_config_ssl_toMap | 684931 | 1.46 |
| http_config_ssl_fromMap | 2631578 | 0.38 |
| http_config_ssl_roundtrip | 552486 | 1.81 |
| battery_budget_heavy_drain | 676746 | 1.48 |
| battery_budget_single_sample | 23551733 | 0.04 |
| battery_budget_60_samples | 1307271 | 0.76 |
| smart_motion_accel_change | 23463753 | 0.04 |
| smart_motion_speed_change | 23412169 | 0.04 |


### 2026-06-14 — Commit 17e65589

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2631578 | 0.38 |
| schedule_matches | 84104 | 11.89 |
| schedule_isWithin_5_entries | 77339 | 12.93 |
| location_fromMap | 1612903 | 0.62 |
| location_toMap | 636942 | 1.57 |
| location_fromMap_toMap_roundtrip | 444444 | 2.25 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 90334 | 11.07 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 362318 | 2.76 |
| config_toMap | 107066 | 9.34 |
| config_roundtrip | 81300 | 12.30 |
| state_fromMap | 342465 | 2.92 |
| state_toMap | 102774 | 9.73 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1315789 | 0.76 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21729 | 46.02 |
| http_config_ssl_toMap | 694444 | 1.44 |
| http_config_ssl_fromMap | 2564102 | 0.39 |
| http_config_ssl_roundtrip | 555555 | 1.80 |
| smart_motion_speed_change | 21935873 | 0.05 |
| battery_budget_single_sample | 22034538 | 0.05 |
| battery_budget_heavy_drain | 658770 | 1.52 |
| battery_budget_60_samples | 1288382 | 0.78 |
| smart_motion_accel_change | 22160993 | 0.05 |


### 2026-06-13 — Commit fb0be1e1

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 92336 | 10.83 |
| schedule_isWithin_5_entries | 82781 | 12.08 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 657894 | 1.52 |
| location_fromMap_toMap_roundtrip | 478468 | 2.09 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 93984 | 10.64 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 362318 | 2.76 |
| config_toMap | 108813 | 9.19 |
| config_roundtrip | 83333 | 12.00 |
| state_fromMap | 344827 | 2.90 |
| state_toMap | 102459 | 9.76 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1388888 | 0.72 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22568 | 44.31 |
| http_config_ssl_toMap | 729927 | 1.37 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 588235 | 1.70 |
| battery_budget_60_samples | 1308068 | 0.76 |
| battery_budget_heavy_drain | 673204 | 1.49 |
| smart_motion_speed_change | 23398144 | 0.04 |
| smart_motion_accel_change | 23374109 | 0.04 |
| battery_budget_single_sample | 23756144 | 0.04 |


### 2026-06-13 — Commit 93b18ea1

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 91491 | 10.93 |
| schedule_isWithin_5_entries | 82440 | 12.13 |
| location_fromMap | 1612903 | 0.62 |
| location_toMap | 653594 | 1.53 |
| location_fromMap_toMap_roundtrip | 471698 | 2.12 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 91996 | 10.87 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 438596 | 2.28 |
| config_toMap | 125470 | 7.97 |
| config_roundtrip | 96339 | 10.38 |
| state_fromMap | 403225 | 2.48 |
| state_toMap | 121802 | 8.21 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 21477 | 46.56 |
| http_config_ssl_toMap | 729927 | 1.37 |
| http_config_ssl_fromMap | 2777777 | 0.36 |
| http_config_ssl_roundtrip | 588235 | 1.70 |
| smart_motion_speed_change | 23463258 | 0.04 |
| smart_motion_accel_change | 23496638 | 0.04 |
| battery_budget_60_samples | 1307096 | 0.77 |
| battery_budget_heavy_drain | 676640 | 1.48 |
| battery_budget_single_sample | 23386595 | 0.04 |


### 2026-06-12 — Commit 20627d3a

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 85689 | 11.67 |
| schedule_isWithin_5_entries | 77942 | 12.83 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 653594 | 1.53 |
| location_fromMap_toMap_roundtrip | 476190 | 2.10 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 88809 | 11.26 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 438596 | 2.28 |
| config_toMap | 125786 | 7.95 |
| config_roundtrip | 96339 | 10.38 |
| state_fromMap | 413223 | 2.42 |
| state_toMap | 120336 | 8.31 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21734 | 46.01 |
| http_config_ssl_toMap | 724637 | 1.38 |
| http_config_ssl_fromMap | 2702702 | 0.37 |
| http_config_ssl_roundtrip | 588235 | 1.70 |
| battery_budget_60_samples | 1288823 | 0.78 |
| battery_budget_heavy_drain | 665199 | 1.50 |
| battery_budget_single_sample | 22003620 | 0.05 |
| smart_motion_accel_change | 22178853 | 0.05 |
| smart_motion_speed_change | 22013741 | 0.05 |


### 2026-06-12 — Commit 238db7d3

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 5263157 | 0.19 |
| schedule_matches | 133689 | 7.48 |
| schedule_isWithin_5_entries | 121359 | 8.24 |
| location_fromMap | 3125000 | 0.32 |
| location_toMap | 1250000 | 0.80 |
| location_fromMap_toMap_roundtrip | 909090 | 1.10 |
| location_copyWithCoords | 20000000 | 0.05 |
| geofence_fromMap_circular | 8333333 | 0.12 |
| geofence_fromMap_polygon | 3030303 | 0.33 |
| carbon_trip_100_locations | 176991 | 5.65 |
| carbon_onLocation | 7142857 | 0.14 |
| carbon_setActivity | 16666666 | 0.06 |
| carbon_cumulative_report | 4761904 | 0.21 |
| persist_decider_location | 33333333 | 0.03 |
| persist_decider_geofence | 33333333 | 0.03 |
| config_fromMap | 840336 | 1.19 |
| config_toMap | 236406 | 4.23 |
| config_roundtrip | 185185 | 5.40 |
| state_fromMap | 787401 | 1.27 |
| state_toMap | 223713 | 4.47 |
| route_context_toMap | 5263157 | 0.19 |
| route_context_fromMap | 4545454 | 0.22 |
| route_context_roundtrip | 2702702 | 0.37 |
| sync_body_context_toMap_50 | 14285714 | 0.07 |
| sync_body_context_fromMap_50 | 43159 | 23.17 |
| http_config_ssl_toMap | 1408450 | 0.71 |
| http_config_ssl_fromMap | 5555555 | 0.18 |
| http_config_ssl_roundtrip | 1162790 | 0.86 |
| battery_budget_60_samples | 1193081 | 0.84 |
| battery_budget_heavy_drain | 607190 | 1.65 |
| battery_budget_single_sample | 28094877 | 0.04 |
| smart_motion_accel_change | 21838480 | 0.05 |
| smart_motion_speed_change | 21512908 | 0.05 |


### 2026-06-12 — Commit 6f836617

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 92592 | 10.80 |
| schedule_isWithin_5_entries | 84674 | 11.81 |
| location_fromMap | 1724137 | 0.58 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 471698 | 2.12 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 93196 | 10.73 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 462962 | 2.16 |
| config_toMap | 126422 | 7.91 |
| config_roundtrip | 98814 | 10.12 |
| state_fromMap | 434782 | 2.30 |
| state_toMap | 121951 | 8.20 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1388888 | 0.72 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22502 | 44.44 |
| http_config_ssl_toMap | 724637 | 1.38 |
| http_config_ssl_fromMap | 2941176 | 0.34 |
| http_config_ssl_roundtrip | 588235 | 1.70 |
| battery_budget_60_samples | 1306663 | 0.77 |
| smart_motion_speed_change | 23441884 | 0.04 |
| battery_budget_single_sample | 23770555 | 0.04 |
| smart_motion_accel_change | 23519967 | 0.04 |
| battery_budget_heavy_drain | 677317 | 1.48 |


### 2026-06-12 — Commit c93051d9

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 91240 | 10.96 |
| schedule_isWithin_5_entries | 84459 | 11.84 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 460829 | 2.17 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 92421 | 10.82 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 444444 | 2.25 |
| config_toMap | 125156 | 7.99 |
| config_roundtrip | 95877 | 10.43 |
| state_fromMap | 418410 | 2.39 |
| state_toMap | 118343 | 8.45 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21881 | 45.70 |
| http_config_ssl_toMap | 719424 | 1.39 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 584795 | 1.71 |
| battery_budget_60_samples | 1306371 | 0.77 |
| battery_budget_heavy_drain | 676807 | 1.48 |
| smart_motion_speed_change | 23464018 | 0.04 |
| battery_budget_single_sample | 23575396 | 0.04 |
| smart_motion_accel_change | 23414509 | 0.04 |


### 2026-06-12 — Commit 02f1e7be

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 90579 | 11.04 |
| schedule_isWithin_5_entries | 82169 | 12.17 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 641025 | 1.56 |
| location_fromMap_toMap_roundtrip | 471698 | 2.12 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 92421 | 10.82 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 438596 | 2.28 |
| config_toMap | 122549 | 8.16 |
| config_roundtrip | 95785 | 10.44 |
| state_fromMap | 421940 | 2.37 |
| state_toMap | 118623 | 8.43 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21824 | 45.82 |
| http_config_ssl_toMap | 714285 | 1.40 |
| http_config_ssl_fromMap | 2941176 | 0.34 |
| http_config_ssl_roundtrip | 578034 | 1.73 |
| battery_budget_heavy_drain | 676471 | 1.48 |
| smart_motion_speed_change | 23437625 | 0.04 |
| battery_budget_single_sample | 23546570 | 0.04 |
| battery_budget_60_samples | 1292850 | 0.77 |
| smart_motion_accel_change | 23455769 | 0.04 |


### 2026-06-12 — Commit 100c821f

**Environment:** Dart 3.12.2, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 93545 | 10.69 |
| schedule_isWithin_5_entries | 84817 | 11.79 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 458715 | 2.18 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 91827 | 10.89 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2631578 | 0.38 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 450450 | 2.22 |
| config_toMap | 126262 | 7.92 |
| config_roundtrip | 97656 | 10.24 |
| state_fromMap | 418410 | 2.39 |
| state_toMap | 120772 | 8.28 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1388888 | 0.72 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22552 | 44.34 |
| http_config_ssl_toMap | 729927 | 1.37 |
| http_config_ssl_fromMap | 2941176 | 0.34 |
| http_config_ssl_roundtrip | 609756 | 1.64 |
| battery_budget_60_samples | 1305858 | 0.77 |
| battery_budget_heavy_drain | 677544 | 1.48 |
| battery_budget_single_sample | 23759252 | 0.04 |
| smart_motion_accel_change | 23432548 | 0.04 |
| smart_motion_speed_change | 23435025 | 0.04 |


