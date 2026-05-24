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

### 2026-05-24 — Commit 4cab63c

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 6972944 | 0.14 |
| kalman_process_100_fixes | 103052 | 9.70 |
| kalman_process_1k_fixes | 10248 | 97.58 |
| kalman_reset | 6518940 | 0.15 |
| haversine_single | 7925242 | 0.13 |
| haversine_1k_pairs | 13695 | 73.02 |
| pip_4v | 12248955 | 0.08 |
| pip_10v | 9348075 | 0.11 |
| pip_50v | 3515801 | 0.28 |
| pip_100v | 1974025 | 0.51 |
| pip_500v | 387082 | 2.58 |
| geofence_eval_10_circular | 664779 | 1.50 |
| geofence_eval_100_circular | 70738 | 14.14 |
| geofence_eval_500_circular | 13916 | 71.86 |
| geofence_eval_10_polygon_6v | 420479 | 2.38 |
| geofence_eval_50_polygon_6v | 83994 | 11.91 |
| processor_1k_fixes | 9273 | 107.84 |
| processor_1k_adaptive | 8601 | 116.26 |
| trip_manager_5k_waypoints | 62 | 16043.30 |
| schedule_parse | 2905490 | 0.34 |
| schedule_matches | 112602 | 8.88 |
| schedule_isWithin_5_entries | 106815 | 9.36 |
| adaptive_compute | 12188329 | 0.08 |
| location_fromMap | 1629165 | 0.61 |
| location_toMap | 676259 | 1.48 |
| location_fromMap_toMap_roundtrip | 479067 | 2.09 |
| location_copyWithCoords | 11229459 | 0.09 |
| geofence_fromMap_circular | 4337267 | 0.23 |
| geofence_fromMap_polygon | 1579789 | 0.63 |
| delta_encode_10 | 14891 | 67.15 |
| delta_decode_10 | 92722 | 10.78 |
| delta_encode_100 | 2658 | 376.20 |
| delta_decode_100 | 11385 | 87.84 |
| delta_encode_500 | 520 | 1922.29 |
| delta_decode_500 | 2150 | 465.02 |
| delta_roundtrip_100 | 2124 | 470.71 |
| battery_budget_single_sample | 8591767 | 0.12 |
| battery_budget_60_samples | 277858 | 3.60 |
| battery_budget_heavy_drain | 139014 | 7.19 |
| carbon_trip_100_locations | 86520 | 11.56 |
| carbon_onLocation | 4134446 | 0.24 |
| carbon_setActivity | 9451144 | 0.11 |
| carbon_cumulative_report | 2577178 | 0.39 |
| persist_decider_location | 19205481 | 0.05 |
| persist_decider_geofence | 19241906 | 0.05 |
| config_fromMap | 463469 | 2.16 |
| config_toMap | 133791 | 7.47 |
| config_roundtrip | 101752 | 9.83 |
| state_fromMap | 431600 | 2.32 |
| state_toMap | 125940 | 7.94 |
| route_context_toMap | 3057464 | 0.33 |
| route_context_fromMap | 2276412 | 0.44 |
| route_context_roundtrip | 1411668 | 0.71 |
| sync_body_context_toMap_50 | 8322315 | 0.12 |
| sync_body_context_fromMap_50 | 22501 | 44.44 |
| http_config_ssl_toMap | 815782 | 1.23 |
| http_config_ssl_fromMap | 3258511 | 0.31 |
| http_config_ssl_roundtrip | 650240 | 1.54 |


### 2026-05-24 — Commit 1ccb039

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 6900056 | 0.14 |
| kalman_process_100_fixes | 101876 | 9.82 |
| kalman_process_1k_fixes | 10303 | 97.06 |
| kalman_reset | 6439825 | 0.16 |
| haversine_single | 7985586 | 0.13 |
| haversine_1k_pairs | 13624 | 73.40 |
| pip_4v | 12673711 | 0.08 |
| pip_10v | 9532661 | 0.10 |
| pip_50v | 3385926 | 0.30 |
| pip_100v | 1805874 | 0.55 |
| pip_500v | 375407 | 2.66 |
| geofence_eval_10_circular | 645681 | 1.55 |
| geofence_eval_100_circular | 68788 | 14.54 |
| geofence_eval_500_circular | 13512 | 74.01 |
| geofence_eval_10_polygon_6v | 419373 | 2.38 |
| geofence_eval_50_polygon_6v | 83070 | 12.04 |
| processor_1k_fixes | 9111 | 109.76 |
| processor_1k_adaptive | 8275 | 120.85 |
| trip_manager_5k_waypoints | 62 | 16216.40 |
| schedule_parse | 2882500 | 0.35 |
| schedule_matches | 112579 | 8.88 |
| schedule_isWithin_5_entries | 106352 | 9.40 |
| adaptive_compute | 13081815 | 0.08 |
| location_fromMap | 1687330 | 0.59 |
| location_toMap | 681768 | 1.47 |
| location_fromMap_toMap_roundtrip | 490526 | 2.04 |
| location_copyWithCoords | 11262129 | 0.09 |
| geofence_fromMap_circular | 4217902 | 0.24 |
| geofence_fromMap_polygon | 1612507 | 0.62 |
| delta_encode_10 | 15150 | 66.01 |
| delta_decode_10 | 92450 | 10.82 |
| delta_encode_100 | 2639 | 379.00 |
| delta_decode_100 | 11413 | 87.62 |
| delta_encode_500 | 522 | 1916.61 |
| delta_decode_500 | 2192 | 456.24 |
| delta_roundtrip_100 | 2145 | 466.29 |
| battery_budget_single_sample | 8463395 | 0.12 |
| battery_budget_60_samples | 286170 | 3.49 |
| battery_budget_heavy_drain | 141467 | 7.07 |
| carbon_trip_100_locations | 85579 | 11.69 |
| carbon_onLocation | 4145927 | 0.24 |
| carbon_setActivity | 9689028 | 0.10 |
| carbon_cumulative_report | 2612779 | 0.38 |
| persist_decider_location | 18460734 | 0.05 |
| persist_decider_geofence | 18591534 | 0.05 |
| config_fromMap | 469067 | 2.13 |
| config_toMap | 132357 | 7.56 |
| config_roundtrip | 98903 | 10.11 |
| state_fromMap | 431370 | 2.32 |
| state_toMap | 126822 | 7.89 |
| route_context_toMap | 3048236 | 0.33 |
| route_context_fromMap | 2259336 | 0.44 |
| route_context_roundtrip | 1415631 | 0.71 |
| sync_body_context_toMap_50 | 8181047 | 0.12 |
| sync_body_context_fromMap_50 | 22546 | 44.35 |
| http_config_ssl_toMap | 786184 | 1.27 |
| http_config_ssl_fromMap | 3215896 | 0.31 |
| http_config_ssl_roundtrip | 660440 | 1.51 |


### 2026-05-24 — Commit 5ef22fb

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 8913341 | 0.11 |
| kalman_process_100_fixes | 130731 | 7.65 |
| kalman_process_1k_fixes | 13150 | 76.05 |
| kalman_reset | 7375114 | 0.14 |
| haversine_single | 8725855 | 0.11 |
| haversine_1k_pairs | 17226 | 58.05 |
| pip_4v | 12308382 | 0.08 |
| pip_10v | 10500577 | 0.10 |
| pip_50v | 4097536 | 0.24 |
| pip_100v | 2276977 | 0.44 |
| pip_500v | 485870 | 2.06 |
| geofence_eval_10_circular | 830945 | 1.20 |
| geofence_eval_100_circular | 90133 | 11.09 |
| geofence_eval_500_circular | 17481 | 57.21 |
| geofence_eval_10_polygon_6v | 530253 | 1.89 |
| geofence_eval_50_polygon_6v | 108638 | 9.20 |
| processor_1k_fixes | 11800 | 84.74 |
| processor_1k_adaptive | 11064 | 90.39 |
| trip_manager_5k_waypoints | 79 | 12718.34 |
| schedule_parse | 3486955 | 0.29 |
| schedule_matches | 145527 | 6.87 |
| schedule_isWithin_5_entries | 138373 | 7.23 |
| adaptive_compute | 13258616 | 0.08 |
| location_fromMap | 2035855 | 0.49 |
| location_toMap | 860656 | 1.16 |
| location_fromMap_toMap_roundtrip | 624061 | 1.60 |
| location_copyWithCoords | 11765868 | 0.08 |
| geofence_fromMap_circular | 5037084 | 0.20 |
| geofence_fromMap_polygon | 1955689 | 0.51 |
| delta_encode_10 | 19625 | 50.96 |
| delta_decode_10 | 118910 | 8.41 |
| delta_encode_100 | 3432 | 291.41 |
| delta_decode_100 | 14645 | 68.28 |
| delta_encode_500 | 684 | 1461.34 |
| delta_decode_500 | 2753 | 363.19 |
| delta_roundtrip_100 | 2740 | 364.94 |
| battery_budget_single_sample | 9411648 | 0.11 |
| battery_budget_60_samples | 363321 | 2.75 |
| battery_budget_heavy_drain | 182168 | 5.49 |
| carbon_trip_100_locations | 111436 | 8.97 |
| carbon_onLocation | 4951326 | 0.20 |
| carbon_setActivity | 10532636 | 0.09 |
| carbon_cumulative_report | 3305722 | 0.30 |
| persist_decider_location | 17844179 | 0.06 |
| persist_decider_geofence | 17842774 | 0.06 |
| config_fromMap | 577841 | 1.73 |
| config_toMap | 169476 | 5.90 |
| config_roundtrip | 127451 | 7.85 |
| state_fromMap | 543683 | 1.84 |
| state_toMap | 161946 | 6.17 |
| route_context_toMap | 3706415 | 0.27 |
| route_context_fromMap | 2848305 | 0.35 |
| route_context_roundtrip | 1765891 | 0.57 |
| sync_body_context_toMap_50 | 9109648 | 0.11 |
| sync_body_context_fromMap_50 | 28641 | 34.91 |
| http_config_ssl_toMap | 1026963 | 0.97 |
| http_config_ssl_fromMap | 3895644 | 0.26 |
| http_config_ssl_roundtrip | 842717 | 1.19 |


### 2026-05-24 — Commit 1e2a244

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7401317 | 0.14 |
| kalman_process_100_fixes | 94227 | 10.61 |
| kalman_process_1k_fixes | 9472 | 105.57 |
| kalman_reset | 6626902 | 0.15 |
| haversine_single | 8067841 | 0.12 |
| haversine_1k_pairs | 13623 | 73.41 |
| pip_4v | 12743379 | 0.08 |
| pip_10v | 9491825 | 0.11 |
| pip_50v | 3595807 | 0.28 |
| pip_100v | 2067773 | 0.48 |
| pip_500v | 416693 | 2.40 |
| geofence_eval_10_circular | 636755 | 1.57 |
| geofence_eval_100_circular | 69546 | 14.38 |
| geofence_eval_500_circular | 13418 | 74.53 |
| geofence_eval_10_polygon_6v | 412640 | 2.42 |
| geofence_eval_50_polygon_6v | 82789 | 12.08 |
| processor_1k_fixes | 8958 | 111.63 |
| processor_1k_adaptive | 8434 | 118.57 |
| trip_manager_5k_waypoints | 72 | 13845.83 |
| schedule_parse | 2924740 | 0.34 |
| schedule_matches | 129183 | 7.74 |
| schedule_isWithin_5_entries | 122134 | 8.19 |
| adaptive_compute | 13474037 | 0.07 |
| location_fromMap | 1743252 | 0.57 |
| location_toMap | 663922 | 1.51 |
| location_fromMap_toMap_roundtrip | 480220 | 2.08 |
| location_copyWithCoords | 12101307 | 0.08 |
| geofence_fromMap_circular | 4513695 | 0.22 |
| geofence_fromMap_polygon | 1620029 | 0.62 |
| delta_encode_10 | 14632 | 68.34 |
| delta_decode_10 | 90684 | 11.03 |
| delta_encode_100 | 2530 | 395.29 |
| delta_decode_100 | 10716 | 93.32 |
| delta_encode_500 | 514 | 1945.83 |
| delta_decode_500 | 2191 | 456.48 |
| delta_roundtrip_100 | 2087 | 479.08 |
| battery_budget_single_sample | 9036741 | 0.11 |
| battery_budget_60_samples | 293880 | 3.40 |
| battery_budget_heavy_drain | 147583 | 6.78 |
| carbon_trip_100_locations | 90391 | 11.06 |
| carbon_onLocation | 4058179 | 0.25 |
| carbon_setActivity | 9626847 | 0.10 |
| carbon_cumulative_report | 2634393 | 0.38 |
| persist_decider_location | 20130293 | 0.05 |
| persist_decider_geofence | 20300819 | 0.05 |
| config_fromMap | 464657 | 2.15 |
| config_toMap | 130631 | 7.66 |
| config_roundtrip | 100090 | 9.99 |
| state_fromMap | 438413 | 2.28 |
| state_toMap | 125331 | 7.98 |
| route_context_toMap | 3011866 | 0.33 |
| route_context_fromMap | 2430043 | 0.41 |
| route_context_roundtrip | 1438773 | 0.70 |
| sync_body_context_toMap_50 | 8411426 | 0.12 |
| sync_body_context_fromMap_50 | 22358 | 44.73 |
| http_config_ssl_toMap | 780468 | 1.28 |
| http_config_ssl_fromMap | 3288767 | 0.30 |
| http_config_ssl_roundtrip | 646461 | 1.55 |


### 2026-05-24 — Commit edc292c

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7251087 | 0.14 |
| kalman_process_100_fixes | 95217 | 10.50 |
| kalman_process_1k_fixes | 9564 | 104.56 |
| kalman_reset | 6746305 | 0.15 |
| haversine_single | 7992063 | 0.13 |
| haversine_1k_pairs | 13754 | 72.71 |
| pip_4v | 13464186 | 0.07 |
| pip_10v | 10005068 | 0.10 |
| pip_50v | 3663828 | 0.27 |
| pip_100v | 2009195 | 0.50 |
| pip_500v | 420130 | 2.38 |
| geofence_eval_10_circular | 640324 | 1.56 |
| geofence_eval_100_circular | 69711 | 14.34 |
| geofence_eval_500_circular | 13241 | 75.52 |
| geofence_eval_10_polygon_6v | 414671 | 2.41 |
| geofence_eval_50_polygon_6v | 84109 | 11.89 |
| processor_1k_fixes | 8734 | 114.50 |
| processor_1k_adaptive | 8199 | 121.97 |
| trip_manager_5k_waypoints | 72 | 13805.42 |
| schedule_parse | 2913317 | 0.34 |
| schedule_matches | 128785 | 7.76 |
| schedule_isWithin_5_entries | 121607 | 8.22 |
| adaptive_compute | 13892829 | 0.07 |
| location_fromMap | 1731730 | 0.58 |
| location_toMap | 663606 | 1.51 |
| location_fromMap_toMap_roundtrip | 482809 | 2.07 |
| location_copyWithCoords | 11858836 | 0.08 |
| geofence_fromMap_circular | 4436766 | 0.23 |
| geofence_fromMap_polygon | 1566416 | 0.64 |
| delta_encode_10 | 14303 | 69.92 |
| delta_decode_10 | 91473 | 10.93 |
| delta_encode_100 | 2486 | 402.31 |
| delta_decode_100 | 11067 | 90.36 |
| delta_encode_500 | 501 | 1996.97 |
| delta_decode_500 | 2373 | 421.35 |
| delta_roundtrip_100 | 2027 | 493.36 |
| battery_budget_single_sample | 9082025 | 0.11 |
| battery_budget_60_samples | 289286 | 3.46 |
| battery_budget_heavy_drain | 147404 | 6.78 |
| carbon_trip_100_locations | 90020 | 11.11 |
| carbon_onLocation | 4080402 | 0.25 |
| carbon_setActivity | 9804162 | 0.10 |
| carbon_cumulative_report | 2758406 | 0.36 |
| persist_decider_location | 20137188 | 0.05 |
| persist_decider_geofence | 20216633 | 0.05 |
| config_fromMap | 468334 | 2.14 |
| config_toMap | 131973 | 7.58 |
| config_roundtrip | 102488 | 9.76 |
| state_fromMap | 439052 | 2.28 |
| state_toMap | 127206 | 7.86 |
| route_context_toMap | 3054600 | 0.33 |
| route_context_fromMap | 2389812 | 0.42 |
| route_context_roundtrip | 1456333 | 0.69 |
| sync_body_context_toMap_50 | 8610563 | 0.12 |
| sync_body_context_fromMap_50 | 22993 | 43.49 |
| http_config_ssl_toMap | 794542 | 1.26 |
| http_config_ssl_fromMap | 3360277 | 0.30 |
| http_config_ssl_roundtrip | 663974 | 1.51 |


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


