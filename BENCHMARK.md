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

### 2026-05-30 — Commit f338066

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 84175 | 11.88 |
| schedule_isWithin_5_entries | 73421 | 13.62 |
| location_fromMap | 1724137 | 0.58 |
| location_toMap | 636942 | 1.57 |
| location_fromMap_toMap_roundtrip | 465116 | 2.15 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4761904 | 0.21 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 92165 | 10.85 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 467289 | 2.14 |
| config_toMap | 126582 | 7.90 |
| config_roundtrip | 97656 | 10.24 |
| state_fromMap | 434782 | 2.30 |
| state_toMap | 120918 | 8.27 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22050 | 45.35 |
| http_config_ssl_toMap | 763358 | 1.31 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 628930 | 1.59 |
| battery_budget_heavy_drain | 559678 | 1.79 |
| smart_motion_accel_change | 18740107 | 0.05 |
| battery_budget_60_samples | 1087845 | 0.92 |
| battery_budget_single_sample | 21753248 | 0.05 |
| smart_motion_speed_change | 17709213 | 0.06 |


### 2026-05-30 — Commit 387728d

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 3571428 | 0.28 |
| schedule_matches | 104602 | 9.56 |
| schedule_isWithin_5_entries | 92336 | 10.83 |
| location_fromMap | 2127659 | 0.47 |
| location_toMap | 833333 | 1.20 |
| location_fromMap_toMap_roundtrip | 609756 | 1.64 |
| location_copyWithCoords | 14285714 | 0.07 |
| geofence_fromMap_circular | 5555555 | 0.18 |
| geofence_fromMap_polygon | 2000000 | 0.50 |
| carbon_trip_100_locations | 117785 | 8.49 |
| carbon_onLocation | 5263157 | 0.19 |
| carbon_setActivity | 11111111 | 0.09 |
| carbon_cumulative_report | 3225806 | 0.31 |
| persist_decider_location | 25000000 | 0.04 |
| persist_decider_geofence | 25000000 | 0.04 |
| config_fromMap | 588235 | 1.70 |
| config_toMap | 163132 | 6.13 |
| config_roundtrip | 126422 | 7.91 |
| state_fromMap | 552486 | 1.81 |
| state_toMap | 158478 | 6.31 |
| route_context_toMap | 3703703 | 0.27 |
| route_context_fromMap | 2857142 | 0.35 |
| route_context_roundtrip | 1694915 | 0.59 |
| sync_body_context_toMap_50 | 10000000 | 0.10 |
| sync_body_context_fromMap_50 | 27770 | 36.01 |
| http_config_ssl_toMap | 1000000 | 1.00 |
| http_config_ssl_fromMap | 4000000 | 0.25 |
| http_config_ssl_roundtrip | 819672 | 1.22 |
| smart_motion_accel_change | 24590545 | 0.04 |
| battery_budget_60_samples | 1449367 | 0.69 |
| battery_budget_heavy_drain | 750722 | 1.33 |
| battery_budget_single_sample | 25789395 | 0.04 |
| smart_motion_speed_change | 23482251 | 0.04 |


### 2026-05-30 — Commit d246919

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 80064 | 12.49 |
| schedule_isWithin_5_entries | 69783 | 14.33 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 641025 | 1.56 |
| location_fromMap_toMap_roundtrip | 469483 | 2.13 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 90909 | 11.00 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 450450 | 2.22 |
| config_toMap | 125470 | 7.97 |
| config_roundtrip | 96246 | 10.39 |
| state_fromMap | 425531 | 2.35 |
| state_toMap | 123001 | 8.13 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21477 | 46.56 |
| http_config_ssl_toMap | 769230 | 1.30 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 645161 | 1.55 |
| battery_budget_single_sample | 20026187 | 0.05 |
| smart_motion_accel_change | 19106117 | 0.05 |
| battery_budget_heavy_drain | 583019 | 1.72 |
| smart_motion_speed_change | 18340762 | 0.05 |
| battery_budget_60_samples | 1131040 | 0.88 |


### 2026-05-30 — Commit e5e5fe4

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2631578 | 0.38 |
| schedule_matches | 85836 | 11.65 |
| schedule_isWithin_5_entries | 73046 | 13.69 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 469483 | 2.13 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 92764 | 10.78 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 8333333 | 0.12 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 454545 | 2.20 |
| config_toMap | 127713 | 7.83 |
| config_roundtrip | 97943 | 10.21 |
| state_fromMap | 427350 | 2.34 |
| state_toMap | 122549 | 8.16 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 22241 | 44.96 |
| http_config_ssl_toMap | 769230 | 1.30 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 641025 | 1.56 |
| battery_budget_heavy_drain | 560588 | 1.78 |
| smart_motion_speed_change | 17841404 | 0.06 |
| battery_budget_single_sample | 21748841 | 0.05 |
| battery_budget_60_samples | 1087606 | 0.92 |
| smart_motion_accel_change | 19050804 | 0.05 |


### 2026-05-30 — Commit 008b4c3

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 86430 | 11.57 |
| schedule_isWithin_5_entries | 74738 | 13.38 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 653594 | 1.53 |
| location_fromMap_toMap_roundtrip | 469483 | 2.13 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 91074 | 10.98 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 473933 | 2.11 |
| config_toMap | 129032 | 7.75 |
| config_roundtrip | 100401 | 9.96 |
| state_fromMap | 442477 | 2.26 |
| state_toMap | 122549 | 8.16 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1408450 | 0.71 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22644 | 44.16 |
| http_config_ssl_toMap | 775193 | 1.29 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 636942 | 1.57 |
| battery_budget_single_sample | 21759811 | 0.05 |
| battery_budget_60_samples | 1091080 | 0.92 |
| smart_motion_accel_change | 19071180 | 0.05 |
| battery_budget_heavy_drain | 561915 | 1.78 |
| smart_motion_speed_change | 17864298 | 0.06 |


### 2026-05-30 — Commit eabd36a

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 3030303 | 0.33 |
| schedule_matches | 140449 | 7.12 |
| schedule_isWithin_5_entries | 113636 | 8.80 |
| location_fromMap | 1754385 | 0.57 |
| location_toMap | 671140 | 1.49 |
| location_fromMap_toMap_roundtrip | 487804 | 2.05 |
| location_copyWithCoords | 12500000 | 0.08 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1694915 | 0.59 |
| carbon_trip_100_locations | 113378 | 8.82 |
| carbon_onLocation | 4347826 | 0.23 |
| carbon_setActivity | 10000000 | 0.10 |
| carbon_cumulative_report | 2631578 | 0.38 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 500000 | 2.00 |
| config_toMap | 136612 | 7.32 |
| config_roundtrip | 106157 | 9.42 |
| state_fromMap | 471698 | 2.12 |
| state_toMap | 130890 | 7.64 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2439024 | 0.41 |
| route_context_roundtrip | 1428571 | 0.70 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 23094 | 43.30 |
| http_config_ssl_toMap | 819672 | 1.22 |
| http_config_ssl_fromMap | 3333333 | 0.30 |
| http_config_ssl_roundtrip | 680272 | 1.47 |
| battery_budget_single_sample | 21813466 | 0.05 |
| battery_budget_heavy_drain | 407929 | 2.45 |
| smart_motion_speed_change | 16054257 | 0.06 |
| battery_budget_60_samples | 806257 | 1.24 |
| smart_motion_accel_change | 16196401 | 0.06 |


### 2026-05-30 — Commit a8eb7cd

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 83682 | 11.95 |
| schedule_isWithin_5_entries | 74794 | 13.37 |
| location_fromMap | 1724137 | 0.58 |
| location_toMap | 613496 | 1.63 |
| location_fromMap_toMap_roundtrip | 448430 | 2.23 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 78308 | 12.77 |
| carbon_onLocation | 3703703 | 0.27 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2380952 | 0.42 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 444444 | 2.25 |
| config_toMap | 124223 | 8.05 |
| config_roundtrip | 96432 | 10.37 |
| state_fromMap | 420168 | 2.38 |
| state_toMap | 120627 | 8.29 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2127659 | 0.47 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21881 | 45.70 |
| http_config_ssl_toMap | 763358 | 1.31 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 632911 | 1.58 |
| smart_motion_accel_change | 18684603 | 0.05 |
| battery_budget_single_sample | 21695686 | 0.05 |
| battery_budget_60_samples | 1050493 | 0.95 |
| smart_motion_speed_change | 17749473 | 0.06 |
| battery_budget_heavy_drain | 540469 | 1.85 |


### 2026-05-30 — Commit 204528d

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 87950 | 11.37 |
| schedule_isWithin_5_entries | 77101 | 12.97 |
| location_fromMap | 1724137 | 0.58 |
| location_toMap | 641025 | 1.56 |
| location_fromMap_toMap_roundtrip | 478468 | 2.09 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 92250 | 10.84 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2631578 | 0.38 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 456621 | 2.19 |
| config_toMap | 130039 | 7.69 |
| config_roundtrip | 101317 | 9.87 |
| state_fromMap | 446428 | 2.24 |
| state_toMap | 123001 | 8.13 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1388888 | 0.72 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22446 | 44.55 |
| http_config_ssl_toMap | 763358 | 1.31 |
| http_config_ssl_fromMap | 3333333 | 0.30 |
| http_config_ssl_roundtrip | 641025 | 1.56 |
| smart_motion_speed_change | 17872183 | 0.06 |
| battery_budget_single_sample | 21767652 | 0.05 |
| battery_budget_60_samples | 1090663 | 0.92 |
| smart_motion_accel_change | 19015531 | 0.05 |
| battery_budget_heavy_drain | 562195 | 1.78 |


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


