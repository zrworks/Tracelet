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

### 2026-04-20 — Commit 5656ee5

**Environment:** Dart 3.11.5, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7313077 | 0.14 |
| kalman_process_100_fixes | 93994 | 10.64 |
| kalman_process_1k_fixes | 9520 | 105.04 |
| kalman_reset | 6482420 | 0.15 |
| haversine_single | 8022832 | 0.12 |
| haversine_1k_pairs | 13740 | 72.78 |
| pip_4v | 12603712 | 0.08 |
| pip_10v | 9865214 | 0.10 |
| pip_50v | 3501123 | 0.29 |
| pip_100v | 1983708 | 0.50 |
| pip_500v | 421090 | 2.37 |
| geofence_eval_10_circular | 637038 | 1.57 |
| geofence_eval_100_circular | 68360 | 14.63 |
| geofence_eval_500_circular | 13279 | 75.31 |
| geofence_eval_10_polygon_6v | 408826 | 2.45 |
| geofence_eval_50_polygon_6v | 81852 | 12.22 |
| processor_1k_fixes | 8962 | 111.58 |
| processor_1k_adaptive | 8521 | 117.36 |
| trip_manager_5k_waypoints | 73 | 13749.20 |
| schedule_parse | 2840159 | 0.35 |
| schedule_matches | 132845 | 7.53 |
| schedule_isWithin_5_entries | 125308 | 7.98 |
| adaptive_compute | 13373711 | 0.07 |
| location_fromMap | 1601636 | 0.62 |
| location_toMap | 666730 | 1.50 |
| location_fromMap_toMap_roundtrip | 473976 | 2.11 |
| location_copyWithCoords | 11523717 | 0.09 |
| geofence_fromMap_circular | 3923936 | 0.25 |
| geofence_fromMap_polygon | 1509402 | 0.66 |
| delta_encode_10 | 29737 | 33.63 |
| delta_decode_10 | 96391 | 10.37 |
| delta_encode_100 | 4222 | 236.87 |
| delta_decode_100 | 11036 | 90.61 |
| delta_encode_500 | 861 | 1161.97 |
| delta_decode_500 | 2288 | 436.98 |
| delta_roundtrip_100 | 2991 | 334.31 |
| battery_budget_single_sample | 8871304 | 0.11 |
| battery_budget_60_samples | 293142 | 3.41 |
| battery_budget_heavy_drain | 146470 | 6.83 |
| carbon_trip_100_locations | 93712 | 10.67 |
| carbon_onLocation | 4039567 | 0.25 |
| carbon_setActivity | 9776445 | 0.10 |
| carbon_cumulative_report | 2739984 | 0.36 |
| persist_decider_location | 19822614 | 0.05 |
| persist_decider_geofence | 20047009 | 0.05 |
| config_fromMap | 412461 | 2.42 |
| config_toMap | 157705 | 6.34 |
| config_roundtrip | 114323 | 8.75 |
| state_fromMap | 395053 | 2.53 |
| state_toMap | 149456 | 6.69 |
| route_context_toMap | 3061814 | 0.33 |
| route_context_fromMap | 2352476 | 0.43 |
| route_context_roundtrip | 1411761 | 0.71 |
| sync_body_context_toMap_50 | 8336110 | 0.12 |
| sync_body_context_fromMap_50 | 22936 | 43.60 |
| http_config_ssl_toMap | 759693 | 1.32 |
| http_config_ssl_fromMap | 1376424 | 0.73 |
| http_config_ssl_roundtrip | 495576 | 2.02 |


### 2026-04-19 — Commit 02ffe27

**Environment:** Dart 3.11.5, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7071662 | 0.14 |
| kalman_process_100_fixes | 101757 | 9.83 |
| kalman_process_1k_fixes | 10497 | 95.27 |
| kalman_reset | 6540653 | 0.15 |
| haversine_single | 8120617 | 0.12 |
| haversine_1k_pairs | 13512 | 74.01 |
| pip_4v | 12894730 | 0.08 |
| pip_10v | 9769505 | 0.10 |
| pip_50v | 3698290 | 0.27 |
| pip_100v | 2036543 | 0.49 |
| pip_500v | 383622 | 2.61 |
| geofence_eval_10_circular | 647777 | 1.54 |
| geofence_eval_100_circular | 71115 | 14.06 |
| geofence_eval_500_circular | 13739 | 72.79 |
| geofence_eval_10_polygon_6v | 415010 | 2.41 |
| geofence_eval_50_polygon_6v | 86164 | 11.61 |
| processor_1k_fixes | 9181 | 108.92 |
| processor_1k_adaptive | 8719 | 114.69 |
| trip_manager_5k_waypoints | 64 | 15571.62 |
| schedule_parse | 2856960 | 0.35 |
| schedule_matches | 115852 | 8.63 |
| schedule_isWithin_5_entries | 109941 | 9.10 |
| adaptive_compute | 12931721 | 0.08 |
| location_fromMap | 1668115 | 0.60 |
| location_toMap | 678568 | 1.47 |
| location_fromMap_toMap_roundtrip | 487575 | 2.05 |
| location_copyWithCoords | 11447409 | 0.09 |
| geofence_fromMap_circular | 4347980 | 0.23 |
| geofence_fromMap_polygon | 1579821 | 0.63 |
| delta_encode_10 | 30742 | 32.53 |
| delta_decode_10 | 97281 | 10.28 |
| delta_encode_100 | 4350 | 229.90 |
| delta_decode_100 | 11354 | 88.08 |
| delta_encode_500 | 880 | 1135.92 |
| delta_decode_500 | 2109 | 474.26 |
| delta_roundtrip_100 | 3120 | 320.56 |
| battery_budget_single_sample | 8651231 | 0.12 |
| battery_budget_60_samples | 279011 | 3.58 |
| battery_budget_heavy_drain | 141850 | 7.05 |
| carbon_trip_100_locations | 87264 | 11.46 |
| carbon_onLocation | 4185647 | 0.24 |
| carbon_setActivity | 9575606 | 0.10 |
| carbon_cumulative_report | 2686843 | 0.37 |
| persist_decider_location | 19023659 | 0.05 |
| persist_decider_geofence | 19244170 | 0.05 |
| config_fromMap | 424176 | 2.36 |
| config_toMap | 158636 | 6.30 |
| config_roundtrip | 111969 | 8.93 |
| state_fromMap | 398400 | 2.51 |
| state_toMap | 148504 | 6.73 |
| route_context_toMap | 3005901 | 0.33 |
| route_context_fromMap | 2326935 | 0.43 |
| route_context_roundtrip | 1419660 | 0.70 |
| sync_body_context_toMap_50 | 8144300 | 0.12 |
| sync_body_context_fromMap_50 | 22359 | 44.72 |
| http_config_ssl_toMap | 757952 | 1.32 |
| http_config_ssl_fromMap | 1358906 | 0.74 |
| http_config_ssl_roundtrip | 497480 | 2.01 |


### 2026-04-17 — Commit cdd9227

**Environment:** Dart 3.11.5, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7186572 | 0.14 |
| kalman_process_100_fixes | 93766 | 10.66 |
| kalman_process_1k_fixes | 9335 | 107.12 |
| kalman_reset | 6746824 | 0.15 |
| haversine_single | 8143519 | 0.12 |
| haversine_1k_pairs | 13850 | 72.20 |
| pip_4v | 13319806 | 0.08 |
| pip_10v | 10192406 | 0.10 |
| pip_50v | 3949991 | 0.25 |
| pip_100v | 2173512 | 0.46 |
| pip_500v | 423020 | 2.36 |
| geofence_eval_10_circular | 641335 | 1.56 |
| geofence_eval_100_circular | 69184 | 14.45 |
| geofence_eval_500_circular | 13386 | 74.70 |
| geofence_eval_10_polygon_6v | 412931 | 2.42 |
| geofence_eval_50_polygon_6v | 82587 | 12.11 |
| processor_1k_fixes | 8898 | 112.39 |
| processor_1k_adaptive | 8490 | 117.78 |
| trip_manager_5k_waypoints | 72 | 13892.91 |
| schedule_parse | 2909551 | 0.34 |
| schedule_matches | 128490 | 7.78 |
| schedule_isWithin_5_entries | 120480 | 8.30 |
| adaptive_compute | 13606650 | 0.07 |
| location_fromMap | 1725884 | 0.58 |
| location_toMap | 668091 | 1.50 |
| location_fromMap_toMap_roundtrip | 481990 | 2.07 |
| location_copyWithCoords | 12232892 | 0.08 |
| geofence_fromMap_circular | 4407999 | 0.23 |
| geofence_fromMap_polygon | 1566046 | 0.64 |
| delta_encode_10 | 28801 | 34.72 |
| delta_decode_10 | 96505 | 10.36 |
| delta_encode_100 | 4031 | 248.07 |
| delta_decode_100 | 10992 | 90.98 |
| delta_encode_500 | 804 | 1244.38 |
| delta_decode_500 | 2279 | 438.77 |
| delta_roundtrip_100 | 2921 | 342.37 |
| battery_budget_single_sample | 8971092 | 0.11 |
| battery_budget_60_samples | 290915 | 3.44 |
| battery_budget_heavy_drain | 146538 | 6.82 |
| carbon_trip_100_locations | 89909 | 11.12 |
| carbon_onLocation | 4190618 | 0.24 |
| carbon_setActivity | 9726922 | 0.10 |
| carbon_cumulative_report | 2739526 | 0.37 |
| persist_decider_location | 19382523 | 0.05 |
| persist_decider_geofence | 19390989 | 0.05 |
| config_fromMap | 415755 | 2.41 |
| config_toMap | 153795 | 6.50 |
| config_roundtrip | 111147 | 9.00 |
| state_fromMap | 397301 | 2.52 |
| state_toMap | 144974 | 6.90 |
| route_context_toMap | 3092915 | 0.32 |
| route_context_fromMap | 2414930 | 0.41 |
| route_context_roundtrip | 1439410 | 0.69 |
| sync_body_context_toMap_50 | 8157144 | 0.12 |
| sync_body_context_fromMap_50 | 23076 | 43.33 |
| http_config_ssl_toMap | 739030 | 1.35 |
| http_config_ssl_fromMap | 1379606 | 0.72 |
| http_config_ssl_roundtrip | 494801 | 2.02 |


### 2026-04-16 — Commit 4e11632

**Environment:** Dart 3.11.4, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| kalman_process_single | 7303928 | 0.14 |
| kalman_process_100_fixes | 92282 | 10.84 |
| kalman_process_1k_fixes | 9565 | 104.54 |
| kalman_reset | 6693867 | 0.15 |
| haversine_single | 7812435 | 0.13 |
| haversine_1k_pairs | 13869 | 72.10 |
| pip_4v | 13263674 | 0.08 |
| pip_10v | 9980881 | 0.10 |
| pip_50v | 3747196 | 0.27 |
| pip_100v | 1919195 | 0.52 |
| pip_500v | 401787 | 2.49 |
| geofence_eval_10_circular | 636466 | 1.57 |
| geofence_eval_100_circular | 69983 | 14.29 |
| geofence_eval_500_circular | 13411 | 74.57 |
| geofence_eval_10_polygon_6v | 415561 | 2.41 |
| geofence_eval_50_polygon_6v | 84128 | 11.89 |
| processor_1k_fixes | 8768 | 114.06 |
| processor_1k_adaptive | 8272 | 120.89 |
| trip_manager_5k_waypoints | 73 | 13729.40 |
| schedule_parse | 2874979 | 0.35 |
| schedule_matches | 130900 | 7.64 |
| schedule_isWithin_5_entries | 123659 | 8.09 |
| adaptive_compute | 13493486 | 0.07 |
| location_fromMap | 1701092 | 0.59 |
| location_toMap | 673236 | 1.49 |
| location_fromMap_toMap_roundtrip | 483054 | 2.07 |
| location_copyWithCoords | 12061659 | 0.08 |
| geofence_fromMap_circular | 4379865 | 0.23 |
| geofence_fromMap_polygon | 1555462 | 0.64 |
| delta_encode_10 | 28001 | 35.71 |
| delta_decode_10 | 95687 | 10.45 |
| delta_encode_100 | 4009 | 249.41 |
| delta_decode_100 | 10536 | 94.91 |
| delta_encode_500 | 826 | 1209.97 |
| delta_decode_500 | 2121 | 471.38 |
| delta_roundtrip_100 | 2943 | 339.79 |
| battery_budget_single_sample | 9204763 | 0.11 |
| battery_budget_60_samples | 295473 | 3.38 |
| battery_budget_heavy_drain | 149454 | 6.69 |
| carbon_trip_100_locations | 89685 | 11.15 |
| carbon_onLocation | 4132270 | 0.24 |
| carbon_setActivity | 9874118 | 0.10 |
| carbon_cumulative_report | 2714165 | 0.37 |
| persist_decider_location | 19983805 | 0.05 |
| persist_decider_geofence | 20080365 | 0.05 |
| config_fromMap | 419495 | 2.38 |
| config_toMap | 157098 | 6.37 |
| config_roundtrip | 112182 | 8.91 |
| state_fromMap | 402684 | 2.48 |
| state_toMap | 148916 | 6.72 |
| route_context_toMap | 3088125 | 0.32 |
| route_context_fromMap | 2431360 | 0.41 |
| route_context_roundtrip | 1441126 | 0.69 |
| sync_body_context_toMap_50 | 8491809 | 0.12 |
| sync_body_context_fromMap_50 | 23046 | 43.39 |
| http_config_ssl_toMap | 753570 | 1.33 |
| http_config_ssl_fromMap | 1449562 | 0.69 |
| http_config_ssl_roundtrip | 509521 | 1.96 |


