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

### 2026-05-27 — Commit 3decb4b

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 93896 | 10.65 |
| schedule_isWithin_5_entries | 87873 | 11.38 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 636942 | 1.57 |
| location_fromMap_toMap_roundtrip | 465116 | 2.15 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 91996 | 10.87 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 465116 | 2.15 |
| config_toMap | 125313 | 7.98 |
| config_roundtrip | 96899 | 10.32 |
| state_fromMap | 436681 | 2.29 |
| state_toMap | 120481 | 8.30 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1388888 | 0.72 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 22128 | 45.19 |
| http_config_ssl_toMap | 757575 | 1.32 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 632911 | 1.58 |
| smart_motion_accel_change | 26177706 | 0.04 |
| battery_budget_heavy_drain | 919906 | 1.09 |
| battery_budget_single_sample | 24555511 | 0.04 |
| battery_budget_60_samples | 1771269 | 0.56 |
| smart_motion_speed_change | 25601779 | 0.04 |


### 2026-05-27 — Commit 7f37c49

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 88028 | 11.36 |
| schedule_isWithin_5_entries | 81833 | 12.22 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 641025 | 1.56 |
| location_fromMap_toMap_roundtrip | 471698 | 2.12 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 90252 | 11.08 |
| carbon_onLocation | 3846153 | 0.26 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 440528 | 2.27 |
| config_toMap | 127877 | 7.82 |
| config_roundtrip | 98135 | 10.19 |
| state_fromMap | 416666 | 2.40 |
| state_toMap | 122100 | 8.19 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2127659 | 0.47 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21556 | 46.39 |
| http_config_ssl_toMap | 781250 | 1.28 |
| http_config_ssl_fromMap | 3125000 | 0.32 |
| http_config_ssl_roundtrip | 641025 | 1.56 |
| smart_motion_accel_change | 24083440 | 0.04 |
| battery_budget_60_samples | 1876136 | 0.53 |
| battery_budget_single_sample | 22561946 | 0.04 |
| smart_motion_speed_change | 23890326 | 0.04 |
| battery_budget_heavy_drain | 972508 | 1.03 |


### 2026-05-27 — Commit e1f9848

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 3030303 | 0.33 |
| schedule_matches | 155520 | 6.43 |
| schedule_isWithin_5_entries | 136798 | 7.31 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 628930 | 1.59 |
| location_fromMap_toMap_roundtrip | 465116 | 2.15 |
| location_copyWithCoords | 12500000 | 0.08 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1666666 | 0.60 |
| carbon_trip_100_locations | 108577 | 9.21 |
| carbon_onLocation | 4347826 | 0.23 |
| carbon_setActivity | 10000000 | 0.10 |
| carbon_cumulative_report | 2702702 | 0.37 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 469483 | 2.13 |
| config_toMap | 131233 | 7.62 |
| config_roundtrip | 103305 | 9.68 |
| state_fromMap | 446428 | 2.24 |
| state_toMap | 125944 | 7.94 |
| route_context_toMap | 2857142 | 0.35 |
| route_context_fromMap | 2380952 | 0.42 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22451 | 44.54 |
| http_config_ssl_toMap | 787401 | 1.27 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 657894 | 1.52 |
| smart_motion_accel_change | 19618896 | 0.05 |
| battery_budget_heavy_drain | 473696 | 2.11 |
| smart_motion_speed_change | 18196757 | 0.05 |
| battery_budget_single_sample | 24102367 | 0.04 |
| battery_budget_60_samples | 937275 | 1.07 |


### 2026-05-27 — Commit af26aae

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 97276 | 10.28 |
| schedule_isWithin_5_entries | 88888 | 11.25 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 467289 | 2.14 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1492537 | 0.67 |
| carbon_trip_100_locations | 93808 | 10.66 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 471698 | 2.12 |
| config_toMap | 130718 | 7.65 |
| config_roundtrip | 99700 | 10.03 |
| state_fromMap | 432900 | 2.31 |
| state_toMap | 123152 | 8.12 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1388888 | 0.72 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 21602 | 46.29 |
| http_config_ssl_toMap | 775193 | 1.29 |
| http_config_ssl_fromMap | 3333333 | 0.30 |
| http_config_ssl_roundtrip | 641025 | 1.56 |
| battery_budget_heavy_drain | 919811 | 1.09 |
| smart_motion_accel_change | 25936045 | 0.04 |
| battery_budget_60_samples | 1783974 | 0.56 |
| battery_budget_single_sample | 26092368 | 0.04 |
| smart_motion_speed_change | 25683191 | 0.04 |


### 2026-05-26 — Commit 39a7f63

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 94339 | 10.60 |
| schedule_isWithin_5_entries | 89047 | 11.23 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 641025 | 1.56 |
| location_fromMap_toMap_roundtrip | 473933 | 2.11 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 91996 | 10.87 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 454545 | 2.20 |
| config_toMap | 127064 | 7.87 |
| config_roundtrip | 98425 | 10.16 |
| state_fromMap | 420168 | 2.38 |
| state_toMap | 121951 | 8.20 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1388888 | 0.72 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22256 | 44.93 |
| http_config_ssl_toMap | 781250 | 1.28 |
| http_config_ssl_fromMap | 3333333 | 0.30 |
| http_config_ssl_roundtrip | 645161 | 1.55 |
| battery_budget_heavy_drain | 912598 | 1.10 |
| battery_budget_60_samples | 1767476 | 0.57 |
| battery_budget_single_sample | 24142475 | 0.04 |
| smart_motion_accel_change | 25875783 | 0.04 |
| smart_motion_speed_change | 25709650 | 0.04 |


### 2026-05-26 — Commit 0ad8eeb

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 86655 | 11.54 |
| schedule_isWithin_5_entries | 80321 | 12.45 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 632911 | 1.58 |
| location_fromMap_toMap_roundtrip | 462962 | 2.16 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 90661 | 11.03 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 452488 | 2.21 |
| config_toMap | 127713 | 7.83 |
| config_roundtrip | 97656 | 10.24 |
| state_fromMap | 423728 | 2.36 |
| state_toMap | 120336 | 8.31 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21748 | 45.98 |
| http_config_ssl_toMap | 781250 | 1.28 |
| http_config_ssl_fromMap | 3125000 | 0.32 |
| http_config_ssl_roundtrip | 636942 | 1.57 |
| battery_budget_heavy_drain | 976567 | 1.02 |
| smart_motion_speed_change | 23891931 | 0.04 |
| battery_budget_60_samples | 1886889 | 0.53 |
| battery_budget_single_sample | 22395552 | 0.04 |
| smart_motion_accel_change | 24097607 | 0.04 |


### 2026-05-26 — Commit c13a32a

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 96993 | 10.31 |
| schedule_isWithin_5_entries | 90661 | 11.03 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 636942 | 1.57 |
| location_fromMap_toMap_roundtrip | 462962 | 2.16 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 93720 | 10.67 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 467289 | 2.14 |
| config_toMap | 128369 | 7.79 |
| config_roundtrip | 99304 | 10.07 |
| state_fromMap | 450450 | 2.22 |
| state_toMap | 121951 | 8.20 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1388888 | 0.72 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 22522 | 44.40 |
| http_config_ssl_toMap | 769230 | 1.30 |
| http_config_ssl_fromMap | 3333333 | 0.30 |
| http_config_ssl_roundtrip | 636942 | 1.57 |
| battery_budget_heavy_drain | 910231 | 1.10 |
| battery_budget_60_samples | 1763398 | 0.57 |
| battery_budget_single_sample | 23941783 | 0.04 |
| smart_motion_accel_change | 25734704 | 0.04 |
| smart_motion_speed_change | 25452531 | 0.04 |


### 2026-05-25 — Commit 024145c

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 94696 | 10.56 |
| schedule_isWithin_5_entries | 90579 | 11.04 |
| location_fromMap | 1724137 | 0.58 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 476190 | 2.10 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4761904 | 0.21 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 92081 | 10.86 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 471698 | 2.12 |
| config_toMap | 126582 | 7.90 |
| config_roundtrip | 98039 | 10.20 |
| state_fromMap | 446428 | 2.24 |
| state_toMap | 123001 | 8.13 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1388888 | 0.72 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22406 | 44.63 |
| http_config_ssl_toMap | 769230 | 1.30 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 641025 | 1.56 |
| battery_budget_single_sample | 23722936 | 0.04 |
| smart_motion_accel_change | 25734967 | 0.04 |
| battery_budget_heavy_drain | 912085 | 1.10 |
| smart_motion_speed_change | 25696396 | 0.04 |
| battery_budget_60_samples | 1768508 | 0.57 |


### 2026-05-25 — Commit 7d3f399

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 92936 | 10.76 |
| schedule_isWithin_5_entries | 87719 | 11.40 |
| location_fromMap | 1754385 | 0.57 |
| location_toMap | 657894 | 1.52 |
| location_fromMap_toMap_roundtrip | 480769 | 2.08 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4761904 | 0.21 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 94517 | 10.58 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 462962 | 2.16 |
| config_toMap | 130208 | 7.68 |
| config_roundtrip | 99502 | 10.05 |
| state_fromMap | 438596 | 2.28 |
| state_toMap | 123609 | 8.09 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1428571 | 0.70 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22461 | 44.52 |
| http_config_ssl_toMap | 781250 | 1.28 |
| http_config_ssl_fromMap | 3225806 | 0.31 |
| http_config_ssl_roundtrip | 645161 | 1.55 |
| battery_budget_single_sample | 23962610 | 0.04 |
| battery_budget_heavy_drain | 892678 | 1.12 |
| smart_motion_accel_change | 25789901 | 0.04 |
| battery_budget_60_samples | 1731367 | 0.58 |
| smart_motion_speed_change | 25696096 | 0.04 |


### 2026-05-25 — Commit 732fbd5

**Environment:** Dart 3.12.0, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 86430 | 11.57 |
| schedule_isWithin_5_entries | 81499 | 12.27 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 465116 | 2.15 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4166666 | 0.24 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 89126 | 11.22 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 16666666 | 0.06 |
| persist_decider_geofence | 16666666 | 0.06 |
| config_fromMap | 456621 | 2.19 |
| config_toMap | 129701 | 7.71 |
| config_roundtrip | 99403 | 10.06 |
| state_fromMap | 429184 | 2.33 |
| state_toMap | 121359 | 8.24 |
| route_context_toMap | 2857142 | 0.35 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 22021 | 45.41 |
| http_config_ssl_toMap | 781250 | 1.28 |
| http_config_ssl_fromMap | 3125000 | 0.32 |
| http_config_ssl_roundtrip | 645161 | 1.55 |
| battery_budget_single_sample | 22557052 | 0.04 |
| smart_motion_speed_change | 23887461 | 0.04 |
| battery_budget_60_samples | 1884524 | 0.53 |
| smart_motion_accel_change | 23976183 | 0.04 |
| battery_budget_heavy_drain | 978382 | 1.02 |


