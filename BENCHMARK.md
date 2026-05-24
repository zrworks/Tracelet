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

### 2026-05-24 — Commit 34bf063

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7267852 | 0.14 |
| kalman_process_100_fixes | 94325 | 10.60 |
| kalman_process_1k_fixes | 9044 | 110.57 |
| kalman_reset | 6873392 | 0.15 |
| haversine_single | 7884805 | 0.13 |
| haversine_1k_pairs | 13557 | 73.76 |
| pip_4v | 12105604 | 0.08 |
| pip_10v | 9064241 | 0.11 |
| pip_50v | 3772668 | 0.27 |
| pip_100v | 2063598 | 0.48 |
| pip_500v | 416074 | 2.40 |
| geofence_eval_10_circular | 642258 | 1.56 |
| geofence_eval_100_circular | 69320 | 14.43 |
| geofence_eval_500_circular | 13232 | 75.57 |
| geofence_eval_10_polygon_6v | 415916 | 2.40 |
| geofence_eval_50_polygon_6v | 84974 | 11.77 |
| processor_1k_fixes | 8842 | 113.10 |
| processor_1k_adaptive | 8177 | 122.29 |
| trip_manager_5k_waypoints | 72 | 13888.14 |
| schedule_parse | 2844776 | 0.35 |
| schedule_matches | 127622 | 7.84 |
| schedule_isWithin_5_entries | 121903 | 8.20 |
| adaptive_compute | 13901199 | 0.07 |
| location_fromMap | 1608689 | 0.62 |
| location_toMap | 656933 | 1.52 |
| location_fromMap_toMap_roundtrip | 471042 | 2.12 |
| location_copyWithCoords | 11974853 | 0.08 |
| geofence_fromMap_circular | 4390423 | 0.23 |
| geofence_fromMap_polygon | 1619292 | 0.62 |
| delta_encode_10 | 14554 | 68.71 |
| delta_decode_10 | 90455 | 11.06 |
| delta_encode_100 | 2538 | 394.05 |
| delta_decode_100 | 10537 | 94.90 |
| delta_encode_500 | 511 | 1958.79 |
| delta_decode_500 | 2210 | 452.47 |
| delta_roundtrip_100 | 2045 | 488.96 |
| battery_budget_single_sample | 9112740 | 0.11 |
| battery_budget_60_samples | 290257 | 3.45 |
| battery_budget_heavy_drain | 148149 | 6.75 |
| carbon_trip_100_locations | 67518 | 14.81 |
| carbon_onLocation | 4094265 | 0.24 |
| carbon_setActivity | 9801728 | 0.10 |
| carbon_cumulative_report | 2616604 | 0.38 |
| persist_decider_location | 19907096 | 0.05 |
| persist_decider_geofence | 19913466 | 0.05 |
| config_fromMap | 473407 | 2.11 |
| config_toMap | 127530 | 7.84 |
| config_roundtrip | 99475 | 10.05 |
| state_fromMap | 444950 | 2.25 |
| state_toMap | 121866 | 8.21 |
| route_context_toMap | 2950091 | 0.34 |
| route_context_fromMap | 2356016 | 0.42 |
| route_context_roundtrip | 1408093 | 0.71 |
| sync_body_context_toMap_50 | 8540636 | 0.12 |
| sync_body_context_fromMap_50 | 22680 | 44.09 |
| http_config_ssl_toMap | 776555 | 1.29 |
| http_config_ssl_fromMap | 3272603 | 0.31 |
| http_config_ssl_roundtrip | 645755 | 1.55 |


### 2026-05-24 — Commit 46effe5

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7118144 | 0.14 |
| kalman_process_100_fixes | 95315 | 10.49 |
| kalman_process_1k_fixes | 9317 | 107.33 |
| kalman_reset | 6824113 | 0.15 |
| haversine_single | 8111930 | 0.12 |
| haversine_1k_pairs | 13822 | 72.35 |
| pip_4v | 13212683 | 0.08 |
| pip_10v | 10048962 | 0.10 |
| pip_50v | 3820597 | 0.26 |
| pip_100v | 2057612 | 0.49 |
| pip_500v | 423757 | 2.36 |
| geofence_eval_10_circular | 637224 | 1.57 |
| geofence_eval_100_circular | 69992 | 14.29 |
| geofence_eval_500_circular | 13444 | 74.38 |
| geofence_eval_10_polygon_6v | 413752 | 2.42 |
| geofence_eval_50_polygon_6v | 84328 | 11.86 |
| processor_1k_fixes | 8985 | 111.30 |
| processor_1k_adaptive | 8566 | 116.73 |
| trip_manager_5k_waypoints | 70 | 14208.15 |
| schedule_parse | 2920020 | 0.34 |
| schedule_matches | 127405 | 7.85 |
| schedule_isWithin_5_entries | 121515 | 8.23 |
| adaptive_compute | 13855765 | 0.07 |
| location_fromMap | 1728849 | 0.58 |
| location_toMap | 665014 | 1.50 |
| location_fromMap_toMap_roundtrip | 483539 | 2.07 |
| location_copyWithCoords | 12144046 | 0.08 |
| geofence_fromMap_circular | 4500666 | 0.22 |
| geofence_fromMap_polygon | 1643151 | 0.61 |
| delta_encode_10 | 14219 | 70.33 |
| delta_decode_10 | 90885 | 11.00 |
| delta_encode_100 | 2454 | 407.58 |
| delta_decode_100 | 10491 | 95.32 |
| delta_encode_500 | 510 | 1961.02 |
| delta_decode_500 | 2144 | 466.42 |
| delta_roundtrip_100 | 2017 | 495.74 |
| battery_budget_single_sample | 8806650 | 0.11 |
| battery_budget_60_samples | 293749 | 3.40 |
| battery_budget_heavy_drain | 147054 | 6.80 |
| carbon_trip_100_locations | 88528 | 11.30 |
| carbon_onLocation | 4227004 | 0.24 |
| carbon_setActivity | 9949844 | 0.10 |
| carbon_cumulative_report | 2648040 | 0.38 |
| persist_decider_location | 20244602 | 0.05 |
| persist_decider_geofence | 20103739 | 0.05 |
| config_fromMap | 456959 | 2.19 |
| config_toMap | 132024 | 7.57 |
| config_roundtrip | 102186 | 9.79 |
| state_fromMap | 435465 | 2.30 |
| state_toMap | 126730 | 7.89 |
| route_context_toMap | 3035633 | 0.33 |
| route_context_fromMap | 2383560 | 0.42 |
| route_context_roundtrip | 1438538 | 0.70 |
| sync_body_context_toMap_50 | 8264641 | 0.12 |
| sync_body_context_fromMap_50 | 22624 | 44.20 |
| http_config_ssl_toMap | 805668 | 1.24 |
| http_config_ssl_fromMap | 3355351 | 0.30 |
| http_config_ssl_roundtrip | 665739 | 1.50 |


### 2026-05-24 — Commit 719bb89

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7493126 | 0.13 |
| kalman_process_100_fixes | 94475 | 10.58 |
| kalman_process_1k_fixes | 9147 | 109.33 |
| kalman_reset | 6824668 | 0.15 |
| haversine_single | 7846250 | 0.13 |
| haversine_1k_pairs | 13594 | 73.56 |
| pip_4v | 13040603 | 0.08 |
| pip_10v | 9706423 | 0.10 |
| pip_50v | 3753948 | 0.27 |
| pip_100v | 1980224 | 0.50 |
| pip_500v | 419974 | 2.38 |
| geofence_eval_10_circular | 643226 | 1.55 |
| geofence_eval_100_circular | 70111 | 14.26 |
| geofence_eval_500_circular | 13385 | 74.71 |
| geofence_eval_10_polygon_6v | 419923 | 2.38 |
| geofence_eval_50_polygon_6v | 84149 | 11.88 |
| processor_1k_fixes | 8967 | 111.52 |
| processor_1k_adaptive | 8411 | 118.89 |
| trip_manager_5k_waypoints | 71 | 14059.45 |
| schedule_parse | 2882960 | 0.35 |
| schedule_matches | 128207 | 7.80 |
| schedule_isWithin_5_entries | 120423 | 8.30 |
| adaptive_compute | 13846557 | 0.07 |
| location_fromMap | 1712273 | 0.58 |
| location_toMap | 667384 | 1.50 |
| location_fromMap_toMap_roundtrip | 492362 | 2.03 |
| location_copyWithCoords | 12038644 | 0.08 |
| geofence_fromMap_circular | 4513010 | 0.22 |
| geofence_fromMap_polygon | 1623385 | 0.62 |
| delta_encode_10 | 14565 | 68.66 |
| delta_decode_10 | 90152 | 11.09 |
| delta_encode_100 | 2512 | 398.12 |
| delta_decode_100 | 10520 | 95.05 |
| delta_encode_500 | 519 | 1925.61 |
| delta_decode_500 | 2253 | 443.88 |
| delta_roundtrip_100 | 2044 | 489.31 |
| battery_budget_single_sample | 9226038 | 0.11 |
| battery_budget_60_samples | 293168 | 3.41 |
| battery_budget_heavy_drain | 148687 | 6.73 |
| carbon_trip_100_locations | 86762 | 11.53 |
| carbon_onLocation | 3997721 | 0.25 |
| carbon_setActivity | 9690798 | 0.10 |
| carbon_cumulative_report | 2717591 | 0.37 |
| persist_decider_location | 20184597 | 0.05 |
| persist_decider_geofence | 20179514 | 0.05 |
| config_fromMap | 473191 | 2.11 |
| config_toMap | 132428 | 7.55 |
| config_roundtrip | 101682 | 9.83 |
| state_fromMap | 444201 | 2.25 |
| state_toMap | 125560 | 7.96 |
| route_context_toMap | 3059877 | 0.33 |
| route_context_fromMap | 2395330 | 0.42 |
| route_context_roundtrip | 1434341 | 0.70 |
| sync_body_context_toMap_50 | 8557687 | 0.12 |
| sync_body_context_fromMap_50 | 22928 | 43.62 |
| http_config_ssl_toMap | 806545 | 1.24 |
| http_config_ssl_fromMap | 3261620 | 0.31 |
| http_config_ssl_roundtrip | 664674 | 1.50 |


### 2026-05-24 — Commit 7ef20cc

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 6943837 | 0.14 |
| kalman_process_100_fixes | 96520 | 10.36 |
| kalman_process_1k_fixes | 9593 | 104.24 |
| kalman_reset | 6606856 | 0.15 |
| haversine_single | 7628117 | 0.13 |
| haversine_1k_pairs | 14006 | 71.40 |
| pip_4v | 12326671 | 0.08 |
| pip_10v | 9293658 | 0.11 |
| pip_50v | 3672233 | 0.27 |
| pip_100v | 2038954 | 0.49 |
| pip_500v | 424789 | 2.35 |
| geofence_eval_10_circular | 635886 | 1.57 |
| geofence_eval_100_circular | 70553 | 14.17 |
| geofence_eval_500_circular | 13373 | 74.78 |
| geofence_eval_10_polygon_6v | 418962 | 2.39 |
| geofence_eval_50_polygon_6v | 84625 | 11.82 |
| processor_1k_fixes | 8860 | 112.87 |
| processor_1k_adaptive | 8485 | 117.85 |
| trip_manager_5k_waypoints | 73 | 13757.00 |
| schedule_parse | 2827629 | 0.35 |
| schedule_matches | 129824 | 7.70 |
| schedule_isWithin_5_entries | 123811 | 8.08 |
| adaptive_compute | 12517072 | 0.08 |
| location_fromMap | 1701957 | 0.59 |
| location_toMap | 672301 | 1.49 |
| location_fromMap_toMap_roundtrip | 489720 | 2.04 |
| location_copyWithCoords | 11140739 | 0.09 |
| geofence_fromMap_circular | 4365710 | 0.23 |
| geofence_fromMap_polygon | 1600187 | 0.62 |
| delta_encode_10 | 14489 | 69.02 |
| delta_decode_10 | 92563 | 10.80 |
| delta_encode_100 | 2503 | 399.50 |
| delta_decode_100 | 10868 | 92.02 |
| delta_encode_500 | 524 | 1908.03 |
| delta_decode_500 | 2100 | 476.17 |
| delta_roundtrip_100 | 2061 | 485.30 |
| battery_budget_single_sample | 8218277 | 0.12 |
| battery_budget_60_samples | 280063 | 3.57 |
| battery_budget_heavy_drain | 141341 | 7.08 |
| carbon_trip_100_locations | 87135 | 11.48 |
| carbon_onLocation | 3984096 | 0.25 |
| carbon_setActivity | 9321155 | 0.11 |
| carbon_cumulative_report | 2688099 | 0.37 |
| persist_decider_location | 17602947 | 0.06 |
| persist_decider_geofence | 17597251 | 0.06 |
| config_fromMap | 496668 | 2.01 |
| config_toMap | 134672 | 7.43 |
| config_roundtrip | 105366 | 9.49 |
| state_fromMap | 467629 | 2.14 |
| state_toMap | 127899 | 7.82 |
| route_context_toMap | 3082360 | 0.32 |
| route_context_fromMap | 2378920 | 0.42 |
| route_context_roundtrip | 1448233 | 0.69 |
| sync_body_context_toMap_50 | 8329118 | 0.12 |
| sync_body_context_fromMap_50 | 23267 | 42.98 |
| http_config_ssl_toMap | 810052 | 1.23 |
| http_config_ssl_fromMap | 3255985 | 0.31 |
| http_config_ssl_roundtrip | 635944 | 1.57 |


### 2026-05-24 — Commit e84ecb8

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7548126 | 0.13 |
| kalman_process_100_fixes | 97036 | 10.31 |
| kalman_process_1k_fixes | 9599 | 104.17 |
| kalman_reset | 6757627 | 0.15 |
| haversine_single | 7932062 | 0.13 |
| haversine_1k_pairs | 13629 | 73.37 |
| pip_4v | 13357988 | 0.07 |
| pip_10v | 10122710 | 0.10 |
| pip_50v | 3777568 | 0.26 |
| pip_100v | 2081105 | 0.48 |
| pip_500v | 428376 | 2.33 |
| geofence_eval_10_circular | 643413 | 1.55 |
| geofence_eval_100_circular | 70482 | 14.19 |
| geofence_eval_500_circular | 13293 | 75.23 |
| geofence_eval_10_polygon_6v | 415217 | 2.41 |
| geofence_eval_50_polygon_6v | 84908 | 11.78 |
| processor_1k_fixes | 9032 | 110.71 |
| processor_1k_adaptive | 8455 | 118.27 |
| trip_manager_5k_waypoints | 72 | 13877.59 |
| schedule_parse | 2908670 | 0.34 |
| schedule_matches | 128166 | 7.80 |
| schedule_isWithin_5_entries | 122190 | 8.18 |
| adaptive_compute | 13602776 | 0.07 |
| location_fromMap | 1734615 | 0.58 |
| location_toMap | 678229 | 1.47 |
| location_fromMap_toMap_roundtrip | 494276 | 2.02 |
| location_copyWithCoords | 12228625 | 0.08 |
| geofence_fromMap_circular | 4540260 | 0.22 |
| geofence_fromMap_polygon | 1642097 | 0.61 |
| delta_encode_10 | 14467 | 69.12 |
| delta_decode_10 | 92616 | 10.80 |
| delta_encode_100 | 2537 | 394.14 |
| delta_decode_100 | 10918 | 91.59 |
| delta_encode_500 | 528 | 1894.91 |
| delta_decode_500 | 2177 | 459.27 |
| delta_roundtrip_100 | 2038 | 490.58 |
| battery_budget_single_sample | 8901596 | 0.11 |
| battery_budget_60_samples | 292651 | 3.42 |
| battery_budget_heavy_drain | 148958 | 6.71 |
| carbon_trip_100_locations | 90314 | 11.07 |
| carbon_onLocation | 4043178 | 0.25 |
| carbon_setActivity | 10020498 | 0.10 |
| carbon_cumulative_report | 2757706 | 0.36 |
| persist_decider_location | 20216291 | 0.05 |
| persist_decider_geofence | 20252130 | 0.05 |
| config_fromMap | 484943 | 2.06 |
| config_toMap | 132466 | 7.55 |
| config_roundtrip | 102049 | 9.80 |
| state_fromMap | 458407 | 2.18 |
| state_toMap | 126703 | 7.89 |
| route_context_toMap | 3081646 | 0.32 |
| route_context_fromMap | 2350310 | 0.43 |
| route_context_roundtrip | 1440089 | 0.69 |
| sync_body_context_toMap_50 | 8646401 | 0.12 |
| sync_body_context_fromMap_50 | 22646 | 44.16 |
| http_config_ssl_toMap | 796196 | 1.26 |
| http_config_ssl_fromMap | 3335928 | 0.30 |
| http_config_ssl_roundtrip | 652201 | 1.53 |


### 2026-05-24 — Commit 8986dee

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7409636 | 0.13 |
| kalman_process_100_fixes | 94640 | 10.57 |
| kalman_process_1k_fixes | 9458 | 105.73 |
| kalman_reset | 6666420 | 0.15 |
| haversine_single | 7820742 | 0.13 |
| haversine_1k_pairs | 13837 | 72.27 |
| pip_4v | 13152463 | 0.08 |
| pip_10v | 9376329 | 0.11 |
| pip_50v | 3877445 | 0.26 |
| pip_100v | 2135886 | 0.47 |
| pip_500v | 417506 | 2.40 |
| geofence_eval_10_circular | 587079 | 1.70 |
| geofence_eval_100_circular | 69782 | 14.33 |
| geofence_eval_500_circular | 13397 | 74.64 |
| geofence_eval_10_polygon_6v | 420270 | 2.38 |
| geofence_eval_50_polygon_6v | 83860 | 11.92 |
| processor_1k_fixes | 8753 | 114.24 |
| processor_1k_adaptive | 8375 | 119.40 |
| trip_manager_5k_waypoints | 71 | 14075.83 |
| schedule_parse | 2916067 | 0.34 |
| schedule_matches | 127460 | 7.85 |
| schedule_isWithin_5_entries | 121231 | 8.25 |
| adaptive_compute | 13058867 | 0.08 |
| location_fromMap | 1208494 | 0.83 |
| location_toMap | 692128 | 1.44 |
| location_fromMap_toMap_roundtrip | 453477 | 2.21 |
| location_copyWithCoords | 12091779 | 0.08 |
| geofence_fromMap_circular | 4493189 | 0.22 |
| geofence_fromMap_polygon | 1618511 | 0.62 |
| delta_encode_10 | 14698 | 68.03 |
| delta_decode_10 | 93666 | 10.68 |
| delta_encode_100 | 2567 | 389.63 |
| delta_decode_100 | 11115 | 89.97 |
| delta_encode_500 | 539 | 1854.86 |
| delta_decode_500 | 2040 | 490.21 |
| delta_roundtrip_100 | 2093 | 477.85 |
| battery_budget_single_sample | 9137841 | 0.11 |
| battery_budget_60_samples | 292724 | 3.42 |
| battery_budget_heavy_drain | 148861 | 6.72 |
| carbon_trip_100_locations | 89586 | 11.16 |
| carbon_onLocation | 3984450 | 0.25 |
| carbon_setActivity | 9865220 | 0.10 |
| carbon_cumulative_report | 2784172 | 0.36 |
| persist_decider_location | 20077577 | 0.05 |
| persist_decider_geofence | 19948336 | 0.05 |
| config_fromMap | 485066 | 2.06 |
| config_toMap | 133714 | 7.48 |
| config_roundtrip | 102711 | 9.74 |
| state_fromMap | 454030 | 2.20 |
| state_toMap | 127038 | 7.87 |
| route_context_toMap | 3137221 | 0.32 |
| route_context_fromMap | 2427578 | 0.41 |
| route_context_roundtrip | 1430764 | 0.70 |
| sync_body_context_toMap_50 | 8563240 | 0.12 |
| sync_body_context_fromMap_50 | 21505 | 46.50 |
| http_config_ssl_toMap | 796161 | 1.26 |
| http_config_ssl_fromMap | 3191388 | 0.31 |
| http_config_ssl_roundtrip | 672721 | 1.49 |


### 2026-05-24 — Commit 718a385

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7091931 | 0.14 |
| kalman_process_100_fixes | 94243 | 10.61 |
| kalman_process_1k_fixes | 9530 | 104.93 |
| kalman_reset | 6370307 | 0.16 |
| haversine_single | 8136121 | 0.12 |
| haversine_1k_pairs | 13774 | 72.60 |
| pip_4v | 12995764 | 0.08 |
| pip_10v | 10013604 | 0.10 |
| pip_50v | 3752239 | 0.27 |
| pip_100v | 2062512 | 0.48 |
| pip_500v | 416490 | 2.40 |
| geofence_eval_10_circular | 624805 | 1.60 |
| geofence_eval_100_circular | 69537 | 14.38 |
| geofence_eval_500_circular | 13428 | 74.47 |
| geofence_eval_10_polygon_6v | 413333 | 2.42 |
| geofence_eval_50_polygon_6v | 83207 | 12.02 |
| processor_1k_fixes | 8925 | 112.05 |
| processor_1k_adaptive | 8339 | 119.91 |
| trip_manager_5k_waypoints | 71 | 14025.92 |
| schedule_parse | 2871297 | 0.35 |
| schedule_matches | 128761 | 7.77 |
| schedule_isWithin_5_entries | 121651 | 8.22 |
| adaptive_compute | 12964035 | 0.08 |
| location_fromMap | 1731628 | 0.58 |
| location_toMap | 678066 | 1.47 |
| location_fromMap_toMap_roundtrip | 483401 | 2.07 |
| location_copyWithCoords | 11583501 | 0.09 |
| geofence_fromMap_circular | 4415053 | 0.23 |
| geofence_fromMap_polygon | 1588340 | 0.63 |
| delta_encode_10 | 14492 | 69.00 |
| delta_decode_10 | 91307 | 10.95 |
| delta_encode_100 | 2568 | 389.44 |
| delta_decode_100 | 10810 | 92.50 |
| delta_encode_500 | 534 | 1874.02 |
| delta_decode_500 | 2142 | 466.86 |
| delta_roundtrip_100 | 2070 | 483.14 |
| battery_budget_single_sample | 8985622 | 0.11 |
| battery_budget_60_samples | 294530 | 3.40 |
| battery_budget_heavy_drain | 148229 | 6.75 |
| carbon_trip_100_locations | 88201 | 11.34 |
| carbon_onLocation | 3823171 | 0.26 |
| carbon_setActivity | 8679613 | 0.12 |
| carbon_cumulative_report | 2721667 | 0.37 |
| persist_decider_location | 20134765 | 0.05 |
| persist_decider_geofence | 20107023 | 0.05 |
| config_fromMap | 456602 | 2.19 |
| config_toMap | 130669 | 7.65 |
| config_roundtrip | 101702 | 9.83 |
| state_fromMap | 442013 | 2.26 |
| state_toMap | 126210 | 7.92 |
| route_context_toMap | 2977934 | 0.34 |
| route_context_fromMap | 2382849 | 0.42 |
| route_context_roundtrip | 1412021 | 0.71 |
| sync_body_context_toMap_50 | 8582461 | 0.12 |
| sync_body_context_fromMap_50 | 23106 | 43.28 |
| http_config_ssl_toMap | 806975 | 1.24 |
| http_config_ssl_fromMap | 3319620 | 0.30 |
| http_config_ssl_roundtrip | 665864 | 1.50 |


### 2026-05-23 — Commit 3aff653

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 6824377 | 0.15 |
| kalman_process_100_fixes | 101868 | 9.82 |
| kalman_process_1k_fixes | 9667 | 103.44 |
| kalman_reset | 6604793 | 0.15 |
| haversine_single | 7928836 | 0.13 |
| haversine_1k_pairs | 13606 | 73.50 |
| pip_4v | 12678628 | 0.08 |
| pip_10v | 9700334 | 0.10 |
| pip_50v | 3698450 | 0.27 |
| pip_100v | 2033947 | 0.49 |
| pip_500v | 378257 | 2.64 |
| geofence_eval_10_circular | 652863 | 1.53 |
| geofence_eval_100_circular | 68684 | 14.56 |
| geofence_eval_500_circular | 13765 | 72.65 |
| geofence_eval_10_polygon_6v | 417322 | 2.40 |
| geofence_eval_50_polygon_6v | 85390 | 11.71 |
| processor_1k_fixes | 8937 | 111.89 |
| processor_1k_adaptive | 8609 | 116.16 |
| trip_manager_5k_waypoints | 62 | 16197.61 |
| schedule_parse | 2886373 | 0.35 |
| schedule_matches | 113325 | 8.82 |
| schedule_isWithin_5_entries | 105654 | 9.46 |
| adaptive_compute | 13061062 | 0.08 |
| location_fromMap | 1665846 | 0.60 |
| location_toMap | 673562 | 1.48 |
| location_fromMap_toMap_roundtrip | 492634 | 2.03 |
| location_copyWithCoords | 11110721 | 0.09 |
| geofence_fromMap_circular | 4326158 | 0.23 |
| geofence_fromMap_polygon | 1583410 | 0.63 |
| delta_encode_10 | 14906 | 67.09 |
| delta_decode_10 | 91788 | 10.89 |
| delta_encode_100 | 2629 | 380.30 |
| delta_decode_100 | 11283 | 88.63 |
| delta_encode_500 | 530 | 1888.04 |
| delta_decode_500 | 2331 | 429.07 |
| delta_roundtrip_100 | 2133 | 468.79 |
| battery_budget_single_sample | 8531578 | 0.12 |
| battery_budget_60_samples | 283337 | 3.53 |
| battery_budget_heavy_drain | 141942 | 7.05 |
| carbon_trip_100_locations | 85572 | 11.69 |
| carbon_onLocation | 4170820 | 0.24 |
| carbon_setActivity | 9563024 | 0.10 |
| carbon_cumulative_report | 2693479 | 0.37 |
| persist_decider_location | 17480474 | 0.06 |
| persist_decider_geofence | 19128802 | 0.05 |
| config_fromMap | 467002 | 2.14 |
| config_toMap | 129683 | 7.71 |
| config_roundtrip | 99071 | 10.09 |
| state_fromMap | 439299 | 2.28 |
| state_toMap | 125585 | 7.96 |
| route_context_toMap | 3040845 | 0.33 |
| route_context_fromMap | 2331351 | 0.43 |
| route_context_roundtrip | 1416970 | 0.71 |
| sync_body_context_toMap_50 | 8163046 | 0.12 |
| sync_body_context_fromMap_50 | 22471 | 44.50 |
| http_config_ssl_toMap | 788421 | 1.27 |
| http_config_ssl_fromMap | 3265724 | 0.31 |
| http_config_ssl_roundtrip | 668255 | 1.50 |


### 2026-05-23 — Commit ff0e2c4

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7222855 | 0.14 |
| kalman_process_100_fixes | 96157 | 10.40 |
| kalman_process_1k_fixes | 9551 | 104.70 |
| kalman_reset | 6774911 | 0.15 |
| haversine_single | 8223399 | 0.12 |
| haversine_1k_pairs | 13494 | 74.11 |
| pip_4v | 13266126 | 0.08 |
| pip_10v | 10040996 | 0.10 |
| pip_50v | 3697717 | 0.27 |
| pip_100v | 2085003 | 0.48 |
| pip_500v | 423617 | 2.36 |
| geofence_eval_10_circular | 642513 | 1.56 |
| geofence_eval_100_circular | 70406 | 14.20 |
| geofence_eval_500_circular | 13241 | 75.52 |
| geofence_eval_10_polygon_6v | 421057 | 2.37 |
| geofence_eval_50_polygon_6v | 83919 | 11.92 |
| processor_1k_fixes | 8951 | 111.72 |
| processor_1k_adaptive | 8241 | 121.34 |
| trip_manager_5k_waypoints | 76 | 13188.52 |
| schedule_parse | 2926285 | 0.34 |
| schedule_matches | 132443 | 7.55 |
| schedule_isWithin_5_entries | 126401 | 7.91 |
| adaptive_compute | 13642242 | 0.07 |
| location_fromMap | 1731828 | 0.58 |
| location_toMap | 679204 | 1.47 |
| location_fromMap_toMap_roundtrip | 491995 | 2.03 |
| location_copyWithCoords | 12286581 | 0.08 |
| geofence_fromMap_circular | 4518157 | 0.22 |
| geofence_fromMap_polygon | 1623802 | 0.62 |
| delta_encode_10 | 14863 | 67.28 |
| delta_decode_10 | 93729 | 10.67 |
| delta_encode_100 | 2554 | 391.58 |
| delta_decode_100 | 11104 | 90.06 |
| delta_encode_500 | 530 | 1886.03 |
| delta_decode_500 | 2336 | 428.07 |
| delta_roundtrip_100 | 2081 | 480.46 |
| battery_budget_single_sample | 9104170 | 0.11 |
| battery_budget_60_samples | 290915 | 3.44 |
| battery_budget_heavy_drain | 148167 | 6.75 |
| carbon_trip_100_locations | 87797 | 11.39 |
| carbon_onLocation | 4124872 | 0.24 |
| carbon_setActivity | 9894653 | 0.10 |
| carbon_cumulative_report | 2778327 | 0.36 |
| persist_decider_location | 20394947 | 0.05 |
| persist_decider_geofence | 20275339 | 0.05 |
| config_fromMap | 475815 | 2.10 |
| config_toMap | 134088 | 7.46 |
| config_roundtrip | 103962 | 9.62 |
| state_fromMap | 449438 | 2.22 |
| state_toMap | 127238 | 7.86 |
| route_context_toMap | 3111119 | 0.32 |
| route_context_fromMap | 2385459 | 0.42 |
| route_context_roundtrip | 1471756 | 0.68 |
| sync_body_context_toMap_50 | 8635684 | 0.12 |
| sync_body_context_fromMap_50 | 23352 | 42.82 |
| http_config_ssl_toMap | 818417 | 1.22 |
| http_config_ssl_fromMap | 3240677 | 0.31 |
| http_config_ssl_roundtrip | 669459 | 1.49 |


### 2026-05-23 — Commit 44e2877

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7345592 | 0.14 |
| kalman_process_100_fixes | 97132 | 10.30 |
| kalman_process_1k_fixes | 9627 | 103.87 |
| kalman_reset | 6955037 | 0.14 |
| haversine_single | 8191969 | 0.12 |
| haversine_1k_pairs | 13772 | 72.61 |
| pip_4v | 13005453 | 0.08 |
| pip_10v | 9878745 | 0.10 |
| pip_50v | 3769647 | 0.27 |
| pip_100v | 2030908 | 0.49 |
| pip_500v | 425814 | 2.35 |
| geofence_eval_10_circular | 643748 | 1.55 |
| geofence_eval_100_circular | 68521 | 14.59 |
| geofence_eval_500_circular | 13534 | 73.89 |
| geofence_eval_10_polygon_6v | 415913 | 2.40 |
| geofence_eval_50_polygon_6v | 83843 | 11.93 |
| processor_1k_fixes | 9090 | 110.01 |
| processor_1k_adaptive | 8610 | 116.14 |
| trip_manager_5k_waypoints | 73 | 13664.36 |
| schedule_parse | 2923301 | 0.34 |
| schedule_matches | 130681 | 7.65 |
| schedule_isWithin_5_entries | 123443 | 8.10 |
| adaptive_compute | 13961650 | 0.07 |
| location_fromMap | 1661332 | 0.60 |
| location_toMap | 654174 | 1.53 |
| location_fromMap_toMap_roundtrip | 483422 | 2.07 |
| location_copyWithCoords | 12182287 | 0.08 |
| geofence_fromMap_circular | 4542149 | 0.22 |
| geofence_fromMap_polygon | 1650782 | 0.61 |
| delta_encode_10 | 15013 | 66.61 |
| delta_decode_10 | 91523 | 10.93 |
| delta_encode_100 | 2552 | 391.80 |
| delta_decode_100 | 10692 | 93.53 |
| delta_encode_500 | 543 | 1840.57 |
| delta_decode_500 | 2100 | 476.24 |
| delta_roundtrip_100 | 2060 | 485.37 |
| battery_budget_single_sample | 8984098 | 0.11 |
| battery_budget_60_samples | 288946 | 3.46 |
| battery_budget_heavy_drain | 146097 | 6.84 |
| carbon_trip_100_locations | 89256 | 11.20 |
| carbon_onLocation | 3879003 | 0.26 |
| carbon_setActivity | 9909082 | 0.10 |
| carbon_cumulative_report | 2577228 | 0.39 |
| persist_decider_location | 20164908 | 0.05 |
| persist_decider_geofence | 20270131 | 0.05 |
| config_fromMap | 486025 | 2.06 |
| config_toMap | 120860 | 8.27 |
| config_roundtrip | 97983 | 10.21 |
| state_fromMap | 468671 | 2.13 |
| state_toMap | 121714 | 8.22 |
| route_context_toMap | 3077754 | 0.32 |
| route_context_fromMap | 2377960 | 0.42 |
| route_context_roundtrip | 1446227 | 0.69 |
| sync_body_context_toMap_50 | 8502153 | 0.12 |
| sync_body_context_fromMap_50 | 22797 | 43.86 |
| http_config_ssl_toMap | 785550 | 1.27 |
| http_config_ssl_fromMap | 3348328 | 0.30 |
| http_config_ssl_roundtrip | 654640 | 1.53 |


