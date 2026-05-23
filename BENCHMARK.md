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

### 2026-05-23 — Commit cf6c662

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7320759 | 0.14 |
| kalman_process_100_fixes | 94922 | 10.53 |
| kalman_process_1k_fixes | 9559 | 104.61 |
| kalman_reset | 6787679 | 0.15 |
| haversine_single | 8235966 | 0.12 |
| haversine_1k_pairs | 13846 | 72.22 |
| pip_4v | 13443589 | 0.07 |
| pip_10v | 10029288 | 0.10 |
| pip_50v | 3948013 | 0.25 |
| pip_100v | 2119259 | 0.47 |
| pip_500v | 431806 | 2.32 |
| geofence_eval_10_circular | 651203 | 1.54 |
| geofence_eval_100_circular | 69729 | 14.34 |
| geofence_eval_500_circular | 13414 | 74.55 |
| geofence_eval_10_polygon_6v | 413157 | 2.42 |
| geofence_eval_50_polygon_6v | 82541 | 12.12 |
| processor_1k_fixes | 8955 | 111.66 |
| processor_1k_adaptive | 8479 | 117.94 |
| trip_manager_5k_waypoints | 73 | 13639.06 |
| schedule_parse | 2810126 | 0.36 |
| schedule_matches | 129854 | 7.70 |
| schedule_isWithin_5_entries | 122448 | 8.17 |
| adaptive_compute | 12645765 | 0.08 |
| location_fromMap | 1686892 | 0.59 |
| location_toMap | 667369 | 1.50 |
| location_fromMap_toMap_roundtrip | 481068 | 2.08 |
| location_copyWithCoords | 11977685 | 0.08 |
| geofence_fromMap_circular | 4452282 | 0.22 |
| geofence_fromMap_polygon | 1630688 | 0.61 |
| delta_encode_10 | 14568 | 68.64 |
| delta_decode_10 | 90541 | 11.04 |
| delta_encode_100 | 2507 | 398.90 |
| delta_decode_100 | 10987 | 91.02 |
| delta_encode_500 | 516 | 1937.11 |
| delta_decode_500 | 2106 | 474.79 |
| delta_roundtrip_100 | 2069 | 483.39 |
| battery_budget_single_sample | 8821891 | 0.11 |
| battery_budget_60_samples | 292089 | 3.42 |
| battery_budget_heavy_drain | 147400 | 6.78 |
| carbon_trip_100_locations | 88262 | 11.33 |
| carbon_onLocation | 4038967 | 0.25 |
| carbon_setActivity | 9647492 | 0.10 |
| carbon_cumulative_report | 2651074 | 0.38 |
| persist_decider_location | 20357582 | 0.05 |
| persist_decider_geofence | 20330734 | 0.05 |
| config_fromMap | 479352 | 2.09 |
| config_toMap | 131650 | 7.60 |
| config_roundtrip | 100683 | 9.93 |
| state_fromMap | 450619 | 2.22 |
| state_toMap | 124685 | 8.02 |
| route_context_toMap | 3041031 | 0.33 |
| route_context_fromMap | 2300833 | 0.43 |
| route_context_roundtrip | 1407104 | 0.71 |
| sync_body_context_toMap_50 | 8374819 | 0.12 |
| sync_body_context_fromMap_50 | 22472 | 44.50 |
| http_config_ssl_toMap | 789255 | 1.27 |
| http_config_ssl_fromMap | 3326406 | 0.30 |
| http_config_ssl_roundtrip | 653378 | 1.53 |


### 2026-05-22 — Commit fbf46b2

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7238052 | 0.14 |
| kalman_process_100_fixes | 94322 | 10.60 |
| kalman_process_1k_fixes | 8943 | 111.82 |
| kalman_reset | 6880453 | 0.15 |
| haversine_single | 7868302 | 0.13 |
| haversine_1k_pairs | 13712 | 72.93 |
| pip_4v | 12959335 | 0.08 |
| pip_10v | 9740375 | 0.10 |
| pip_50v | 3798331 | 0.26 |
| pip_100v | 2012480 | 0.50 |
| pip_500v | 421058 | 2.37 |
| geofence_eval_10_circular | 636820 | 1.57 |
| geofence_eval_100_circular | 70333 | 14.22 |
| geofence_eval_500_circular | 13351 | 74.90 |
| geofence_eval_10_polygon_6v | 418067 | 2.39 |
| geofence_eval_50_polygon_6v | 84304 | 11.86 |
| processor_1k_fixes | 8810 | 113.51 |
| processor_1k_adaptive | 8292 | 120.60 |
| trip_manager_5k_waypoints | 74 | 13475.66 |
| schedule_parse | 2924789 | 0.34 |
| schedule_matches | 129418 | 7.73 |
| schedule_isWithin_5_entries | 120718 | 8.28 |
| adaptive_compute | 13681539 | 0.07 |
| location_fromMap | 1651831 | 0.61 |
| location_toMap | 662780 | 1.51 |
| location_fromMap_toMap_roundtrip | 485336 | 2.06 |
| location_copyWithCoords | 12253082 | 0.08 |
| geofence_fromMap_circular | 4157162 | 0.24 |
| geofence_fromMap_polygon | 1595907 | 0.63 |
| delta_encode_10 | 14372 | 69.58 |
| delta_decode_10 | 91852 | 10.89 |
| delta_encode_100 | 2525 | 396.08 |
| delta_decode_100 | 11070 | 90.34 |
| delta_encode_500 | 530 | 1887.24 |
| delta_decode_500 | 2243 | 445.79 |
| delta_roundtrip_100 | 2036 | 491.10 |
| battery_budget_single_sample | 8990141 | 0.11 |
| battery_budget_60_samples | 296137 | 3.38 |
| battery_budget_heavy_drain | 149396 | 6.69 |
| carbon_trip_100_locations | 92042 | 10.86 |
| carbon_onLocation | 4109912 | 0.24 |
| carbon_setActivity | 9956690 | 0.10 |
| carbon_cumulative_report | 2676314 | 0.37 |
| persist_decider_location | 20197630 | 0.05 |
| persist_decider_geofence | 20057293 | 0.05 |
| config_fromMap | 469056 | 2.13 |
| config_toMap | 133495 | 7.49 |
| config_roundtrip | 101999 | 9.80 |
| state_fromMap | 436488 | 2.29 |
| state_toMap | 126942 | 7.88 |
| route_context_toMap | 3046771 | 0.33 |
| route_context_fromMap | 2361909 | 0.42 |
| route_context_roundtrip | 1418161 | 0.71 |
| sync_body_context_toMap_50 | 8255319 | 0.12 |
| sync_body_context_fromMap_50 | 22821 | 43.82 |
| http_config_ssl_toMap | 802699 | 1.25 |
| http_config_ssl_fromMap | 3353256 | 0.30 |
| http_config_ssl_roundtrip | 659612 | 1.52 |


### 2026-05-22 — Commit 696c6dc

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7288028 | 0.14 |
| kalman_process_100_fixes | 96085 | 10.41 |
| kalman_process_1k_fixes | 9603 | 104.13 |
| kalman_reset | 6908057 | 0.14 |
| haversine_single | 8026179 | 0.12 |
| haversine_1k_pairs | 13939 | 71.74 |
| pip_4v | 13210896 | 0.08 |
| pip_10v | 9434547 | 0.11 |
| pip_50v | 3713804 | 0.27 |
| pip_100v | 2044494 | 0.49 |
| pip_500v | 419899 | 2.38 |
| geofence_eval_10_circular | 631021 | 1.58 |
| geofence_eval_100_circular | 69489 | 14.39 |
| geofence_eval_500_circular | 13459 | 74.30 |
| geofence_eval_10_polygon_6v | 414674 | 2.41 |
| geofence_eval_50_polygon_6v | 83514 | 11.97 |
| processor_1k_fixes | 8980 | 111.35 |
| processor_1k_adaptive | 8465 | 118.13 |
| trip_manager_5k_waypoints | 73 | 13614.49 |
| schedule_parse | 2914083 | 0.34 |
| schedule_matches | 130626 | 7.66 |
| schedule_isWithin_5_entries | 123505 | 8.10 |
| adaptive_compute | 13448509 | 0.07 |
| location_fromMap | 1735886 | 0.58 |
| location_toMap | 675945 | 1.48 |
| location_fromMap_toMap_roundtrip | 491553 | 2.03 |
| location_copyWithCoords | 12424701 | 0.08 |
| geofence_fromMap_circular | 4462875 | 0.22 |
| geofence_fromMap_polygon | 1613570 | 0.62 |
| delta_encode_10 | 14894 | 67.14 |
| delta_decode_10 | 93336 | 10.71 |
| delta_encode_100 | 2562 | 390.26 |
| delta_decode_100 | 10937 | 91.43 |
| delta_encode_500 | 551 | 1815.56 |
| delta_decode_500 | 2128 | 469.99 |
| delta_roundtrip_100 | 2099 | 476.39 |
| battery_budget_single_sample | 9289167 | 0.11 |
| battery_budget_60_samples | 294960 | 3.39 |
| battery_budget_heavy_drain | 148472 | 6.74 |
| carbon_trip_100_locations | 87758 | 11.40 |
| carbon_onLocation | 4100261 | 0.24 |
| carbon_setActivity | 9811452 | 0.10 |
| carbon_cumulative_report | 2754116 | 0.36 |
| persist_decider_location | 20343552 | 0.05 |
| persist_decider_geofence | 20416745 | 0.05 |
| config_fromMap | 486192 | 2.06 |
| config_toMap | 133675 | 7.48 |
| config_roundtrip | 104086 | 9.61 |
| state_fromMap | 456753 | 2.19 |
| state_toMap | 126727 | 7.89 |
| route_context_toMap | 3083294 | 0.32 |
| route_context_fromMap | 2402366 | 0.42 |
| route_context_roundtrip | 1443592 | 0.69 |
| sync_body_context_toMap_50 | 8305958 | 0.12 |
| sync_body_context_fromMap_50 | 22920 | 43.63 |
| http_config_ssl_toMap | 810991 | 1.23 |
| http_config_ssl_fromMap | 3321339 | 0.30 |
| http_config_ssl_roundtrip | 665157 | 1.50 |


### 2026-05-22 — Commit 5421e7a

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7315907 | 0.14 |
| kalman_process_100_fixes | 94556 | 10.58 |
| kalman_process_1k_fixes | 9530 | 104.93 |
| kalman_reset | 6794980 | 0.15 |
| haversine_single | 8042604 | 0.12 |
| haversine_1k_pairs | 13929 | 71.79 |
| pip_4v | 13226303 | 0.08 |
| pip_10v | 9866403 | 0.10 |
| pip_50v | 3704341 | 0.27 |
| pip_100v | 1997451 | 0.50 |
| pip_500v | 417289 | 2.40 |
| geofence_eval_10_circular | 645183 | 1.55 |
| geofence_eval_100_circular | 69872 | 14.31 |
| geofence_eval_500_circular | 13486 | 74.15 |
| geofence_eval_10_polygon_6v | 412891 | 2.42 |
| geofence_eval_50_polygon_6v | 82971 | 12.05 |
| processor_1k_fixes | 8816 | 113.43 |
| processor_1k_adaptive | 8031 | 124.52 |
| trip_manager_5k_waypoints | 72 | 13816.97 |
| schedule_parse | 2818461 | 0.35 |
| schedule_matches | 131305 | 7.62 |
| schedule_isWithin_5_entries | 122750 | 8.15 |
| adaptive_compute | 13269985 | 0.08 |
| location_fromMap | 1723016 | 0.58 |
| location_toMap | 672198 | 1.49 |
| location_fromMap_toMap_roundtrip | 480505 | 2.08 |
| location_copyWithCoords | 12024699 | 0.08 |
| geofence_fromMap_circular | 4410034 | 0.23 |
| geofence_fromMap_polygon | 1613917 | 0.62 |
| delta_encode_10 | 14413 | 69.38 |
| delta_decode_10 | 91893 | 10.88 |
| delta_encode_100 | 2512 | 398.12 |
| delta_decode_100 | 10859 | 92.09 |
| delta_encode_500 | 511 | 1958.59 |
| delta_decode_500 | 2061 | 485.25 |
| delta_roundtrip_100 | 2072 | 482.72 |
| battery_budget_single_sample | 9063365 | 0.11 |
| battery_budget_60_samples | 291151 | 3.43 |
| battery_budget_heavy_drain | 146683 | 6.82 |
| carbon_trip_100_locations | 87297 | 11.46 |
| carbon_onLocation | 4118633 | 0.24 |
| carbon_setActivity | 9589520 | 0.10 |
| carbon_cumulative_report | 2705640 | 0.37 |
| persist_decider_location | 20242344 | 0.05 |
| persist_decider_geofence | 20256994 | 0.05 |
| config_fromMap | 457792 | 2.18 |
| config_toMap | 130415 | 7.67 |
| config_roundtrip | 102072 | 9.80 |
| state_fromMap | 434296 | 2.30 |
| state_toMap | 124951 | 8.00 |
| route_context_toMap | 3055658 | 0.33 |
| route_context_fromMap | 2401284 | 0.42 |
| route_context_roundtrip | 1441497 | 0.69 |
| sync_body_context_toMap_50 | 8450437 | 0.12 |
| sync_body_context_fromMap_50 | 23053 | 43.38 |
| http_config_ssl_toMap | 787956 | 1.27 |
| http_config_ssl_fromMap | 3336796 | 0.30 |
| http_config_ssl_roundtrip | 647890 | 1.54 |


### 2026-05-22 — Commit bea576b

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 6743938 | 0.15 |
| kalman_process_100_fixes | 101886 | 9.81 |
| kalman_process_1k_fixes | 10271 | 97.36 |
| kalman_reset | 6234037 | 0.16 |
| haversine_single | 7779724 | 0.13 |
| haversine_1k_pairs | 13522 | 73.95 |
| pip_4v | 12673017 | 0.08 |
| pip_10v | 9618210 | 0.10 |
| pip_50v | 3784413 | 0.26 |
| pip_100v | 2036028 | 0.49 |
| pip_500v | 379151 | 2.64 |
| geofence_eval_10_circular | 653564 | 1.53 |
| geofence_eval_100_circular | 69810 | 14.32 |
| geofence_eval_500_circular | 13657 | 73.22 |
| geofence_eval_10_polygon_6v | 416009 | 2.40 |
| geofence_eval_50_polygon_6v | 83252 | 12.01 |
| processor_1k_fixes | 9130 | 109.53 |
| processor_1k_adaptive | 8575 | 116.61 |
| trip_manager_5k_waypoints | 63 | 15968.44 |
| schedule_parse | 2878427 | 0.35 |
| schedule_matches | 113939 | 8.78 |
| schedule_isWithin_5_entries | 106699 | 9.37 |
| adaptive_compute | 12329418 | 0.08 |
| location_fromMap | 1654211 | 0.60 |
| location_toMap | 674127 | 1.48 |
| location_fromMap_toMap_roundtrip | 488414 | 2.05 |
| location_copyWithCoords | 11439986 | 0.09 |
| geofence_fromMap_circular | 4311088 | 0.23 |
| geofence_fromMap_polygon | 1608072 | 0.62 |
| delta_encode_10 | 15016 | 66.60 |
| delta_decode_10 | 91138 | 10.97 |
| delta_encode_100 | 2630 | 380.18 |
| delta_decode_100 | 11108 | 90.02 |
| delta_encode_500 | 515 | 1941.83 |
| delta_decode_500 | 2193 | 455.90 |
| delta_roundtrip_100 | 2099 | 476.33 |
| battery_budget_single_sample | 8574163 | 0.12 |
| battery_budget_60_samples | 276756 | 3.61 |
| battery_budget_heavy_drain | 138191 | 7.24 |
| carbon_trip_100_locations | 85948 | 11.63 |
| carbon_onLocation | 4118938 | 0.24 |
| carbon_setActivity | 9541281 | 0.10 |
| carbon_cumulative_report | 2681653 | 0.37 |
| persist_decider_location | 18710361 | 0.05 |
| persist_decider_geofence | 18694408 | 0.05 |
| config_fromMap | 482970 | 2.07 |
| config_toMap | 141558 | 7.06 |
| config_roundtrip | 107240 | 9.32 |
| state_fromMap | 456043 | 2.19 |
| state_toMap | 134934 | 7.41 |
| route_context_toMap | 3024636 | 0.33 |
| route_context_fromMap | 2279461 | 0.44 |
| route_context_roundtrip | 1389782 | 0.72 |
| sync_body_context_toMap_50 | 8201397 | 0.12 |
| sync_body_context_fromMap_50 | 22072 | 45.31 |
| http_config_ssl_toMap | 810769 | 1.23 |
| http_config_ssl_fromMap | 3253145 | 0.31 |
| http_config_ssl_roundtrip | 661966 | 1.51 |


### 2026-05-22 — Commit a5cf597

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 6955328 | 0.14 |
| kalman_process_100_fixes | 102336 | 9.77 |
| kalman_process_1k_fixes | 10340 | 96.71 |
| kalman_reset | 6513321 | 0.15 |
| haversine_single | 8011146 | 0.12 |
| haversine_1k_pairs | 13595 | 73.56 |
| pip_4v | 12047944 | 0.08 |
| pip_10v | 9574581 | 0.10 |
| pip_50v | 3717456 | 0.27 |
| pip_100v | 1993873 | 0.50 |
| pip_500v | 381471 | 2.62 |
| geofence_eval_10_circular | 657600 | 1.52 |
| geofence_eval_100_circular | 69548 | 14.38 |
| geofence_eval_500_circular | 13460 | 74.30 |
| geofence_eval_10_polygon_6v | 418571 | 2.39 |
| geofence_eval_50_polygon_6v | 84212 | 11.87 |
| processor_1k_fixes | 9449 | 105.83 |
| processor_1k_adaptive | 8634 | 115.82 |
| trip_manager_5k_waypoints | 63 | 15931.17 |
| schedule_parse | 2887511 | 0.35 |
| schedule_matches | 112713 | 8.87 |
| schedule_isWithin_5_entries | 107907 | 9.27 |
| adaptive_compute | 12717612 | 0.08 |
| location_fromMap | 1652254 | 0.61 |
| location_toMap | 678545 | 1.47 |
| location_fromMap_toMap_roundtrip | 489902 | 2.04 |
| location_copyWithCoords | 11494978 | 0.09 |
| geofence_fromMap_circular | 4350061 | 0.23 |
| geofence_fromMap_polygon | 1619938 | 0.62 |
| delta_encode_10 | 15196 | 65.81 |
| delta_decode_10 | 92983 | 10.75 |
| delta_encode_100 | 2650 | 377.39 |
| delta_decode_100 | 11213 | 89.18 |
| delta_encode_500 | 523 | 1911.88 |
| delta_decode_500 | 2262 | 442.00 |
| delta_roundtrip_100 | 2166 | 461.73 |
| battery_budget_single_sample | 8591900 | 0.12 |
| battery_budget_60_samples | 283620 | 3.53 |
| battery_budget_heavy_drain | 142501 | 7.02 |
| carbon_trip_100_locations | 86395 | 11.57 |
| carbon_onLocation | 4093833 | 0.24 |
| carbon_setActivity | 9645732 | 0.10 |
| carbon_cumulative_report | 2695741 | 0.37 |
| persist_decider_location | 19194509 | 0.05 |
| persist_decider_geofence | 19289942 | 0.05 |
| config_fromMap | 496559 | 2.01 |
| config_toMap | 142234 | 7.03 |
| config_roundtrip | 110170 | 9.08 |
| state_fromMap | 454622 | 2.20 |
| state_toMap | 136178 | 7.34 |
| route_context_toMap | 3046998 | 0.33 |
| route_context_fromMap | 2371714 | 0.42 |
| route_context_roundtrip | 1451007 | 0.69 |
| sync_body_context_toMap_50 | 8270292 | 0.12 |
| sync_body_context_fromMap_50 | 22317 | 44.81 |
| http_config_ssl_toMap | 815916 | 1.23 |
| http_config_ssl_fromMap | 3259793 | 0.31 |
| http_config_ssl_roundtrip | 665143 | 1.50 |


### 2026-05-22 — Commit db61167

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7136861 | 0.14 |
| kalman_process_100_fixes | 95386 | 10.48 |
| kalman_process_1k_fixes | 9504 | 105.22 |
| kalman_reset | 6831639 | 0.15 |
| haversine_single | 8039316 | 0.12 |
| haversine_1k_pairs | 13915 | 71.87 |
| pip_4v | 13290443 | 0.08 |
| pip_10v | 9727098 | 0.10 |
| pip_50v | 3771188 | 0.27 |
| pip_100v | 2053180 | 0.49 |
| pip_500v | 406372 | 2.46 |
| geofence_eval_10_circular | 639542 | 1.56 |
| geofence_eval_100_circular | 69778 | 14.33 |
| geofence_eval_500_circular | 13417 | 74.53 |
| geofence_eval_10_polygon_6v | 414636 | 2.41 |
| geofence_eval_50_polygon_6v | 84489 | 11.84 |
| processor_1k_fixes | 8966 | 111.53 |
| processor_1k_adaptive | 8395 | 119.12 |
| trip_manager_5k_waypoints | 74 | 13563.39 |
| schedule_parse | 2922187 | 0.34 |
| schedule_matches | 130230 | 7.68 |
| schedule_isWithin_5_entries | 123615 | 8.09 |
| adaptive_compute | 14049996 | 0.07 |
| location_fromMap | 1701773 | 0.59 |
| location_toMap | 663335 | 1.51 |
| location_fromMap_toMap_roundtrip | 482519 | 2.07 |
| location_copyWithCoords | 12298395 | 0.08 |
| geofence_fromMap_circular | 4489289 | 0.22 |
| geofence_fromMap_polygon | 1634299 | 0.61 |
| delta_encode_10 | 14595 | 68.51 |
| delta_decode_10 | 90951 | 10.99 |
| delta_encode_100 | 2567 | 389.55 |
| delta_decode_100 | 10841 | 92.24 |
| delta_encode_500 | 538 | 1858.04 |
| delta_decode_500 | 2126 | 470.32 |
| delta_roundtrip_100 | 2098 | 476.55 |
| battery_budget_single_sample | 9130748 | 0.11 |
| battery_budget_60_samples | 283087 | 3.53 |
| battery_budget_heavy_drain | 141151 | 7.08 |
| carbon_trip_100_locations | 89891 | 11.12 |
| carbon_onLocation | 4240035 | 0.24 |
| carbon_setActivity | 9757220 | 0.10 |
| carbon_cumulative_report | 2750224 | 0.36 |
| persist_decider_location | 20011241 | 0.05 |
| persist_decider_geofence | 20166443 | 0.05 |
| config_fromMap | 494577 | 2.02 |
| config_toMap | 139950 | 7.15 |
| config_roundtrip | 108904 | 9.18 |
| state_fromMap | 464810 | 2.15 |
| state_toMap | 135172 | 7.40 |
| route_context_toMap | 3049988 | 0.33 |
| route_context_fromMap | 2424968 | 0.41 |
| route_context_roundtrip | 1452099 | 0.69 |
| sync_body_context_toMap_50 | 8329418 | 0.12 |
| sync_body_context_fromMap_50 | 21814 | 45.84 |
| http_config_ssl_toMap | 798673 | 1.25 |
| http_config_ssl_fromMap | 3354346 | 0.30 |
| http_config_ssl_roundtrip | 648544 | 1.54 |


### 2026-05-22 — Commit c15ff5f

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 9121313 | 0.11 |
| kalman_process_100_fixes | 131945 | 7.58 |
| kalman_process_1k_fixes | 12984 | 77.02 |
| kalman_reset | 8449045 | 0.12 |
| haversine_single | 10371852 | 0.10 |
| haversine_1k_pairs | 17742 | 56.36 |
| pip_4v | 16428742 | 0.06 |
| pip_10v | 12622312 | 0.08 |
| pip_50v | 4797721 | 0.21 |
| pip_100v | 2634976 | 0.38 |
| pip_500v | 501633 | 1.99 |
| geofence_eval_10_circular | 847204 | 1.18 |
| geofence_eval_100_circular | 90132 | 11.09 |
| geofence_eval_500_circular | 17998 | 55.56 |
| geofence_eval_10_polygon_6v | 542933 | 1.84 |
| geofence_eval_50_polygon_6v | 109795 | 9.11 |
| processor_1k_fixes | 12062 | 82.91 |
| processor_1k_adaptive | 10622 | 94.14 |
| trip_manager_5k_waypoints | 81 | 12276.39 |
| schedule_parse | 3730150 | 0.27 |
| schedule_matches | 144422 | 6.92 |
| schedule_isWithin_5_entries | 138473 | 7.22 |
| adaptive_compute | 16240455 | 0.06 |
| location_fromMap | 2086795 | 0.48 |
| location_toMap | 876300 | 1.14 |
| location_fromMap_toMap_roundtrip | 632411 | 1.58 |
| location_copyWithCoords | 14872175 | 0.07 |
| geofence_fromMap_circular | 5525831 | 0.18 |
| geofence_fromMap_polygon | 2076599 | 0.48 |
| delta_encode_10 | 19416 | 51.50 |
| delta_decode_10 | 120313 | 8.31 |
| delta_encode_100 | 3434 | 291.19 |
| delta_decode_100 | 14514 | 68.90 |
| delta_encode_500 | 680 | 1470.11 |
| delta_decode_500 | 2896 | 345.32 |
| delta_roundtrip_100 | 2779 | 359.78 |
| battery_budget_single_sample | 11178739 | 0.09 |
| battery_budget_60_samples | 370173 | 2.70 |
| battery_budget_heavy_drain | 183823 | 5.44 |
| carbon_trip_100_locations | 113012 | 8.85 |
| carbon_onLocation | 5395142 | 0.19 |
| carbon_setActivity | 12452149 | 0.08 |
| carbon_cumulative_report | 3448873 | 0.29 |
| persist_decider_location | 24112238 | 0.04 |
| persist_decider_geofence | 24036124 | 0.04 |
| config_fromMap | 637319 | 1.57 |
| config_toMap | 186203 | 5.37 |
| config_roundtrip | 141213 | 7.08 |
| state_fromMap | 594756 | 1.68 |
| state_toMap | 177358 | 5.64 |
| route_context_toMap | 3773579 | 0.27 |
| route_context_fromMap | 2927230 | 0.34 |
| route_context_roundtrip | 1812665 | 0.55 |
| sync_body_context_toMap_50 | 10728072 | 0.09 |
| sync_body_context_fromMap_50 | 28596 | 34.97 |
| http_config_ssl_toMap | 1054030 | 0.95 |
| http_config_ssl_fromMap | 4203288 | 0.24 |
| http_config_ssl_roundtrip | 863839 | 1.16 |


### 2026-05-22 — Commit 26bc7f9

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 6893348 | 0.15 |
| kalman_process_100_fixes | 94606 | 10.57 |
| kalman_process_1k_fixes | 9408 | 106.29 |
| kalman_reset | 6735765 | 0.15 |
| haversine_single | 8851495 | 0.11 |
| haversine_1k_pairs | 18314 | 54.60 |
| pip_4v | 13054021 | 0.08 |
| pip_10v | 10456959 | 0.10 |
| pip_50v | 4049617 | 0.25 |
| pip_100v | 2200966 | 0.45 |
| pip_500v | 447486 | 2.23 |
| geofence_eval_10_circular | 659732 | 1.52 |
| geofence_eval_100_circular | 74054 | 13.50 |
| geofence_eval_500_circular | 14193 | 70.46 |
| geofence_eval_10_polygon_6v | 429122 | 2.33 |
| geofence_eval_50_polygon_6v | 85616 | 11.68 |
| processor_1k_fixes | 10724 | 93.25 |
| processor_1k_adaptive | 10073 | 99.27 |
| trip_manager_5k_waypoints | 134 | 7488.65 |
| schedule_parse | 2944653 | 0.34 |
| schedule_matches | 253920 | 3.94 |
| schedule_isWithin_5_entries | 224033 | 4.46 |
| adaptive_compute | 11985351 | 0.08 |
| location_fromMap | 1574587 | 0.64 |
| location_toMap | 574004 | 1.74 |
| location_fromMap_toMap_roundtrip | 400729 | 2.50 |
| location_copyWithCoords | 10709934 | 0.09 |
| geofence_fromMap_circular | 4241740 | 0.24 |
| geofence_fromMap_polygon | 1509998 | 0.66 |
| delta_encode_10 | 15235 | 65.64 |
| delta_decode_10 | 81199 | 12.32 |
| delta_encode_100 | 2563 | 390.23 |
| delta_decode_100 | 9716 | 102.92 |
| delta_encode_500 | 484 | 2065.32 |
| delta_decode_500 | 2030 | 492.72 |
| delta_roundtrip_100 | 2035 | 491.28 |
| battery_budget_single_sample | 8377199 | 0.12 |
| battery_budget_60_samples | 287567 | 3.48 |
| battery_budget_heavy_drain | 146098 | 6.84 |
| carbon_trip_100_locations | 96923 | 10.32 |
| carbon_onLocation | 4099682 | 0.24 |
| carbon_setActivity | 9870654 | 0.10 |
| carbon_cumulative_report | 2537931 | 0.39 |
| persist_decider_location | 20535695 | 0.05 |
| persist_decider_geofence | 20631592 | 0.05 |
| config_fromMap | 472278 | 2.12 |
| config_toMap | 131527 | 7.60 |
| config_roundtrip | 99403 | 10.06 |
| state_fromMap | 435286 | 2.30 |
| state_toMap | 125804 | 7.95 |
| route_context_toMap | 2734594 | 0.37 |
| route_context_fromMap | 2225456 | 0.45 |
| route_context_roundtrip | 1247668 | 0.80 |
| sync_body_context_toMap_50 | 8324956 | 0.12 |
| sync_body_context_fromMap_50 | 20239 | 49.41 |
| http_config_ssl_toMap | 718452 | 1.39 |
| http_config_ssl_fromMap | 3186225 | 0.31 |
| http_config_ssl_roundtrip | 573469 | 1.74 |


### 2026-05-22 — Commit 9ec96af

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7053854 | 0.14 |
| kalman_process_100_fixes | 99381 | 10.06 |
| kalman_process_1k_fixes | 9826 | 101.77 |
| kalman_reset | 6724622 | 0.15 |
| haversine_single | 7438215 | 0.13 |
| haversine_1k_pairs | 12066 | 82.88 |
| pip_4v | 13332574 | 0.08 |
| pip_10v | 9905294 | 0.10 |
| pip_50v | 4033164 | 0.25 |
| pip_100v | 2153466 | 0.46 |
| pip_500v | 417918 | 2.39 |
| geofence_eval_10_circular | 625387 | 1.60 |
| geofence_eval_100_circular | 68474 | 14.60 |
| geofence_eval_500_circular | 12992 | 76.97 |
| geofence_eval_10_polygon_6v | 412824 | 2.42 |
| geofence_eval_50_polygon_6v | 81838 | 12.22 |
| processor_1k_fixes | 8251 | 121.20 |
| processor_1k_adaptive | 7915 | 126.34 |
| trip_manager_5k_waypoints | 71 | 14162.38 |
| schedule_parse | 2878354 | 0.35 |
| schedule_matches | 127953 | 7.82 |
| schedule_isWithin_5_entries | 119796 | 8.35 |
| adaptive_compute | 13976413 | 0.07 |
| location_fromMap | 1735301 | 0.58 |
| location_toMap | 668620 | 1.50 |
| location_fromMap_toMap_roundtrip | 478117 | 2.09 |
| location_copyWithCoords | 12246051 | 0.08 |
| geofence_fromMap_circular | 4461060 | 0.22 |
| geofence_fromMap_polygon | 1635902 | 0.61 |
| delta_encode_10 | 14726 | 67.91 |
| delta_decode_10 | 91020 | 10.99 |
| delta_encode_100 | 2553 | 391.63 |
| delta_decode_100 | 10727 | 93.23 |
| delta_encode_500 | 523 | 1913.06 |
| delta_decode_500 | 2165 | 461.91 |
| delta_roundtrip_100 | 2069 | 483.33 |
| battery_budget_single_sample | 9102386 | 0.11 |
| battery_budget_60_samples | 289924 | 3.45 |
| battery_budget_heavy_drain | 146844 | 6.81 |
| carbon_trip_100_locations | 84809 | 11.79 |
| carbon_onLocation | 3939247 | 0.25 |
| carbon_setActivity | 9793470 | 0.10 |
| carbon_cumulative_report | 2735755 | 0.37 |
| persist_decider_location | 20285107 | 0.05 |
| persist_decider_geofence | 20373344 | 0.05 |
| config_fromMap | 509747 | 1.96 |
| config_toMap | 142470 | 7.02 |
| config_roundtrip | 109023 | 9.17 |
| state_fromMap | 468840 | 2.13 |
| state_toMap | 137633 | 7.27 |
| route_context_toMap | 3046931 | 0.33 |
| route_context_fromMap | 2316578 | 0.43 |
| route_context_roundtrip | 1378938 | 0.73 |
| sync_body_context_toMap_50 | 8422380 | 0.12 |
| sync_body_context_fromMap_50 | 22981 | 43.51 |
| http_config_ssl_toMap | 801185 | 1.25 |
| http_config_ssl_fromMap | 3207002 | 0.31 |
| http_config_ssl_roundtrip | 644946 | 1.55 |


