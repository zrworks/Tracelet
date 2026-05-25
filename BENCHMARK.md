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

### 2026-05-25 — Commit 41385a0

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2755187 | 0.36 |
| schedule_matches | 107246 | 9.32 |
| schedule_isWithin_5_entries | 105957 | 9.44 |
| location_fromMap | 1656256 | 0.60 |
| location_toMap | 634037 | 1.58 |
| location_fromMap_toMap_roundtrip | 470487 | 2.13 |
| location_copyWithCoords | 10731640 | 0.09 |
| geofence_fromMap_circular | 4197355 | 0.24 |
| geofence_fromMap_polygon | 1493689 | 0.67 |
| carbon_trip_100_locations | 90340 | 11.07 |
| carbon_onLocation | 3969565 | 0.25 |
| carbon_setActivity | 9039438 | 0.11 |
| carbon_cumulative_report | 2531703 | 0.39 |
| persist_decider_location | 19030429 | 0.05 |
| persist_decider_geofence | 18736683 | 0.05 |
| config_fromMap | 453607 | 2.20 |
| config_toMap | 127948 | 7.82 |
| config_roundtrip | 98799 | 10.12 |
| state_fromMap | 424377 | 2.36 |
| state_toMap | 122379 | 8.17 |
| route_context_toMap | 2888112 | 0.35 |
| route_context_fromMap | 2318754 | 0.43 |
| route_context_roundtrip | 1385000 | 0.72 |
| sync_body_context_toMap_50 | 7633495 | 0.13 |
| sync_body_context_fromMap_50 | 21706 | 46.07 |
| http_config_ssl_toMap | 781964 | 1.28 |
| http_config_ssl_fromMap | 3144623 | 0.32 |
| http_config_ssl_roundtrip | 649849 | 1.54 |


### 2026-05-25 — Commit 7dc73de

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2707111 | 0.37 |
| schedule_matches | 129753 | 7.71 |
| schedule_isWithin_5_entries | 121444 | 8.23 |
| location_fromMap | 1728078 | 0.58 |
| location_toMap | 646066 | 1.55 |
| location_fromMap_toMap_roundtrip | 475266 | 2.10 |
| location_copyWithCoords | 11429084 | 0.09 |
| geofence_fromMap_circular | 4343745 | 0.23 |
| geofence_fromMap_polygon | 1561790 | 0.64 |
| carbon_trip_100_locations | 94286 | 10.61 |
| carbon_onLocation | 4072540 | 0.25 |
| carbon_setActivity | 9353151 | 0.11 |
| carbon_cumulative_report | 2589199 | 0.39 |
| persist_decider_location | 20397284 | 0.05 |
| persist_decider_geofence | 20419034 | 0.05 |
| config_fromMap | 489065 | 2.04 |
| config_toMap | 127220 | 7.86 |
| config_roundtrip | 99997 | 10.00 |
| state_fromMap | 462233 | 2.16 |
| state_toMap | 124634 | 8.02 |
| route_context_toMap | 3045020 | 0.33 |
| route_context_fromMap | 2320818 | 0.43 |
| route_context_roundtrip | 1364350 | 0.73 |
| sync_body_context_toMap_50 | 8068645 | 0.12 |
| sync_body_context_fromMap_50 | 22393 | 44.66 |
| http_config_ssl_toMap | 786035 | 1.27 |
| http_config_ssl_fromMap | 3252982 | 0.31 |
| http_config_ssl_roundtrip | 647125 | 1.55 |


### 2026-05-25 — Commit 7dc41c9

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

(no table captured)


### 2026-05-25 — Commit 881e96f

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

(no table captured)


### 2026-05-25 — Commit e751997

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

(no table captured)


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


