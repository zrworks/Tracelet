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


### 2026-05-22 — Commit 94ff7ad

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7126478 | 0.14 |
| kalman_process_100_fixes | 94503 | 10.58 |
| kalman_process_1k_fixes | 9352 | 106.93 |
| kalman_reset | 6834001 | 0.15 |
| haversine_single | 8064258 | 0.12 |
| haversine_1k_pairs | 13852 | 72.19 |
| pip_4v | 12451363 | 0.08 |
| pip_10v | 9598356 | 0.10 |
| pip_50v | 3818951 | 0.26 |
| pip_100v | 1833165 | 0.55 |
| pip_500v | 420644 | 2.38 |
| geofence_eval_10_circular | 644574 | 1.55 |
| geofence_eval_100_circular | 70488 | 14.19 |
| geofence_eval_500_circular | 13279 | 75.31 |
| geofence_eval_10_polygon_6v | 417417 | 2.40 |
| geofence_eval_50_polygon_6v | 83291 | 12.01 |
| processor_1k_fixes | 8823 | 113.34 |
| processor_1k_adaptive | 8257 | 121.11 |
| trip_manager_5k_waypoints | 74 | 13588.24 |
| schedule_parse | 2865791 | 0.35 |
| schedule_matches | 130694 | 7.65 |
| schedule_isWithin_5_entries | 124657 | 8.02 |
| adaptive_compute | 13971929 | 0.07 |
| location_fromMap | 1681989 | 0.59 |
| location_toMap | 677052 | 1.48 |
| location_fromMap_toMap_roundtrip | 490406 | 2.04 |
| location_copyWithCoords | 12090804 | 0.08 |
| geofence_fromMap_circular | 4521061 | 0.22 |
| geofence_fromMap_polygon | 1565807 | 0.64 |
| delta_encode_10 | 14926 | 67.00 |
| delta_decode_10 | 93255 | 10.72 |
| delta_encode_100 | 2560 | 390.59 |
| delta_decode_100 | 11059 | 90.42 |
| delta_encode_500 | 533 | 1877.67 |
| delta_decode_500 | 2353 | 424.94 |
| delta_roundtrip_100 | 2101 | 476.02 |
| battery_budget_single_sample | 9026854 | 0.11 |
| battery_budget_60_samples | 294406 | 3.40 |
| battery_budget_heavy_drain | 149399 | 6.69 |
| carbon_trip_100_locations | 89017 | 11.23 |
| carbon_onLocation | 4123967 | 0.24 |
| carbon_setActivity | 9892547 | 0.10 |
| carbon_cumulative_report | 2721605 | 0.37 |
| persist_decider_location | 19657925 | 0.05 |
| persist_decider_geofence | 19492287 | 0.05 |
| config_fromMap | 507030 | 1.97 |
| config_toMap | 144141 | 6.94 |
| config_roundtrip | 111243 | 8.99 |
| state_fromMap | 470995 | 2.12 |
| state_toMap | 136680 | 7.32 |
| route_context_toMap | 3081721 | 0.32 |
| route_context_fromMap | 2397266 | 0.42 |
| route_context_roundtrip | 1466852 | 0.68 |
| sync_body_context_toMap_50 | 8472377 | 0.12 |
| sync_body_context_fromMap_50 | 23302 | 42.91 |
| http_config_ssl_toMap | 812315 | 1.23 |
| http_config_ssl_fromMap | 3377116 | 0.30 |
| http_config_ssl_roundtrip | 654772 | 1.53 |


### 2026-05-22 — Commit 35fa33d

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7048767 | 0.14 |
| kalman_process_100_fixes | 102143 | 9.79 |
| kalman_process_1k_fixes | 10306 | 97.03 |
| kalman_reset | 6476525 | 0.15 |
| haversine_single | 7987005 | 0.13 |
| haversine_1k_pairs | 13652 | 73.25 |
| pip_4v | 12751937 | 0.08 |
| pip_10v | 9533143 | 0.10 |
| pip_50v | 3786455 | 0.26 |
| pip_100v | 1999105 | 0.50 |
| pip_500v | 383554 | 2.61 |
| geofence_eval_10_circular | 661192 | 1.51 |
| geofence_eval_100_circular | 70288 | 14.23 |
| geofence_eval_500_circular | 13714 | 72.92 |
| geofence_eval_10_polygon_6v | 421804 | 2.37 |
| geofence_eval_50_polygon_6v | 83599 | 11.96 |
| processor_1k_fixes | 9341 | 107.06 |
| processor_1k_adaptive | 8595 | 116.35 |
| trip_manager_5k_waypoints | 63 | 15986.33 |
| schedule_parse | 2897307 | 0.35 |
| schedule_matches | 112745 | 8.87 |
| schedule_isWithin_5_entries | 104876 | 9.54 |
| adaptive_compute | 12906399 | 0.08 |
| location_fromMap | 1624802 | 0.62 |
| location_toMap | 664446 | 1.51 |
| location_fromMap_toMap_roundtrip | 477424 | 2.09 |
| location_copyWithCoords | 11462962 | 0.09 |
| geofence_fromMap_circular | 3919465 | 0.26 |
| geofence_fromMap_polygon | 1518791 | 0.66 |
| delta_encode_10 | 14943 | 66.92 |
| delta_decode_10 | 92904 | 10.76 |
| delta_encode_100 | 2705 | 369.74 |
| delta_decode_100 | 11412 | 87.62 |
| delta_encode_500 | 546 | 1830.46 |
| delta_decode_500 | 2359 | 423.82 |
| delta_roundtrip_100 | 2136 | 468.24 |
| battery_budget_single_sample | 8636956 | 0.12 |
| battery_budget_60_samples | 283098 | 3.53 |
| battery_budget_heavy_drain | 143143 | 6.99 |
| carbon_trip_100_locations | 92299 | 10.83 |
| carbon_onLocation | 4148724 | 0.24 |
| carbon_setActivity | 9667893 | 0.10 |
| carbon_cumulative_report | 2704225 | 0.37 |
| persist_decider_location | 19318593 | 0.05 |
| persist_decider_geofence | 19342539 | 0.05 |
| config_fromMap | 496196 | 2.02 |
| config_toMap | 143808 | 6.95 |
| config_roundtrip | 109299 | 9.15 |
| state_fromMap | 464370 | 2.15 |
| state_toMap | 136145 | 7.35 |
| route_context_toMap | 2986871 | 0.33 |
| route_context_fromMap | 2394438 | 0.42 |
| route_context_roundtrip | 1429615 | 0.70 |
| sync_body_context_toMap_50 | 8274551 | 0.12 |
| sync_body_context_fromMap_50 | 22529 | 44.39 |
| http_config_ssl_toMap | 815826 | 1.23 |
| http_config_ssl_fromMap | 3281968 | 0.30 |
| http_config_ssl_roundtrip | 672601 | 1.49 |


### 2026-05-22 — Commit b437e72

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 6937329 | 0.14 |
| kalman_process_100_fixes | 101807 | 9.82 |
| kalman_process_1k_fixes | 10313 | 96.96 |
| kalman_reset | 6336391 | 0.16 |
| haversine_single | 7595870 | 0.13 |
| haversine_1k_pairs | 13629 | 73.38 |
| pip_4v | 12580598 | 0.08 |
| pip_10v | 9575191 | 0.10 |
| pip_50v | 3755277 | 0.27 |
| pip_100v | 1975091 | 0.51 |
| pip_500v | 382088 | 2.62 |
| geofence_eval_10_circular | 653968 | 1.53 |
| geofence_eval_100_circular | 70568 | 14.17 |
| geofence_eval_500_circular | 13795 | 72.49 |
| geofence_eval_10_polygon_6v | 409863 | 2.44 |
| geofence_eval_50_polygon_6v | 82709 | 12.09 |
| processor_1k_fixes | 9302 | 107.50 |
| processor_1k_adaptive | 8672 | 115.31 |
| trip_manager_5k_waypoints | 63 | 15921.52 |
| schedule_parse | 2871900 | 0.35 |
| schedule_matches | 112389 | 8.90 |
| schedule_isWithin_5_entries | 106646 | 9.38 |
| adaptive_compute | 13122677 | 0.08 |
| location_fromMap | 1646849 | 0.61 |
| location_toMap | 671713 | 1.49 |
| location_fromMap_toMap_roundtrip | 488788 | 2.05 |
| location_copyWithCoords | 11461154 | 0.09 |
| geofence_fromMap_circular | 4212972 | 0.24 |
| geofence_fromMap_polygon | 1599814 | 0.63 |
| delta_encode_10 | 15128 | 66.10 |
| delta_decode_10 | 92165 | 10.85 |
| delta_encode_100 | 2626 | 380.81 |
| delta_decode_100 | 11355 | 88.07 |
| delta_encode_500 | 514 | 1944.61 |
| delta_decode_500 | 2319 | 431.22 |
| delta_roundtrip_100 | 2123 | 471.10 |
| battery_budget_single_sample | 8481698 | 0.12 |
| battery_budget_60_samples | 281408 | 3.55 |
| battery_budget_heavy_drain | 142769 | 7.00 |
| carbon_trip_100_locations | 86458 | 11.57 |
| carbon_onLocation | 4180104 | 0.24 |
| carbon_setActivity | 9565132 | 0.10 |
| carbon_cumulative_report | 2686170 | 0.37 |
| persist_decider_location | 18481783 | 0.05 |
| persist_decider_geofence | 15287002 | 0.07 |
| config_fromMap | 487307 | 2.05 |
| config_toMap | 143771 | 6.96 |
| config_roundtrip | 110164 | 9.08 |
| state_fromMap | 455220 | 2.20 |
| state_toMap | 136240 | 7.34 |
| route_context_toMap | 3024869 | 0.33 |
| route_context_fromMap | 2302171 | 0.43 |
| route_context_roundtrip | 1403858 | 0.71 |
| sync_body_context_toMap_50 | 8257814 | 0.12 |
| sync_body_context_fromMap_50 | 22536 | 44.37 |
| http_config_ssl_toMap | 811223 | 1.23 |
| http_config_ssl_fromMap | 3215816 | 0.31 |
| http_config_ssl_roundtrip | 663550 | 1.51 |


### 2026-05-22 — Commit 16b3acd

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7238507 | 0.14 |
| kalman_process_100_fixes | 97710 | 10.23 |
| kalman_process_1k_fixes | 9339 | 107.08 |
| kalman_reset | 6544014 | 0.15 |
| haversine_single | 7699821 | 0.13 |
| haversine_1k_pairs | 13913 | 71.87 |
| pip_4v | 13390596 | 0.07 |
| pip_10v | 9948835 | 0.10 |
| pip_50v | 3547662 | 0.28 |
| pip_100v | 2022775 | 0.49 |
| pip_500v | 413234 | 2.42 |
| geofence_eval_10_circular | 637874 | 1.57 |
| geofence_eval_100_circular | 69841 | 14.32 |
| geofence_eval_500_circular | 13479 | 74.19 |
| geofence_eval_10_polygon_6v | 413610 | 2.42 |
| geofence_eval_50_polygon_6v | 83338 | 12.00 |
| processor_1k_fixes | 8992 | 111.21 |
| processor_1k_adaptive | 8574 | 116.63 |
| trip_manager_5k_waypoints | 72 | 13817.13 |
| schedule_parse | 2924444 | 0.34 |
| schedule_matches | 127907 | 7.82 |
| schedule_isWithin_5_entries | 121306 | 8.24 |
| adaptive_compute | 13197282 | 0.08 |
| location_fromMap | 1729571 | 0.58 |
| location_toMap | 672050 | 1.49 |
| location_fromMap_toMap_roundtrip | 487971 | 2.05 |
| location_copyWithCoords | 12231546 | 0.08 |
| geofence_fromMap_circular | 4484999 | 0.22 |
| geofence_fromMap_polygon | 1642527 | 0.61 |
| delta_encode_10 | 14683 | 68.11 |
| delta_decode_10 | 93441 | 10.70 |
| delta_encode_100 | 2508 | 398.65 |
| delta_decode_100 | 10905 | 91.70 |
| delta_encode_500 | 530 | 1886.88 |
| delta_decode_500 | 2102 | 475.77 |
| delta_roundtrip_100 | 2004 | 499.12 |
| battery_budget_single_sample | 8891791 | 0.11 |
| battery_budget_60_samples | 292220 | 3.42 |
| battery_budget_heavy_drain | 147893 | 6.76 |
| carbon_trip_100_locations | 87866 | 11.38 |
| carbon_onLocation | 4134735 | 0.24 |
| carbon_setActivity | 9748496 | 0.10 |
| carbon_cumulative_report | 2772330 | 0.36 |
| persist_decider_location | 19419559 | 0.05 |
| persist_decider_geofence | 19415664 | 0.05 |
| config_fromMap | 498559 | 2.01 |
| config_toMap | 143875 | 6.95 |
| config_roundtrip | 110559 | 9.04 |
| state_fromMap | 476728 | 2.10 |
| state_toMap | 135968 | 7.35 |
| route_context_toMap | 3053175 | 0.33 |
| route_context_fromMap | 2344883 | 0.43 |
| route_context_roundtrip | 1422249 | 0.70 |
| sync_body_context_toMap_50 | 8605557 | 0.12 |
| sync_body_context_fromMap_50 | 22754 | 43.95 |
| http_config_ssl_toMap | 808548 | 1.24 |
| http_config_ssl_fromMap | 3212982 | 0.31 |
| http_config_ssl_roundtrip | 652068 | 1.53 |


### 2026-05-21 — Commit f7fc07c

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7013083 | 0.14 |
| kalman_process_100_fixes | 101470 | 9.86 |
| kalman_process_1k_fixes | 10258 | 97.48 |
| kalman_reset | 6581106 | 0.15 |
| haversine_single | 7668516 | 0.13 |
| haversine_1k_pairs | 13678 | 73.11 |
| pip_4v | 12707241 | 0.08 |
| pip_10v | 9541770 | 0.10 |
| pip_50v | 3655255 | 0.27 |
| pip_100v | 1966971 | 0.51 |
| pip_500v | 382089 | 2.62 |
| geofence_eval_10_circular | 664090 | 1.51 |
| geofence_eval_100_circular | 70955 | 14.09 |
| geofence_eval_500_circular | 13884 | 72.03 |
| geofence_eval_10_polygon_6v | 414961 | 2.41 |
| geofence_eval_50_polygon_6v | 84451 | 11.84 |
| processor_1k_fixes | 9458 | 105.73 |
| processor_1k_adaptive | 8708 | 114.83 |
| trip_manager_5k_waypoints | 62 | 16136.69 |
| schedule_parse | 2873917 | 0.35 |
| schedule_matches | 113338 | 8.82 |
| schedule_isWithin_5_entries | 105145 | 9.51 |
| adaptive_compute | 12851410 | 0.08 |
| location_fromMap | 1678184 | 0.60 |
| location_toMap | 684686 | 1.46 |
| location_fromMap_toMap_roundtrip | 489483 | 2.04 |
| location_copyWithCoords | 11411555 | 0.09 |
| geofence_fromMap_circular | 4297215 | 0.23 |
| geofence_fromMap_polygon | 1592598 | 0.63 |
| delta_encode_10 | 15254 | 65.56 |
| delta_decode_10 | 92756 | 10.78 |
| delta_encode_100 | 2691 | 371.61 |
| delta_decode_100 | 11337 | 88.20 |
| delta_encode_500 | 536 | 1866.88 |
| delta_decode_500 | 2123 | 471.00 |
| delta_roundtrip_100 | 2136 | 468.20 |
| battery_budget_single_sample | 8421184 | 0.12 |
| battery_budget_60_samples | 283996 | 3.52 |
| battery_budget_heavy_drain | 144086 | 6.94 |
| carbon_trip_100_locations | 86871 | 11.51 |
| carbon_onLocation | 4236228 | 0.24 |
| carbon_setActivity | 9635957 | 0.10 |
| carbon_cumulative_report | 2650522 | 0.38 |
| persist_decider_location | 19032717 | 0.05 |
| persist_decider_geofence | 19133312 | 0.05 |
| config_fromMap | 493807 | 2.03 |
| config_toMap | 144728 | 6.91 |
| config_roundtrip | 110947 | 9.01 |
| state_fromMap | 462741 | 2.16 |
| state_toMap | 137379 | 7.28 |
| route_context_toMap | 3022867 | 0.33 |
| route_context_fromMap | 2301718 | 0.43 |
| route_context_roundtrip | 1399720 | 0.71 |
| sync_body_context_toMap_50 | 8276942 | 0.12 |
| sync_body_context_fromMap_50 | 22104 | 45.24 |
| http_config_ssl_toMap | 821895 | 1.22 |
| http_config_ssl_fromMap | 3250613 | 0.31 |
| http_config_ssl_roundtrip | 671613 | 1.49 |


