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


### 2026-05-23 — Commit b20db45

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 6742403 | 0.15 |
| kalman_process_100_fixes | 101384 | 9.86 |
| kalman_process_1k_fixes | 10308 | 97.02 |
| kalman_reset | 6239647 | 0.16 |
| haversine_single | 8028310 | 0.12 |
| haversine_1k_pairs | 13647 | 73.27 |
| pip_4v | 12872955 | 0.08 |
| pip_10v | 9702084 | 0.10 |
| pip_50v | 3741151 | 0.27 |
| pip_100v | 2001104 | 0.50 |
| pip_500v | 380050 | 2.63 |
| geofence_eval_10_circular | 647857 | 1.54 |
| geofence_eval_100_circular | 70190 | 14.25 |
| geofence_eval_500_circular | 13299 | 75.19 |
| geofence_eval_10_polygon_6v | 413476 | 2.42 |
| geofence_eval_50_polygon_6v | 82534 | 12.12 |
| processor_1k_fixes | 9016 | 110.91 |
| processor_1k_adaptive | 8220 | 121.66 |
| trip_manager_5k_waypoints | 61 | 16315.65 |
| schedule_parse | 2817945 | 0.35 |
| schedule_matches | 112683 | 8.87 |
| schedule_isWithin_5_entries | 106095 | 9.43 |
| adaptive_compute | 12964537 | 0.08 |
| location_fromMap | 1590789 | 0.63 |
| location_toMap | 617054 | 1.62 |
| location_fromMap_toMap_roundtrip | 455166 | 2.20 |
| location_copyWithCoords | 11361116 | 0.09 |
| geofence_fromMap_circular | 4041741 | 0.25 |
| geofence_fromMap_polygon | 1501614 | 0.67 |
| delta_encode_10 | 14879 | 67.21 |
| delta_decode_10 | 89517 | 11.17 |
| delta_encode_100 | 2618 | 381.91 |
| delta_decode_100 | 10915 | 91.62 |
| delta_encode_500 | 548 | 1823.33 |
| delta_decode_500 | 2213 | 451.78 |
| delta_roundtrip_100 | 2129 | 469.78 |
| battery_budget_single_sample | 8362438 | 0.12 |
| battery_budget_60_samples | 275333 | 3.63 |
| battery_budget_heavy_drain | 138517 | 7.22 |
| carbon_trip_100_locations | 90458 | 11.05 |
| carbon_onLocation | 4003312 | 0.25 |
| carbon_setActivity | 8949673 | 0.11 |
| carbon_cumulative_report | 2518548 | 0.40 |
| persist_decider_location | 19286422 | 0.05 |
| persist_decider_geofence | 19273910 | 0.05 |
| config_fromMap | 466186 | 2.15 |
| config_toMap | 118903 | 8.41 |
| config_roundtrip | 92872 | 10.77 |
| state_fromMap | 432155 | 2.31 |
| state_toMap | 110146 | 9.08 |
| route_context_toMap | 2925271 | 0.34 |
| route_context_fromMap | 2343432 | 0.43 |
| route_context_roundtrip | 1354627 | 0.74 |
| sync_body_context_toMap_50 | 7905483 | 0.13 |
| sync_body_context_fromMap_50 | 19726 | 50.69 |
| http_config_ssl_toMap | 779338 | 1.28 |
| http_config_ssl_fromMap | 3251913 | 0.31 |
| http_config_ssl_roundtrip | 648888 | 1.54 |


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


