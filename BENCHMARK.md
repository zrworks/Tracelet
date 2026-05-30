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

### 2026-05-30 — Commit 151f45a

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2631578 | 0.38 |
| schedule_matches | 79302 | 12.61 |
| schedule_isWithin_5_entries | 69930 | 14.30 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 476190 | 2.10 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 91240 | 10.96 |
| carbon_onLocation | 3846153 | 0.26 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 429184 | 2.33 |
| config_toMap | 127877 | 7.82 |
| config_roundtrip | 97656 | 10.24 |
| state_fromMap | 432900 | 2.31 |
| state_toMap | 123456 | 8.10 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21982 | 45.49 |
| http_config_ssl_toMap | 787401 | 1.27 |
| http_config_ssl_fromMap | 3125000 | 0.32 |
| http_config_ssl_roundtrip | 649350 | 1.54 |
| battery_budget_single_sample | 20011420 | 0.05 |
| battery_budget_heavy_drain | 577655 | 1.73 |
| smart_motion_speed_change | 18267281 | 0.05 |
| battery_budget_60_samples | 1124761 | 0.89 |
| smart_motion_accel_change | 19081218 | 0.05 |


### 2026-05-30 — Commit 1643885

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 85251 | 11.73 |
| schedule_isWithin_5_entries | 74294 | 13.46 |
| location_fromMap | 1612903 | 0.62 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 469483 | 2.13 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 92250 | 10.84 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 454545 | 2.20 |
| config_toMap | 127226 | 7.86 |
| config_roundtrip | 98328 | 10.17 |
| state_fromMap | 423728 | 2.36 |
| state_toMap | 122249 | 8.18 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1388888 | 0.72 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 22451 | 44.54 |
| http_config_ssl_toMap | 769230 | 1.30 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 636942 | 1.57 |
| battery_budget_heavy_drain | 560294 | 1.78 |
| battery_budget_single_sample | 21742135 | 0.05 |
| battery_budget_60_samples | 1088052 | 0.92 |
| smart_motion_accel_change | 18157521 | 0.06 |
| smart_motion_speed_change | 17690790 | 0.06 |


### 2026-05-30 — Commit cbb1d6f

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 79554 | 12.57 |
| schedule_isWithin_5_entries | 71123 | 14.06 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 452488 | 2.21 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 87642 | 11.41 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 444444 | 2.25 |
| config_toMap | 127388 | 7.85 |
| config_roundtrip | 98425 | 10.16 |
| state_fromMap | 425531 | 2.35 |
| state_toMap | 121802 | 8.21 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21805 | 45.86 |
| http_config_ssl_toMap | 781250 | 1.28 |
| http_config_ssl_fromMap | 3125000 | 0.32 |
| http_config_ssl_roundtrip | 645161 | 1.55 |
| battery_budget_single_sample | 19984551 | 0.05 |
| battery_budget_heavy_drain | 582488 | 1.72 |
| battery_budget_60_samples | 1116132 | 0.90 |
| smart_motion_accel_change | 19045371 | 0.05 |
| smart_motion_speed_change | 18272035 | 0.05 |


### 2026-05-30 — Commit c866a49

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 79744 | 12.54 |
| schedule_isWithin_5_entries | 71022 | 14.08 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 653594 | 1.53 |
| location_fromMap_toMap_roundtrip | 471698 | 2.12 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1515151 | 0.66 |
| carbon_trip_100_locations | 91491 | 10.93 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 458715 | 2.18 |
| config_toMap | 127877 | 7.82 |
| config_roundtrip | 98814 | 10.12 |
| state_fromMap | 423728 | 2.36 |
| state_toMap | 121951 | 8.20 |
| route_context_toMap | 2857142 | 0.35 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21682 | 46.12 |
| http_config_ssl_toMap | 793650 | 1.26 |
| http_config_ssl_fromMap | 3125000 | 0.32 |
| http_config_ssl_roundtrip | 649350 | 1.54 |
| battery_budget_single_sample | 20020197 | 0.05 |
| smart_motion_accel_change | 19141739 | 0.05 |
| smart_motion_speed_change | 18374347 | 0.05 |
| battery_budget_60_samples | 1130266 | 0.88 |
| battery_budget_heavy_drain | 583228 | 1.71 |


### 2026-05-30 — Commit 7b14e5c

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 87796 | 11.39 |
| schedule_isWithin_5_entries | 74404 | 13.44 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 641025 | 1.56 |
| location_fromMap_toMap_roundtrip | 465116 | 2.15 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 91575 | 10.92 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2631578 | 0.38 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 467289 | 2.14 |
| config_toMap | 128700 | 7.77 |
| config_roundtrip | 99800 | 10.02 |
| state_fromMap | 444444 | 2.25 |
| state_toMap | 123001 | 8.13 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1315789 | 0.76 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22336 | 44.77 |
| http_config_ssl_toMap | 757575 | 1.32 |
| http_config_ssl_fromMap | 3333333 | 0.30 |
| http_config_ssl_roundtrip | 632911 | 1.58 |
| battery_budget_60_samples | 1089168 | 0.92 |
| battery_budget_heavy_drain | 562192 | 1.78 |
| smart_motion_speed_change | 17753930 | 0.06 |
| battery_budget_single_sample | 21719301 | 0.05 |
| smart_motion_accel_change | 18683287 | 0.05 |


### 2026-05-29 — Commit 783742b

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 79113 | 12.64 |
| schedule_isWithin_5_entries | 71174 | 14.05 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 641025 | 1.56 |
| location_fromMap_toMap_roundtrip | 467289 | 2.14 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 91157 | 10.97 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 456621 | 2.19 |
| config_toMap | 128205 | 7.80 |
| config_roundtrip | 98814 | 10.12 |
| state_fromMap | 413223 | 2.42 |
| state_toMap | 123001 | 8.13 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21805 | 45.86 |
| http_config_ssl_toMap | 775193 | 1.29 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 641025 | 1.56 |
| battery_budget_60_samples | 1129822 | 0.89 |
| battery_budget_heavy_drain | 582118 | 1.72 |
| smart_motion_accel_change | 19110677 | 0.05 |
| battery_budget_single_sample | 20010130 | 0.05 |
| smart_motion_speed_change | 18290696 | 0.05 |


### 2026-05-29 — Commit e959f9e

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 86132 | 11.61 |
| schedule_isWithin_5_entries | 74682 | 13.39 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 662251 | 1.51 |
| location_fromMap_toMap_roundtrip | 473933 | 2.11 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 94073 | 10.63 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2631578 | 0.38 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 460829 | 2.17 |
| config_toMap | 126903 | 7.88 |
| config_roundtrip | 98814 | 10.12 |
| state_fromMap | 427350 | 2.34 |
| state_toMap | 121506 | 8.23 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 22441 | 44.56 |
| http_config_ssl_toMap | 793650 | 1.26 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 645161 | 1.55 |
| smart_motion_accel_change | 18453186 | 0.05 |
| battery_budget_60_samples | 1090542 | 0.92 |
| battery_budget_heavy_drain | 561748 | 1.78 |
| battery_budget_single_sample | 21716467 | 0.05 |
| smart_motion_speed_change | 17862933 | 0.06 |


### 2026-05-29 — Commit 9b274a0

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 80710 | 12.39 |
| schedule_isWithin_5_entries | 70126 | 14.26 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 469483 | 2.13 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 90252 | 11.08 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 458715 | 2.18 |
| config_toMap | 129366 | 7.73 |
| config_roundtrip | 98716 | 10.13 |
| state_fromMap | 431034 | 2.32 |
| state_toMap | 123152 | 8.12 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21710 | 46.06 |
| http_config_ssl_toMap | 793650 | 1.26 |
| http_config_ssl_fromMap | 3125000 | 0.32 |
| http_config_ssl_roundtrip | 653594 | 1.53 |
| battery_budget_heavy_drain | 580906 | 1.72 |
| battery_budget_single_sample | 20025367 | 0.05 |
| smart_motion_accel_change | 19061078 | 0.05 |
| smart_motion_speed_change | 18237725 | 0.05 |
| battery_budget_60_samples | 1129918 | 0.89 |


### 2026-05-29 — Commit fff913d

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 84245 | 11.87 |
| schedule_isWithin_5_entries | 73475 | 13.61 |
| location_fromMap | 1724137 | 0.58 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 480769 | 2.08 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4761904 | 0.21 |
| geofence_fromMap_polygon | 1612903 | 0.62 |
| carbon_trip_100_locations | 91659 | 10.91 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 440528 | 2.27 |
| config_toMap | 127551 | 7.84 |
| config_roundtrip | 97847 | 10.22 |
| state_fromMap | 416666 | 2.40 |
| state_toMap | 121802 | 8.21 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1388888 | 0.72 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22075 | 45.30 |
| http_config_ssl_toMap | 775193 | 1.29 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 636942 | 1.57 |
| battery_budget_60_samples | 1088787 | 0.92 |
| battery_budget_single_sample | 21683710 | 0.05 |
| battery_budget_heavy_drain | 561276 | 1.78 |
| smart_motion_speed_change | 17688718 | 0.06 |
| smart_motion_accel_change | 18674667 | 0.05 |


### 2026-05-29 — Commit 339d2b6

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 79744 | 12.54 |
| schedule_isWithin_5_entries | 70972 | 14.09 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 641025 | 1.56 |
| location_fromMap_toMap_roundtrip | 473933 | 2.11 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 90171 | 11.09 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 448430 | 2.23 |
| config_toMap | 127713 | 7.83 |
| config_roundtrip | 96805 | 10.33 |
| state_fromMap | 425531 | 2.35 |
| state_toMap | 120772 | 8.28 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1298701 | 0.77 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21335 | 46.87 |
| http_config_ssl_toMap | 775193 | 1.29 |
| http_config_ssl_fromMap | 2941176 | 0.34 |
| http_config_ssl_roundtrip | 632911 | 1.58 |
| smart_motion_accel_change | 19056997 | 0.05 |
| battery_budget_single_sample | 19886251 | 0.05 |
| battery_budget_60_samples | 1125692 | 0.89 |
| battery_budget_heavy_drain | 579883 | 1.72 |
| smart_motion_speed_change | 18239125 | 0.05 |


