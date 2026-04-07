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

### 2026-04-07 — Commit 06a2ede

**Environment:** Dart 3.11.4, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7185724 | 0.14 |
| kalman_process_100_fixes | 95381 | 10.48 |
| kalman_process_1k_fixes | 9762 | 102.44 |
| kalman_reset | 6717636 | 0.15 |
| haversine_single | 9552840 | 0.10 |
| haversine_1k_pairs | 18994 | 52.65 |
| pip_4v | 12587544 | 0.08 |
| pip_10v | 9627755 | 0.10 |
| pip_50v | 3885769 | 0.26 |
| pip_100v | 2150099 | 0.47 |
| pip_500v | 436795 | 2.29 |
| geofence_eval_10_circular | 686029 | 1.46 |
| geofence_eval_100_circular | 76097 | 13.14 |
| geofence_eval_500_circular | 14475 | 69.09 |
| geofence_eval_10_polygon_6v | 435584 | 2.30 |
| geofence_eval_50_polygon_6v | 87131 | 11.48 |
| processor_1k_fixes | 10777 | 92.79 |
| processor_1k_adaptive | 10169 | 98.33 |
| trip_manager_5k_waypoints | 139 | 7189.25 |
| schedule_parse | 2926784 | 0.34 |
| schedule_matches | 256738 | 3.90 |
| schedule_isWithin_5_entries | 229920 | 4.35 |
| adaptive_compute | 13277830 | 0.08 |
| location_fromMap | 1634029 | 0.61 |
| location_toMap | 588976 | 1.70 |
| location_fromMap_toMap_roundtrip | 429750 | 2.33 |
| location_copyWithCoords | 11210661 | 0.09 |
| geofence_fromMap_circular | 4159995 | 0.24 |
| geofence_fromMap_polygon | 1503814 | 0.66 |
| delta_encode_10 | 32274 | 30.98 |
| delta_decode_10 | 90659 | 11.03 |
| delta_encode_100 | 4271 | 234.16 |
| delta_decode_100 | 10473 | 95.48 |
| delta_encode_500 | 809 | 1236.69 |
| delta_decode_500 | 2061 | 485.14 |
| delta_roundtrip_100 | 3097 | 322.91 |
| battery_budget_single_sample | 8801410 | 0.11 |
| battery_budget_60_samples | 300189 | 3.33 |
| battery_budget_heavy_drain | 151675 | 6.59 |
| carbon_trip_100_locations | 107077 | 9.34 |
| carbon_onLocation | 4289270 | 0.23 |
| carbon_setActivity | 9967804 | 0.10 |
| carbon_cumulative_report | 2669710 | 0.37 |
| persist_decider_location | 20341831 | 0.05 |
| persist_decider_geofence | 20434983 | 0.05 |
| config_fromMap | 431483 | 2.32 |
| config_toMap | 156686 | 6.38 |
| config_roundtrip | 114786 | 8.71 |
| state_fromMap | 391495 | 2.55 |
| state_toMap | 146365 | 6.83 |
| route_context_toMap | 2774183 | 0.36 |
| route_context_fromMap | 2197714 | 0.46 |
| route_context_roundtrip | 1273898 | 0.78 |
| sync_body_context_toMap_50 | 8106950 | 0.12 |
| sync_body_context_fromMap_50 | 22012 | 45.43 |
| http_config_ssl_toMap | 720109 | 1.39 |
| http_config_ssl_fromMap | 1357108 | 0.74 |
| http_config_ssl_roundtrip | 473196 | 2.11 |


### 2026-04-04 — Commit 28d530c

**Environment:** Dart 3.11.4, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7320644 | 0.14 |
| kalman_process_100_fixes | 96356 | 10.38 |
| kalman_process_1k_fixes | 9680 | 103.30 |
| kalman_reset | 6646315 | 0.15 |
| haversine_single | 8070054 | 0.12 |
| haversine_1k_pairs | 13658 | 73.22 |
| pip_4v | 13275729 | 0.08 |
| pip_10v | 10063036 | 0.10 |
| pip_50v | 3694197 | 0.27 |
| pip_100v | 2075364 | 0.48 |
| pip_500v | 427523 | 2.34 |
| geofence_eval_10_circular | 642448 | 1.56 |
| geofence_eval_100_circular | 70866 | 14.11 |
| geofence_eval_500_circular | 13511 | 74.01 |
| geofence_eval_10_polygon_6v | 414762 | 2.41 |
| geofence_eval_50_polygon_6v | 84016 | 11.90 |
| processor_1k_fixes | 8980 | 111.36 |
| processor_1k_adaptive | 8417 | 118.81 |
| trip_manager_5k_waypoints | 73 | 13759.60 |
| schedule_parse | 2913758 | 0.34 |
| schedule_matches | 132022 | 7.57 |
| schedule_isWithin_5_entries | 122721 | 8.15 |
| adaptive_compute | 13995811 | 0.07 |
| location_fromMap | 1612190 | 0.62 |
| location_toMap | 661074 | 1.51 |
| location_fromMap_toMap_roundtrip | 482995 | 2.07 |
| location_copyWithCoords | 12257897 | 0.08 |
| geofence_fromMap_circular | 4040498 | 0.25 |
| geofence_fromMap_polygon | 1525636 | 0.66 |
| delta_encode_10 | 29334 | 34.09 |
| delta_decode_10 | 98222 | 10.18 |
| delta_encode_100 | 4295 | 232.82 |
| delta_decode_100 | 11261 | 88.80 |
| delta_encode_500 | 832 | 1202.02 |
| delta_decode_500 | 2342 | 426.90 |
| delta_roundtrip_100 | 2974 | 336.28 |
| battery_budget_single_sample | 8924066 | 0.11 |
| battery_budget_60_samples | 291686 | 3.43 |
| battery_budget_heavy_drain | 144571 | 6.92 |
| carbon_trip_100_locations | 92641 | 10.79 |
| carbon_onLocation | 4180661 | 0.24 |
| carbon_setActivity | 9706101 | 0.10 |
| carbon_cumulative_report | 2725121 | 0.37 |
| persist_decider_location | 19939180 | 0.05 |
| persist_decider_geofence | 19515056 | 0.05 |
| config_fromMap | 436207 | 2.29 |
| config_toMap | 159487 | 6.27 |
| config_roundtrip | 115396 | 8.67 |
| state_fromMap | 412824 | 2.42 |
| state_toMap | 150186 | 6.66 |
| route_context_toMap | 3092650 | 0.32 |
| route_context_fromMap | 2423261 | 0.41 |
| route_context_roundtrip | 1408752 | 0.71 |
| sync_body_context_toMap_50 | 8479919 | 0.12 |
| sync_body_context_fromMap_50 | 23150 | 43.20 |
| http_config_ssl_toMap | 772293 | 1.29 |
| http_config_ssl_fromMap | 1400976 | 0.71 |
| http_config_ssl_roundtrip | 503780 | 1.98 |


### 2026-04-03 — Commit 5b27506

**Environment:** Dart 3.11.4, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7183709 | 0.14 |
| kalman_process_100_fixes | 93930 | 10.65 |
| kalman_process_1k_fixes | 9457 | 105.75 |
| kalman_reset | 6662081 | 0.15 |
| haversine_single | 8144962 | 0.12 |
| haversine_1k_pairs | 13842 | 72.24 |
| pip_4v | 13270854 | 0.08 |
| pip_10v | 10211104 | 0.10 |
| pip_50v | 4030814 | 0.25 |
| pip_100v | 2053476 | 0.49 |
| pip_500v | 420155 | 2.38 |
| geofence_eval_10_circular | 646006 | 1.55 |
| geofence_eval_100_circular | 69860 | 14.31 |
| geofence_eval_500_circular | 13389 | 74.69 |
| geofence_eval_10_polygon_6v | 415277 | 2.41 |
| geofence_eval_50_polygon_6v | 84870 | 11.78 |
| processor_1k_fixes | 8979 | 111.37 |
| processor_1k_adaptive | 8479 | 117.93 |
| trip_manager_5k_waypoints | 74 | 13562.17 |
| schedule_parse | 2925474 | 0.34 |
| schedule_matches | 131488 | 7.61 |
| schedule_isWithin_5_entries | 125269 | 7.98 |
| adaptive_compute | 13834854 | 0.07 |
| location_fromMap | 1675181 | 0.60 |
| location_toMap | 664313 | 1.51 |
| location_fromMap_toMap_roundtrip | 476713 | 2.10 |
| location_copyWithCoords | 12129626 | 0.08 |
| geofence_fromMap_circular | 4507730 | 0.22 |
| geofence_fromMap_polygon | 1623214 | 0.62 |
| delta_encode_10 | 28946 | 34.55 |
| delta_decode_10 | 96936 | 10.32 |
| delta_encode_100 | 4025 | 248.43 |
| delta_decode_100 | 10947 | 91.35 |
| delta_encode_500 | 851 | 1175.49 |
| delta_decode_500 | 2060 | 485.51 |
| delta_roundtrip_100 | 2926 | 341.80 |
| battery_budget_single_sample | 8455413 | 0.12 |
| battery_budget_60_samples | 295796 | 3.38 |
| battery_budget_heavy_drain | 148298 | 6.74 |
| carbon_trip_100_locations | 91416 | 10.94 |
| carbon_onLocation | 4113905 | 0.24 |
| carbon_setActivity | 9843073 | 0.10 |
| carbon_cumulative_report | 2738718 | 0.37 |
| persist_decider_location | 19722896 | 0.05 |
| persist_decider_geofence | 19909089 | 0.05 |
| config_fromMap | 433495 | 2.31 |
| config_toMap | 154441 | 6.47 |
| config_roundtrip | 113306 | 8.83 |
| state_fromMap | 413321 | 2.42 |
| state_toMap | 146935 | 6.81 |
| route_context_toMap | 3037848 | 0.33 |
| route_context_fromMap | 2379666 | 0.42 |
| route_context_roundtrip | 1358228 | 0.74 |
| sync_body_context_toMap_50 | 8199394 | 0.12 |
| sync_body_context_fromMap_50 | 22965 | 43.55 |
| http_config_ssl_toMap | 762037 | 1.31 |
| http_config_ssl_fromMap | 1423144 | 0.70 |
| http_config_ssl_roundtrip | 485673 | 2.06 |


### 2026-04-01 — Commit 0329541

**Environment:** Dart 3.11.4, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7226951 | 0.14 |
| kalman_process_100_fixes | 95672 | 10.45 |
| kalman_process_1k_fixes | 9678 | 103.33 |
| kalman_reset | 6650181 | 0.15 |
| haversine_single | 7891211 | 0.13 |
| haversine_1k_pairs | 13752 | 72.72 |
| pip_4v | 12897556 | 0.08 |
| pip_10v | 9914822 | 0.10 |
| pip_50v | 3790011 | 0.26 |
| pip_100v | 2027082 | 0.49 |
| pip_500v | 415679 | 2.41 |
| geofence_eval_10_circular | 632631 | 1.58 |
| geofence_eval_100_circular | 69257 | 14.44 |
| geofence_eval_500_circular | 13393 | 74.67 |
| geofence_eval_10_polygon_6v | 412431 | 2.42 |
| geofence_eval_50_polygon_6v | 83523 | 11.97 |
| processor_1k_fixes | 9065 | 110.31 |
| processor_1k_adaptive | 8481 | 117.91 |
| trip_manager_5k_waypoints | 73 | 13740.72 |
| schedule_parse | 2863647 | 0.35 |
| schedule_matches | 130673 | 7.65 |
| schedule_isWithin_5_entries | 124814 | 8.01 |
| adaptive_compute | 12664392 | 0.08 |
| location_fromMap | 1646021 | 0.61 |
| location_toMap | 662579 | 1.51 |
| location_fromMap_toMap_roundtrip | 486840 | 2.05 |
| location_copyWithCoords | 11522016 | 0.09 |
| geofence_fromMap_circular | 4040899 | 0.25 |
| geofence_fromMap_polygon | 1523908 | 0.66 |
| delta_encode_10 | 28791 | 34.73 |
| delta_decode_10 | 97256 | 10.28 |
| delta_encode_100 | 4089 | 244.56 |
| delta_decode_100 | 11040 | 90.58 |
| delta_encode_500 | 839 | 1191.24 |
| delta_decode_500 | 2321 | 430.77 |
| delta_roundtrip_100 | 2954 | 338.49 |
| battery_budget_single_sample | 8657560 | 0.12 |
| battery_budget_60_samples | 284882 | 3.51 |
| battery_budget_heavy_drain | 146224 | 6.84 |
| carbon_trip_100_locations | 94418 | 10.59 |
| carbon_onLocation | 4173526 | 0.24 |
| carbon_setActivity | 9514029 | 0.11 |
| carbon_cumulative_report | 2683539 | 0.37 |
| persist_decider_location | 19988041 | 0.05 |
| persist_decider_geofence | 19933488 | 0.05 |
| config_fromMap | 431975 | 2.31 |
| config_toMap | 157221 | 6.36 |
| config_roundtrip | 114863 | 8.71 |
| state_fromMap | 409382 | 2.44 |
| state_toMap | 151053 | 6.62 |
| route_context_toMap | 3026093 | 0.33 |
| route_context_fromMap | 2339292 | 0.43 |
| route_context_roundtrip | 1420323 | 0.70 |
| sync_body_context_toMap_50 | 8231748 | 0.12 |
| sync_body_context_fromMap_50 | 23228 | 43.05 |
| http_config_ssl_toMap | 775807 | 1.29 |
| http_config_ssl_fromMap | 1402150 | 0.71 |
| http_config_ssl_roundtrip | 502751 | 1.99 |


