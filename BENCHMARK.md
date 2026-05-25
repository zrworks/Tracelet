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

### 2026-05-25 — Commit dab8afc

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 96432 | 10.37 |
| schedule_isWithin_5_entries | 91659 | 10.91 |
| location_fromMap | 1754385 | 0.57 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 471698 | 2.12 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1515151 | 0.66 |
| carbon_trip_100_locations | 92936 | 10.76 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 473933 | 2.11 |
| config_toMap | 129366 | 7.73 |
| config_roundtrip | 99800 | 10.02 |
| state_fromMap | 446428 | 2.24 |
| state_toMap | 124223 | 8.05 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1408450 | 0.71 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22366 | 44.71 |
| http_config_ssl_toMap | 775193 | 1.29 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 636942 | 1.57 |
| battery_budget_single_sample | 23954625 | 0.04 |
| smart_motion_speed_change | 25715590 | 0.04 |
| battery_budget_60_samples | 1767759 | 0.57 |
| battery_budget_heavy_drain | 913212 | 1.10 |
| smart_motion_accel_change | 25863904 | 0.04 |


### 2026-05-25 — Commit b94ae85

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2564102 | 0.39 |
| schedule_matches | 94428 | 10.59 |
| schedule_isWithin_5_entries | 87032 | 11.49 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 471698 | 2.12 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 90415 | 11.06 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 452488 | 2.21 |
| config_toMap | 123456 | 8.10 |
| config_roundtrip | 96899 | 10.32 |
| state_fromMap | 429184 | 2.33 |
| state_toMap | 121212 | 8.25 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21791 | 45.89 |
| http_config_ssl_toMap | 763358 | 1.31 |
| http_config_ssl_fromMap | 3333333 | 0.30 |
| http_config_ssl_roundtrip | 625000 | 1.60 |
| battery_budget_60_samples | 1767590 | 0.57 |
| smart_motion_speed_change | 25691165 | 0.04 |
| smart_motion_accel_change | 25846884 | 0.04 |
| battery_budget_single_sample | 23934618 | 0.04 |
| battery_budget_heavy_drain | 911841 | 1.10 |


### 2026-05-25 — Commit 0639185

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 97943 | 10.21 |
| schedule_isWithin_5_entries | 91074 | 10.98 |
| location_fromMap | 1724137 | 0.58 |
| location_toMap | 653594 | 1.53 |
| location_fromMap_toMap_roundtrip | 467289 | 2.14 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4761904 | 0.21 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 93545 | 10.69 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2631578 | 0.38 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 469483 | 2.13 |
| config_toMap | 127551 | 7.84 |
| config_roundtrip | 100000 | 10.00 |
| state_fromMap | 436681 | 2.29 |
| state_toMap | 123456 | 8.10 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1315789 | 0.76 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22588 | 44.27 |
| http_config_ssl_toMap | 793650 | 1.26 |
| http_config_ssl_fromMap | 3333333 | 0.30 |
| http_config_ssl_roundtrip | 636942 | 1.57 |
| battery_budget_60_samples | 1735379 | 0.58 |
| battery_budget_heavy_drain | 891982 | 1.12 |
| smart_motion_speed_change | 25713299 | 0.04 |
| smart_motion_accel_change | 25879260 | 0.04 |
| battery_budget_single_sample | 24141037 | 0.04 |


### 2026-05-25 — Commit e33c551

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 3571428 | 0.28 |
| schedule_matches | 112233 | 8.91 |
| schedule_isWithin_5_entries | 104931 | 9.53 |
| location_fromMap | 2173913 | 0.46 |
| location_toMap | 847457 | 1.18 |
| location_fromMap_toMap_roundtrip | 613496 | 1.63 |
| location_copyWithCoords | 14285714 | 0.07 |
| geofence_fromMap_circular | 5882352 | 0.17 |
| geofence_fromMap_polygon | 2040816 | 0.49 |
| carbon_trip_100_locations | 114547 | 8.73 |
| carbon_onLocation | 5000000 | 0.20 |
| carbon_setActivity | 11111111 | 0.09 |
| carbon_cumulative_report | 3225806 | 0.31 |
| persist_decider_location | 25000000 | 0.04 |
| persist_decider_geofence | 25000000 | 0.04 |
| config_fromMap | 591715 | 1.69 |
| config_toMap | 165562 | 6.04 |
| config_roundtrip | 126903 | 7.88 |
| state_fromMap | 558659 | 1.79 |
| state_toMap | 158227 | 6.32 |
| route_context_toMap | 3846153 | 0.26 |
| route_context_fromMap | 2777777 | 0.36 |
| route_context_roundtrip | 1724137 | 0.58 |
| sync_body_context_toMap_50 | 10000000 | 0.10 |
| sync_body_context_fromMap_50 | 28129 | 35.55 |
| http_config_ssl_toMap | 1020408 | 0.98 |
| http_config_ssl_fromMap | 4166666 | 0.24 |
| http_config_ssl_roundtrip | 840336 | 1.19 |
| battery_budget_60_samples | 2434853 | 0.41 |
| smart_motion_accel_change | 31068875 | 0.03 |
| battery_budget_single_sample | 29092823 | 0.03 |
| battery_budget_heavy_drain | 1261837 | 0.79 |
| smart_motion_speed_change | 30702477 | 0.03 |


### 2026-05-25 — Commit 8836e8a

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 94607 | 10.57 |
| schedule_isWithin_5_entries | 90991 | 10.99 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 653594 | 1.53 |
| location_fromMap_toMap_roundtrip | 478468 | 2.09 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 91575 | 10.92 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 476190 | 2.10 |
| config_toMap | 130208 | 7.68 |
| config_roundtrip | 101522 | 9.85 |
| state_fromMap | 450450 | 2.22 |
| state_toMap | 123152 | 8.12 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 20597 | 48.55 |
| http_config_ssl_toMap | 769230 | 1.30 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 641025 | 1.56 |
| battery_budget_60_samples | 1768327 | 0.57 |
| battery_budget_single_sample | 23962423 | 0.04 |
| smart_motion_speed_change | 25690234 | 0.04 |
| battery_budget_heavy_drain | 906891 | 1.10 |
| smart_motion_accel_change | 25868147 | 0.04 |


### 2026-05-25 — Commit a96d7b3

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2631578 | 0.38 |
| schedule_matches | 122249 | 8.18 |
| schedule_isWithin_5_entries | 121212 | 8.25 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 471698 | 2.12 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 93457 | 10.70 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 476190 | 2.10 |
| config_toMap | 128534 | 7.78 |
| config_roundtrip | 99403 | 10.06 |
| state_fromMap | 438596 | 2.28 |
| state_toMap | 123915 | 8.07 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2380952 | 0.42 |
| route_context_roundtrip | 1449275 | 0.69 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 22341 | 44.76 |
| http_config_ssl_toMap | 781250 | 1.28 |
| http_config_ssl_fromMap | 3333333 | 0.30 |
| http_config_ssl_roundtrip | 636942 | 1.57 |
| battery_budget_60_samples | 1758109 | 0.57 |
| battery_budget_heavy_drain | 906297 | 1.10 |
| smart_motion_accel_change | 25937645 | 0.04 |
| smart_motion_speed_change | 25716780 | 0.04 |
| battery_budget_single_sample | 24403575 | 0.04 |


### 2026-05-25 — Commit 10e6198

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 130208 | 7.68 |
| schedule_isWithin_5_entries | 121506 | 8.23 |
| location_fromMap | 1724137 | 0.58 |
| location_toMap | 617283 | 1.62 |
| location_fromMap_toMap_roundtrip | 480769 | 2.08 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 93023 | 10.75 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 473933 | 2.11 |
| config_toMap | 130718 | 7.65 |
| config_roundtrip | 101317 | 9.87 |
| state_fromMap | 456621 | 2.19 |
| state_toMap | 123915 | 8.07 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2380952 | 0.42 |
| route_context_roundtrip | 1408450 | 0.71 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22401 | 44.64 |
| http_config_ssl_toMap | 775193 | 1.29 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 645161 | 1.55 |
| battery_budget_heavy_drain | 901174 | 1.11 |
| smart_motion_speed_change | 25703974 | 0.04 |
| battery_budget_60_samples | 1747886 | 0.57 |
| smart_motion_accel_change | 25913960 | 0.04 |
| battery_budget_single_sample | 24411426 | 0.04 |


### 2026-05-25 — Commit a506e7a

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2738227 | 0.37 |
| schedule_matches | 129048 | 7.75 |
| schedule_isWithin_5_entries | 120717 | 8.28 |
| location_fromMap | 1685811 | 0.59 |
| location_toMap | 631901 | 1.58 |
| location_fromMap_toMap_roundtrip | 467250 | 2.14 |
| location_copyWithCoords | 9926767 | 0.10 |
| geofence_fromMap_circular | 4115895 | 0.24 |
| geofence_fromMap_polygon | 1534734 | 0.65 |
| carbon_trip_100_locations | 93382 | 10.71 |
| carbon_onLocation | 3920541 | 0.26 |
| carbon_setActivity | 8416146 | 0.12 |
| carbon_cumulative_report | 2521059 | 0.40 |
| persist_decider_location | 15699719 | 0.06 |
| persist_decider_geofence | 15693033 | 0.06 |
| config_fromMap | 462051 | 2.16 |
| config_toMap | 127468 | 7.85 |
| config_roundtrip | 99000 | 10.10 |
| state_fromMap | 431215 | 2.32 |
| state_toMap | 122737 | 8.15 |
| route_context_toMap | 2878209 | 0.35 |
| route_context_fromMap | 2279196 | 0.44 |
| route_context_roundtrip | 1391391 | 0.72 |
| sync_body_context_toMap_50 | 7321693 | 0.14 |
| sync_body_context_fromMap_50 | 22372 | 44.70 |
| http_config_ssl_toMap | 778365 | 1.28 |
| http_config_ssl_fromMap | 3172445 | 0.32 |
| http_config_ssl_roundtrip | 630118 | 1.59 |


### 2026-05-25 — Commit c053ef9

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2732644 | 0.37 |
| schedule_matches | 130265 | 7.68 |
| schedule_isWithin_5_entries | 123070 | 8.13 |
| location_fromMap | 1668625 | 0.60 |
| location_toMap | 648876 | 1.54 |
| location_fromMap_toMap_roundtrip | 469821 | 2.13 |
| location_copyWithCoords | 11375610 | 0.09 |
| geofence_fromMap_circular | 4354608 | 0.23 |
| geofence_fromMap_polygon | 1549172 | 0.65 |
| carbon_trip_100_locations | 93992 | 10.64 |
| carbon_onLocation | 4136565 | 0.24 |
| carbon_setActivity | 9342631 | 0.11 |
| carbon_cumulative_report | 2585585 | 0.39 |
| persist_decider_location | 20282385 | 0.05 |
| persist_decider_geofence | 20273189 | 0.05 |
| config_fromMap | 477030 | 2.10 |
| config_toMap | 129390 | 7.73 |
| config_roundtrip | 99952 | 10.00 |
| state_fromMap | 452847 | 2.21 |
| state_toMap | 122266 | 8.18 |
| route_context_toMap | 2978841 | 0.34 |
| route_context_fromMap | 2426101 | 0.41 |
| route_context_roundtrip | 1424773 | 0.70 |
| sync_body_context_toMap_50 | 7964500 | 0.13 |
| sync_body_context_fromMap_50 | 22341 | 44.76 |
| http_config_ssl_toMap | 777786 | 1.29 |
| http_config_ssl_fromMap | 3288619 | 0.30 |
| http_config_ssl_roundtrip | 646095 | 1.55 |


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


