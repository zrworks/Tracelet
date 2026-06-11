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

### 2026-06-11 — Commit db5b5c5c

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 85178 | 11.74 |
| schedule_isWithin_5_entries | 77160 | 12.96 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 595238 | 1.68 |
| location_fromMap_toMap_roundtrip | 465116 | 2.15 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 92165 | 10.85 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 442477 | 2.26 |
| config_toMap | 126742 | 7.89 |
| config_roundtrip | 97656 | 10.24 |
| state_fromMap | 421940 | 2.37 |
| state_toMap | 121065 | 8.26 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1315789 | 0.76 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 22016 | 45.42 |
| http_config_ssl_toMap | 735294 | 1.36 |
| http_config_ssl_fromMap | 2564102 | 0.39 |
| http_config_ssl_roundtrip | 602409 | 1.66 |
| smart_motion_speed_change | 21960783 | 0.05 |
| battery_budget_single_sample | 22009375 | 0.05 |
| smart_motion_accel_change | 22149457 | 0.05 |
| battery_budget_heavy_drain | 664539 | 1.50 |
| battery_budget_60_samples | 1283069 | 0.78 |


### 2026-06-11 — Commit d08ae615

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 5000000 | 0.20 |
| schedule_matches | 126422 | 7.91 |
| schedule_isWithin_5_entries | 115473 | 8.66 |
| location_fromMap | 2941176 | 0.34 |
| location_toMap | 1190476 | 0.84 |
| location_fromMap_toMap_roundtrip | 869565 | 1.15 |
| location_copyWithCoords | 20000000 | 0.05 |
| geofence_fromMap_circular | 8333333 | 0.12 |
| geofence_fromMap_polygon | 2857142 | 0.35 |
| carbon_trip_100_locations | 164473 | 6.08 |
| carbon_onLocation | 7142857 | 0.14 |
| carbon_setActivity | 16666666 | 0.06 |
| carbon_cumulative_report | 4545454 | 0.22 |
| persist_decider_location | 33333333 | 0.03 |
| persist_decider_geofence | 33333333 | 0.03 |
| config_fromMap | 800000 | 1.25 |
| config_toMap | 225733 | 4.43 |
| config_roundtrip | 172413 | 5.80 |
| state_fromMap | 763358 | 1.31 |
| state_toMap | 215517 | 4.64 |
| route_context_toMap | 5263157 | 0.19 |
| route_context_fromMap | 4347826 | 0.23 |
| route_context_roundtrip | 2500000 | 0.40 |
| sync_body_context_toMap_50 | 14285714 | 0.07 |
| sync_body_context_fromMap_50 | 38774 | 25.79 |
| http_config_ssl_toMap | 1315789 | 0.76 |
| http_config_ssl_fromMap | 5263157 | 0.19 |
| http_config_ssl_roundtrip | 1086956 | 0.92 |
| battery_budget_single_sample | 26311873 | 0.04 |
| battery_budget_60_samples | 1121667 | 0.89 |
| battery_budget_heavy_drain | 558862 | 1.79 |
| smart_motion_accel_change | 20628676 | 0.05 |
| smart_motion_speed_change | 20495787 | 0.05 |


### 2026-06-11 — Commit 0b7bf504

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 89525 | 11.17 |
| schedule_isWithin_5_entries | 81168 | 12.32 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 625000 | 1.60 |
| location_fromMap_toMap_roundtrip | 450450 | 2.22 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 90497 | 11.05 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 418410 | 2.39 |
| config_toMap | 122249 | 8.18 |
| config_roundtrip | 95419 | 10.48 |
| state_fromMap | 421940 | 2.37 |
| state_toMap | 119617 | 8.36 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22163 | 45.12 |
| http_config_ssl_toMap | 714285 | 1.40 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 584795 | 1.71 |
| battery_budget_60_samples | 1306666 | 0.77 |
| battery_budget_single_sample | 23705799 | 0.04 |
| smart_motion_accel_change | 23435321 | 0.04 |
| smart_motion_speed_change | 23396710 | 0.04 |
| battery_budget_heavy_drain | 673031 | 1.49 |


### 2026-06-11 — Commit 7e965a12

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 5000000 | 0.20 |
| schedule_matches | 129701 | 7.71 |
| schedule_isWithin_5_entries | 118203 | 8.46 |
| location_fromMap | 3125000 | 0.32 |
| location_toMap | 1190476 | 0.84 |
| location_fromMap_toMap_roundtrip | 854700 | 1.17 |
| location_copyWithCoords | 16666666 | 0.06 |
| geofence_fromMap_circular | 7692307 | 0.13 |
| geofence_fromMap_polygon | 2777777 | 0.36 |
| carbon_trip_100_locations | 169204 | 5.91 |
| carbon_onLocation | 7142857 | 0.14 |
| carbon_setActivity | 16666666 | 0.06 |
| carbon_cumulative_report | 4545454 | 0.22 |
| persist_decider_location | 33333333 | 0.03 |
| persist_decider_geofence | 33333333 | 0.03 |
| config_fromMap | 729927 | 1.37 |
| config_toMap | 223713 | 4.47 |
| config_roundtrip | 162866 | 6.14 |
| state_fromMap | 719424 | 1.39 |
| state_toMap | 212314 | 4.71 |
| route_context_toMap | 5263157 | 0.19 |
| route_context_fromMap | 4347826 | 0.23 |
| route_context_roundtrip | 2500000 | 0.40 |
| sync_body_context_toMap_50 | 14285714 | 0.07 |
| sync_body_context_fromMap_50 | 40485 | 24.70 |
| http_config_ssl_toMap | 1282051 | 0.78 |
| http_config_ssl_fromMap | 5000000 | 0.20 |
| http_config_ssl_roundtrip | 1063829 | 0.94 |
| smart_motion_accel_change | 20605221 | 0.05 |
| battery_budget_60_samples | 1130298 | 0.88 |
| smart_motion_speed_change | 21097392 | 0.05 |
| battery_budget_single_sample | 25784482 | 0.04 |
| battery_budget_heavy_drain | 574596 | 1.74 |


### 2026-06-11 — Commit 275f4a62

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 84245 | 11.87 |
| schedule_isWithin_5_entries | 78247 | 12.78 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 462962 | 2.16 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1515151 | 0.66 |
| carbon_trip_100_locations | 90661 | 11.03 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 436681 | 2.29 |
| config_toMap | 126742 | 7.89 |
| config_roundtrip | 97560 | 10.25 |
| state_fromMap | 416666 | 2.40 |
| state_toMap | 120336 | 8.31 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21781 | 45.91 |
| http_config_ssl_toMap | 746268 | 1.34 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 602409 | 1.66 |
| battery_budget_60_samples | 1288778 | 0.78 |
| battery_budget_single_sample | 22040452 | 0.05 |
| smart_motion_accel_change | 22157788 | 0.05 |
| smart_motion_speed_change | 21985271 | 0.05 |
| battery_budget_heavy_drain | 665533 | 1.50 |


### 2026-06-11 — Commit 5d4f1d5e

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 83752 | 11.94 |
| schedule_isWithin_5_entries | 77220 | 12.95 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 653594 | 1.53 |
| location_fromMap_toMap_roundtrip | 473933 | 2.11 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 88339 | 11.32 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 16666666 | 0.06 |
| config_fromMap | 444444 | 2.25 |
| config_toMap | 125470 | 7.97 |
| config_roundtrip | 97751 | 10.23 |
| state_fromMap | 414937 | 2.41 |
| state_toMap | 119617 | 8.36 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21682 | 46.12 |
| http_config_ssl_toMap | 735294 | 1.36 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 598802 | 1.67 |
| battery_budget_single_sample | 22041273 | 0.05 |
| smart_motion_speed_change | 21861701 | 0.05 |
| battery_budget_heavy_drain | 664677 | 1.50 |
| battery_budget_60_samples | 1288655 | 0.78 |
| smart_motion_accel_change | 22185452 | 0.05 |


### 2026-06-11 — Commit e6c679ff

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 82372 | 12.14 |
| schedule_isWithin_5_entries | 77399 | 12.92 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 473933 | 2.11 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 91911 | 10.88 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 444444 | 2.25 |
| config_toMap | 126103 | 7.93 |
| config_roundtrip | 95785 | 10.44 |
| state_fromMap | 404858 | 2.47 |
| state_toMap | 120481 | 8.30 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21953 | 45.55 |
| http_config_ssl_toMap | 729927 | 1.37 |
| http_config_ssl_fromMap | 2777777 | 0.36 |
| http_config_ssl_roundtrip | 588235 | 1.70 |
| smart_motion_accel_change | 22009935 | 0.05 |
| battery_budget_single_sample | 21925428 | 0.05 |
| battery_budget_60_samples | 1288614 | 0.78 |
| smart_motion_speed_change | 21469599 | 0.05 |
| battery_budget_heavy_drain | 665457 | 1.50 |


### 2026-06-11 — Commit d51e4b74

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 91157 | 10.97 |
| schedule_isWithin_5_entries | 83682 | 11.95 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 653594 | 1.53 |
| location_fromMap_toMap_roundtrip | 469483 | 2.13 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 91074 | 10.98 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 8333333 | 0.12 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 444444 | 2.25 |
| config_toMap | 122549 | 8.16 |
| config_roundtrip | 96246 | 10.39 |
| state_fromMap | 423728 | 2.36 |
| state_toMap | 118906 | 8.41 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21925 | 45.61 |
| http_config_ssl_toMap | 719424 | 1.39 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 581395 | 1.72 |
| battery_budget_60_samples | 1306922 | 0.77 |
| smart_motion_speed_change | 23442869 | 0.04 |
| battery_budget_single_sample | 23768291 | 0.04 |
| smart_motion_accel_change | 23517583 | 0.04 |
| battery_budget_heavy_drain | 672743 | 1.49 |


### 2026-06-11 — Commit d975d876

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 91157 | 10.97 |
| schedule_isWithin_5_entries | 81766 | 12.23 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 636942 | 1.57 |
| location_fromMap_toMap_roundtrip | 460829 | 2.17 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 92764 | 10.78 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 440528 | 2.27 |
| config_toMap | 124533 | 8.03 |
| config_roundtrip | 94250 | 10.61 |
| state_fromMap | 418410 | 2.39 |
| state_toMap | 117370 | 8.52 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 21376 | 46.78 |
| http_config_ssl_toMap | 719424 | 1.39 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 581395 | 1.72 |
| smart_motion_accel_change | 23508045 | 0.04 |
| battery_budget_heavy_drain | 677677 | 1.48 |
| smart_motion_speed_change | 23394702 | 0.04 |
| battery_budget_60_samples | 1307512 | 0.76 |
| battery_budget_single_sample | 23591180 | 0.04 |


### 2026-06-11 — Commit d51cebec

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 93896 | 10.65 |
| schedule_isWithin_5_entries | 82712 | 12.09 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 657894 | 1.52 |
| location_fromMap_toMap_roundtrip | 465116 | 2.15 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1515151 | 0.66 |
| carbon_trip_100_locations | 92936 | 10.76 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 436681 | 2.29 |
| config_toMap | 128205 | 7.80 |
| config_roundtrip | 97087 | 10.30 |
| state_fromMap | 411522 | 2.43 |
| state_toMap | 120336 | 8.31 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1388888 | 0.72 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22202 | 45.04 |
| http_config_ssl_toMap | 735294 | 1.36 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 591715 | 1.69 |
| battery_budget_single_sample | 23583115 | 0.04 |
| battery_budget_60_samples | 1308295 | 0.76 |
| smart_motion_speed_change | 23462680 | 0.04 |
| smart_motion_accel_change | 23476888 | 0.04 |
| battery_budget_heavy_drain | 677350 | 1.48 |


### 2026-06-11 — Commit 6db758c0

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 92250 | 10.84 |
| schedule_isWithin_5_entries | 83822 | 11.93 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 657894 | 1.52 |
| location_fromMap_toMap_roundtrip | 469483 | 2.13 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 95147 | 10.51 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 446428 | 2.24 |
| config_toMap | 126903 | 7.88 |
| config_roundtrip | 98425 | 10.16 |
| state_fromMap | 423728 | 2.36 |
| state_toMap | 120192 | 8.32 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1408450 | 0.71 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22471 | 44.50 |
| http_config_ssl_toMap | 729927 | 1.37 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 588235 | 1.70 |
| battery_budget_single_sample | 23761591 | 0.04 |
| battery_budget_60_samples | 1307055 | 0.77 |
| smart_motion_speed_change | 23432933 | 0.04 |
| battery_budget_heavy_drain | 677309 | 1.48 |
| smart_motion_accel_change | 23513340 | 0.04 |


### 2026-06-10 — Commit 9a083478

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 3030303 | 0.33 |
| schedule_matches | 147058 | 6.80 |
| schedule_isWithin_5_entries | 125156 | 7.99 |
| location_fromMap | 1724137 | 0.58 |
| location_toMap | 662251 | 1.51 |
| location_fromMap_toMap_roundtrip | 478468 | 2.09 |
| location_copyWithCoords | 12500000 | 0.08 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1639344 | 0.61 |
| carbon_trip_100_locations | 109409 | 9.14 |
| carbon_onLocation | 4347826 | 0.23 |
| carbon_setActivity | 10000000 | 0.10 |
| carbon_cumulative_report | 2702702 | 0.37 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 473933 | 2.11 |
| config_toMap | 133333 | 7.50 |
| config_roundtrip | 102880 | 9.72 |
| state_fromMap | 438596 | 2.28 |
| state_toMap | 126903 | 7.88 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22941 | 43.59 |
| http_config_ssl_toMap | 751879 | 1.33 |
| http_config_ssl_fromMap | 2941176 | 0.34 |
| http_config_ssl_roundtrip | 609756 | 1.64 |
| battery_budget_60_samples | 843727 | 1.19 |
| battery_budget_single_sample | 24142348 | 0.04 |
| smart_motion_speed_change | 17528737 | 0.06 |
| battery_budget_heavy_drain | 426570 | 2.34 |
| smart_motion_accel_change | 17571356 | 0.06 |


### 2026-06-10 — Commit 7fa16fdf

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2857142 | 0.35 |
| schedule_matches | 90171 | 11.09 |
| schedule_isWithin_5_entries | 82101 | 12.18 |
| location_fromMap | 1612903 | 0.62 |
| location_toMap | 653594 | 1.53 |
| location_fromMap_toMap_roundtrip | 469483 | 2.13 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 91911 | 10.88 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2631578 | 0.38 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 425531 | 2.35 |
| config_toMap | 125786 | 7.95 |
| config_roundtrip | 96432 | 10.37 |
| state_fromMap | 411522 | 2.43 |
| state_toMap | 121359 | 8.24 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22670 | 44.11 |
| http_config_ssl_toMap | 729927 | 1.37 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 584795 | 1.71 |
| battery_budget_60_samples | 1306762 | 0.77 |
| battery_budget_single_sample | 23543478 | 0.04 |
| smart_motion_speed_change | 23335419 | 0.04 |
| smart_motion_accel_change | 23458465 | 0.04 |
| battery_budget_heavy_drain | 677456 | 1.48 |


### 2026-06-10 — Commit eaae7467

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2500000 | 0.40 |
| schedule_matches | 82987 | 12.05 |
| schedule_isWithin_5_entries | 76511 | 13.07 |
| location_fromMap | 1587301 | 0.63 |
| location_toMap | 641025 | 1.56 |
| location_fromMap_toMap_roundtrip | 467289 | 2.14 |
| location_copyWithCoords | 9090909 | 0.11 |
| geofence_fromMap_circular | 4000000 | 0.25 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 91240 | 10.96 |
| carbon_onLocation | 3448275 | 0.29 |
| carbon_setActivity | 6666666 | 0.15 |
| carbon_cumulative_report | 2272727 | 0.44 |
| persist_decider_location | 14285714 | 0.07 |
| persist_decider_geofence | 14285714 | 0.07 |
| config_fromMap | 436681 | 2.29 |
| config_toMap | 125156 | 7.99 |
| config_roundtrip | 97276 | 10.28 |
| state_fromMap | 408163 | 2.45 |
| state_toMap | 120627 | 8.29 |
| route_context_toMap | 2777777 | 0.36 |
| route_context_fromMap | 2127659 | 0.47 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 6666666 | 0.15 |
| sync_body_context_fromMap_50 | 21819 | 45.83 |
| http_config_ssl_toMap | 719424 | 1.39 |
| http_config_ssl_fromMap | 2631578 | 0.38 |
| http_config_ssl_roundtrip | 584795 | 1.71 |
| battery_budget_single_sample | 21994005 | 0.05 |
| smart_motion_speed_change | 21948697 | 0.05 |
| smart_motion_accel_change | 22080829 | 0.05 |
| battery_budget_60_samples | 1286883 | 0.78 |
| battery_budget_heavy_drain | 664015 | 1.51 |


### 2026-06-10 — Commit 36b4b9c9

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 83963 | 11.91 |
| schedule_isWithin_5_entries | 76511 | 13.07 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 613496 | 1.63 |
| location_fromMap_toMap_roundtrip | 456621 | 2.19 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 90497 | 11.05 |
| carbon_onLocation | 3846153 | 0.26 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2325581 | 0.43 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 438596 | 2.28 |
| config_toMap | 120192 | 8.32 |
| config_roundtrip | 95328 | 10.49 |
| state_fromMap | 416666 | 2.40 |
| state_toMap | 115740 | 8.64 |
| route_context_toMap | 2777777 | 0.36 |
| route_context_fromMap | 2127659 | 0.47 |
| route_context_roundtrip | 1282051 | 0.78 |
| sync_body_context_toMap_50 | 7142857 | 0.14 |
| sync_body_context_fromMap_50 | 21519 | 46.47 |
| http_config_ssl_toMap | 709219 | 1.41 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 578034 | 1.73 |
| smart_motion_accel_change | 22033492 | 0.05 |
| battery_budget_heavy_drain | 653364 | 1.53 |
| smart_motion_speed_change | 21957201 | 0.05 |
| battery_budget_single_sample | 21824396 | 0.05 |
| battery_budget_60_samples | 1287347 | 0.78 |


### 2026-06-10 — Commit 5dcf140f

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 90991 | 10.99 |
| schedule_isWithin_5_entries | 82576 | 12.11 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 641025 | 1.56 |
| location_fromMap_toMap_roundtrip | 469483 | 2.13 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1492537 | 0.67 |
| carbon_trip_100_locations | 92506 | 10.81 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 421940 | 2.37 |
| config_toMap | 126742 | 7.89 |
| config_roundtrip | 95147 | 10.51 |
| state_fromMap | 404858 | 2.47 |
| state_toMap | 119047 | 8.40 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 22326 | 44.79 |
| http_config_ssl_toMap | 719424 | 1.39 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 598802 | 1.67 |
| battery_budget_single_sample | 23568582 | 0.04 |
| smart_motion_accel_change | 23454234 | 0.04 |
| smart_motion_speed_change | 23441771 | 0.04 |
| battery_budget_heavy_drain | 676927 | 1.48 |
| battery_budget_60_samples | 1300736 | 0.77 |


### 2026-06-10 — Commit de8b8ea5

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 92081 | 10.86 |
| schedule_isWithin_5_entries | 83963 | 11.91 |
| location_fromMap | 1612903 | 0.62 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 462962 | 2.16 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 94428 | 10.59 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 442477 | 2.26 |
| config_toMap | 125313 | 7.98 |
| config_roundtrip | 97276 | 10.28 |
| state_fromMap | 421940 | 2.37 |
| state_toMap | 120048 | 8.33 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1388888 | 0.72 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22482 | 44.48 |
| http_config_ssl_toMap | 735294 | 1.36 |
| http_config_ssl_fromMap | 2777777 | 0.36 |
| http_config_ssl_roundtrip | 588235 | 1.70 |
| battery_budget_heavy_drain | 675108 | 1.48 |
| battery_budget_60_samples | 1304981 | 0.77 |
| battery_budget_single_sample | 23776163 | 0.04 |
| smart_motion_accel_change | 23520658 | 0.04 |
| smart_motion_speed_change | 23464862 | 0.04 |


### 2026-06-10 — Commit 71527afc

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 87336 | 11.45 |
| schedule_isWithin_5_entries | 81766 | 12.23 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 636942 | 1.57 |
| location_fromMap_toMap_roundtrip | 460829 | 2.17 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1612903 | 0.62 |
| carbon_trip_100_locations | 91157 | 10.97 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 8333333 | 0.12 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 432900 | 2.31 |
| config_toMap | 122850 | 8.14 |
| config_roundtrip | 94876 | 10.54 |
| state_fromMap | 400000 | 2.50 |
| state_toMap | 118063 | 8.47 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21691 | 46.10 |
| http_config_ssl_toMap | 714285 | 1.40 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 584795 | 1.71 |
| battery_budget_single_sample | 23756183 | 0.04 |
| battery_budget_60_samples | 1301256 | 0.77 |
| smart_motion_accel_change | 23491068 | 0.04 |
| battery_budget_heavy_drain | 675753 | 1.48 |
| smart_motion_speed_change | 23436867 | 0.04 |


### 2026-06-10 — Commit 2e1bfd98

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 3030303 | 0.33 |
| schedule_matches | 150829 | 6.63 |
| schedule_isWithin_5_entries | 127226 | 7.86 |
| location_fromMap | 1724137 | 0.58 |
| location_toMap | 666666 | 1.50 |
| location_fromMap_toMap_roundtrip | 480769 | 2.08 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1694915 | 0.59 |
| carbon_trip_100_locations | 111856 | 8.94 |
| carbon_onLocation | 4347826 | 0.23 |
| carbon_setActivity | 10000000 | 0.10 |
| carbon_cumulative_report | 2631578 | 0.38 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 480769 | 2.08 |
| config_toMap | 129870 | 7.70 |
| config_roundtrip | 101214 | 9.88 |
| state_fromMap | 448430 | 2.23 |
| state_toMap | 124378 | 8.04 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2380952 | 0.42 |
| route_context_roundtrip | 1388888 | 0.72 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22722 | 44.01 |
| http_config_ssl_toMap | 763358 | 1.31 |
| http_config_ssl_fromMap | 3030303 | 0.33 |
| http_config_ssl_roundtrip | 609756 | 1.64 |
| smart_motion_accel_change | 17617180 | 0.06 |
| battery_budget_60_samples | 844692 | 1.18 |
| battery_budget_single_sample | 24106290 | 0.04 |
| smart_motion_speed_change | 17627693 | 0.06 |
| battery_budget_heavy_drain | 426741 | 2.34 |


### 2026-06-10 — Commit b07bee94

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 92421 | 10.82 |
| schedule_isWithin_5_entries | 83822 | 11.93 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 641025 | 1.56 |
| location_fromMap_toMap_roundtrip | 462962 | 2.16 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 92850 | 10.77 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 446428 | 2.24 |
| config_toMap | 124378 | 8.04 |
| config_roundtrip | 95969 | 10.42 |
| state_fromMap | 425531 | 2.35 |
| state_toMap | 119617 | 8.36 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1298701 | 0.77 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 21992 | 45.47 |
| http_config_ssl_toMap | 724637 | 1.38 |
| http_config_ssl_fromMap | 2777777 | 0.36 |
| http_config_ssl_roundtrip | 588235 | 1.70 |
| smart_motion_speed_change | 23456958 | 0.04 |
| battery_budget_single_sample | 23580851 | 0.04 |
| battery_budget_60_samples | 1307874 | 0.76 |
| battery_budget_heavy_drain | 677720 | 1.48 |
| smart_motion_accel_change | 23508189 | 0.04 |


### 2026-06-10 — Commit 4b7b1456

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 91911 | 10.88 |
| schedule_isWithin_5_entries | 82576 | 12.11 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 653594 | 1.53 |
| location_fromMap_toMap_roundtrip | 462962 | 2.16 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 91659 | 10.91 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 431034 | 2.32 |
| config_toMap | 125470 | 7.97 |
| config_roundtrip | 97370 | 10.27 |
| state_fromMap | 408163 | 2.45 |
| state_toMap | 119331 | 8.38 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1388888 | 0.72 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 21848 | 45.77 |
| http_config_ssl_toMap | 729927 | 1.37 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 588235 | 1.70 |
| smart_motion_speed_change | 23434638 | 0.04 |
| battery_budget_60_samples | 1306067 | 0.77 |
| battery_budget_single_sample | 23745063 | 0.04 |
| smart_motion_accel_change | 23449202 | 0.04 |
| battery_budget_heavy_drain | 676888 | 1.48 |


### 2026-06-10 — Commit 3d1a119e

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 84317 | 11.86 |
| schedule_isWithin_5_entries | 76982 | 12.99 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 465116 | 2.15 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 90826 | 11.01 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 431034 | 2.32 |
| config_toMap | 125000 | 8.00 |
| config_roundtrip | 97751 | 10.23 |
| state_fromMap | 408163 | 2.45 |
| state_toMap | 119760 | 8.35 |
| route_context_toMap | 2857142 | 0.35 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21551 | 46.40 |
| http_config_ssl_toMap | 729927 | 1.37 |
| http_config_ssl_fromMap | 2777777 | 0.36 |
| http_config_ssl_roundtrip | 591715 | 1.69 |
| battery_budget_60_samples | 1284205 | 0.78 |
| battery_budget_single_sample | 22030785 | 0.05 |
| battery_budget_heavy_drain | 661378 | 1.51 |
| smart_motion_speed_change | 21985637 | 0.05 |
| smart_motion_accel_change | 22151108 | 0.05 |


### 2026-06-10 — Commit 06139645

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 90909 | 11.00 |
| schedule_isWithin_5_entries | 82034 | 12.19 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 636942 | 1.57 |
| location_fromMap_toMap_roundtrip | 467289 | 2.14 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4000000 | 0.25 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 91407 | 10.94 |
| carbon_onLocation | 3703703 | 0.27 |
| carbon_setActivity | 8333333 | 0.12 |
| carbon_cumulative_report | 2439024 | 0.41 |
| persist_decider_location | 16666666 | 0.06 |
| persist_decider_geofence | 16666666 | 0.06 |
| config_fromMap | 438596 | 2.28 |
| config_toMap | 124843 | 8.01 |
| config_roundtrip | 96711 | 10.34 |
| state_fromMap | 416666 | 2.40 |
| state_toMap | 119617 | 8.36 |
| route_context_toMap | 2857142 | 0.35 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 7142857 | 0.14 |
| sync_body_context_fromMap_50 | 22055 | 45.34 |
| http_config_ssl_toMap | 714285 | 1.40 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 581395 | 1.72 |
| battery_budget_60_samples | 1307428 | 0.76 |
| battery_budget_heavy_drain | 677771 | 1.48 |
| smart_motion_accel_change | 23479987 | 0.04 |
| smart_motion_speed_change | 23343480 | 0.04 |
| battery_budget_single_sample | 23581404 | 0.04 |


### 2026-06-10 — Commit f1d17dc7

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 90497 | 11.05 |
| schedule_isWithin_5_entries | 80450 | 12.43 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 641025 | 1.56 |
| location_fromMap_toMap_roundtrip | 471698 | 2.12 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1612903 | 0.62 |
| carbon_trip_100_locations | 90909 | 11.00 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 16666666 | 0.06 |
| config_fromMap | 452488 | 2.21 |
| config_toMap | 124533 | 8.03 |
| config_roundtrip | 96432 | 10.37 |
| state_fromMap | 425531 | 2.35 |
| state_toMap | 119331 | 8.38 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 22281 | 44.88 |
| http_config_ssl_toMap | 735294 | 1.36 |
| http_config_ssl_fromMap | 2941176 | 0.34 |
| http_config_ssl_roundtrip | 591715 | 1.69 |
| battery_budget_heavy_drain | 677637 | 1.48 |
| battery_budget_single_sample | 23585372 | 0.04 |
| smart_motion_speed_change | 23378343 | 0.04 |
| battery_budget_60_samples | 1306426 | 0.77 |
| smart_motion_accel_change | 23480055 | 0.04 |


### 2026-06-10 — Commit d1f717fd

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 91996 | 10.87 |
| schedule_isWithin_5_entries | 83472 | 11.98 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 657894 | 1.52 |
| location_fromMap_toMap_roundtrip | 465116 | 2.15 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 92936 | 10.76 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 440528 | 2.27 |
| config_toMap | 127064 | 7.87 |
| config_roundtrip | 96899 | 10.32 |
| state_fromMap | 414937 | 2.41 |
| state_toMap | 120918 | 8.27 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1408450 | 0.71 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22568 | 44.31 |
| http_config_ssl_toMap | 746268 | 1.34 |
| http_config_ssl_fromMap | 2941176 | 0.34 |
| http_config_ssl_roundtrip | 595238 | 1.68 |
| battery_budget_single_sample | 23577426 | 0.04 |
| smart_motion_accel_change | 23440717 | 0.04 |
| smart_motion_speed_change | 23388696 | 0.04 |
| battery_budget_heavy_drain | 677545 | 1.48 |
| battery_budget_60_samples | 1306292 | 0.77 |


### 2026-06-10 — Commit 86992eb9

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 84388 | 11.85 |
| schedule_isWithin_5_entries | 77519 | 12.90 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 568181 | 1.76 |
| location_fromMap_toMap_roundtrip | 427350 | 2.34 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 90579 | 11.04 |
| carbon_onLocation | 3703703 | 0.27 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2222222 | 0.45 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 436681 | 2.29 |
| config_toMap | 112485 | 8.89 |
| config_roundtrip | 89766 | 11.14 |
| state_fromMap | 409836 | 2.44 |
| state_toMap | 109409 | 9.14 |
| route_context_toMap | 2564102 | 0.39 |
| route_context_fromMap | 2040816 | 0.49 |
| route_context_roundtrip | 1204819 | 0.83 |
| sync_body_context_toMap_50 | 7142857 | 0.14 |
| sync_body_context_fromMap_50 | 21017 | 47.58 |
| http_config_ssl_toMap | 657894 | 1.52 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 540540 | 1.85 |
| battery_budget_60_samples | 1276764 | 0.78 |
| battery_budget_single_sample | 21971461 | 0.05 |
| smart_motion_speed_change | 21951743 | 0.05 |
| smart_motion_accel_change | 22172809 | 0.05 |
| battery_budget_heavy_drain | 660143 | 1.51 |


### 2026-06-10 — Commit 99b7fda8

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2857142 | 0.35 |
| schedule_matches | 85616 | 11.68 |
| schedule_isWithin_5_entries | 77639 | 12.88 |
| location_fromMap | 1612903 | 0.62 |
| location_toMap | 641025 | 1.56 |
| location_fromMap_toMap_roundtrip | 469483 | 2.13 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 91074 | 10.98 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 432900 | 2.31 |
| config_toMap | 125628 | 7.96 |
| config_roundtrip | 96339 | 10.38 |
| state_fromMap | 403225 | 2.48 |
| state_toMap | 120336 | 8.31 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21748 | 45.98 |
| http_config_ssl_toMap | 735294 | 1.36 |
| http_config_ssl_fromMap | 2777777 | 0.36 |
| http_config_ssl_roundtrip | 598802 | 1.67 |
| battery_budget_single_sample | 22021314 | 0.05 |
| smart_motion_accel_change | 22151720 | 0.05 |
| smart_motion_speed_change | 21882119 | 0.05 |
| battery_budget_60_samples | 1288453 | 0.78 |
| battery_budget_heavy_drain | 664381 | 1.51 |


### 2026-06-10 — Commit b9a3d115

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 83542 | 11.97 |
| schedule_isWithin_5_entries | 77160 | 12.96 |
| location_fromMap | 1612903 | 0.62 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 462962 | 2.16 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1492537 | 0.67 |
| carbon_trip_100_locations | 91491 | 10.93 |
| carbon_onLocation | 3846153 | 0.26 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2380952 | 0.42 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 427350 | 2.34 |
| config_toMap | 123915 | 8.07 |
| config_roundtrip | 95510 | 10.47 |
| state_fromMap | 413223 | 2.42 |
| state_toMap | 119047 | 8.40 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21463 | 46.59 |
| http_config_ssl_toMap | 714285 | 1.40 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 588235 | 1.70 |
| smart_motion_speed_change | 21945917 | 0.05 |
| battery_budget_heavy_drain | 665106 | 1.50 |
| battery_budget_single_sample | 22026745 | 0.05 |
| smart_motion_accel_change | 22181218 | 0.05 |
| battery_budget_60_samples | 1288406 | 0.78 |


### 2026-06-10 — Commit 8fc89457

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 94073 | 10.63 |
| schedule_isWithin_5_entries | 84388 | 11.85 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 636942 | 1.57 |
| location_fromMap_toMap_roundtrip | 467289 | 2.14 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4761904 | 0.21 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 92936 | 10.76 |
| carbon_onLocation | 3846153 | 0.26 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 442477 | 2.26 |
| config_toMap | 124378 | 8.04 |
| config_roundtrip | 96246 | 10.39 |
| state_fromMap | 411522 | 2.43 |
| state_toMap | 120048 | 8.33 |
| route_context_toMap | 2857142 | 0.35 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 22202 | 45.04 |
| http_config_ssl_toMap | 724637 | 1.38 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 588235 | 1.70 |
| battery_budget_single_sample | 23751090 | 0.04 |
| smart_motion_accel_change | 22809922 | 0.04 |
| smart_motion_speed_change | 23486697 | 0.04 |
| battery_budget_60_samples | 1302601 | 0.77 |
| battery_budget_heavy_drain | 677156 | 1.48 |


### 2026-06-10 — Commit 05b46579

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 83612 | 11.96 |
| schedule_isWithin_5_entries | 76277 | 13.11 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 632911 | 1.58 |
| location_fromMap_toMap_roundtrip | 454545 | 2.20 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 88731 | 11.27 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 440528 | 2.27 |
| config_toMap | 122399 | 8.17 |
| config_roundtrip | 97656 | 10.24 |
| state_fromMap | 418410 | 2.39 |
| state_toMap | 120627 | 8.29 |
| route_context_toMap | 2777777 | 0.36 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1282051 | 0.78 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21645 | 46.20 |
| http_config_ssl_toMap | 714285 | 1.40 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 574712 | 1.74 |
| battery_budget_60_samples | 1288761 | 0.78 |
| battery_budget_single_sample | 22004609 | 0.05 |
| battery_budget_heavy_drain | 665585 | 1.50 |
| smart_motion_accel_change | 22141978 | 0.05 |
| smart_motion_speed_change | 21860983 | 0.05 |


### 2026-06-10 — Commit 0cbd4201

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 90909 | 11.00 |
| schedule_isWithin_5_entries | 84674 | 11.81 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 641025 | 1.56 |
| location_fromMap_toMap_roundtrip | 462962 | 2.16 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4761904 | 0.21 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 93984 | 10.64 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 454545 | 2.20 |
| config_toMap | 124688 | 8.02 |
| config_roundtrip | 96805 | 10.33 |
| state_fromMap | 431034 | 2.32 |
| state_toMap | 119047 | 8.40 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1408450 | 0.71 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22138 | 45.17 |
| http_config_ssl_toMap | 719424 | 1.39 |
| http_config_ssl_fromMap | 2941176 | 0.34 |
| http_config_ssl_roundtrip | 584795 | 1.71 |
| smart_motion_speed_change | 23435672 | 0.04 |
| battery_budget_heavy_drain | 677713 | 1.48 |
| smart_motion_accel_change | 23498572 | 0.04 |
| battery_budget_60_samples | 1307436 | 0.76 |
| battery_budget_single_sample | 23776193 | 0.04 |


### 2026-06-10 — Commit 426b6cdf

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 93720 | 10.67 |
| schedule_isWithin_5_entries | 84033 | 11.90 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 480769 | 2.08 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 91743 | 10.90 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 438596 | 2.28 |
| config_toMap | 125944 | 7.94 |
| config_roundtrip | 96432 | 10.37 |
| state_fromMap | 418410 | 2.39 |
| state_toMap | 120918 | 8.27 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1388888 | 0.72 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22192 | 45.06 |
| http_config_ssl_toMap | 735294 | 1.36 |
| http_config_ssl_fromMap | 2941176 | 0.34 |
| http_config_ssl_roundtrip | 595238 | 1.68 |
| smart_motion_speed_change | 23459653 | 0.04 |
| battery_budget_heavy_drain | 676160 | 1.48 |
| battery_budget_60_samples | 1304485 | 0.77 |
| battery_budget_single_sample | 23564810 | 0.04 |
| smart_motion_accel_change | 23510451 | 0.04 |


### 2026-06-10 — Commit da57213f

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 85251 | 11.73 |
| schedule_isWithin_5_entries | 77639 | 12.88 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 471698 | 2.12 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 92165 | 10.85 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 431034 | 2.32 |
| config_toMap | 124533 | 8.03 |
| config_roundtrip | 96993 | 10.31 |
| state_fromMap | 404858 | 2.47 |
| state_toMap | 119760 | 8.35 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21877 | 45.71 |
| http_config_ssl_toMap | 740740 | 1.35 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 602409 | 1.66 |
| battery_budget_60_samples | 1278903 | 0.78 |
| smart_motion_speed_change | 21990914 | 0.05 |
| battery_budget_single_sample | 22031640 | 0.05 |
| battery_budget_heavy_drain | 658770 | 1.52 |
| smart_motion_accel_change | 21959361 | 0.05 |


### 2026-06-09 — Commit b17b054

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 3030303 | 0.33 |
| schedule_matches | 149700 | 6.68 |
| schedule_isWithin_5_entries | 124378 | 8.04 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 628930 | 1.59 |
| location_fromMap_toMap_roundtrip | 471698 | 2.12 |
| location_copyWithCoords | 12500000 | 0.08 |
| geofence_fromMap_circular | 4761904 | 0.21 |
| geofence_fromMap_polygon | 1694915 | 0.59 |
| carbon_trip_100_locations | 111111 | 9.00 |
| carbon_onLocation | 4347826 | 0.23 |
| carbon_setActivity | 10000000 | 0.10 |
| carbon_cumulative_report | 2631578 | 0.38 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 462962 | 2.16 |
| config_toMap | 130039 | 7.69 |
| config_roundtrip | 100401 | 9.96 |
| state_fromMap | 432900 | 2.31 |
| state_toMap | 124223 | 8.05 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2380952 | 0.42 |
| route_context_roundtrip | 1408450 | 0.71 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22573 | 44.30 |
| http_config_ssl_toMap | 751879 | 1.33 |
| http_config_ssl_fromMap | 3030303 | 0.33 |
| http_config_ssl_roundtrip | 606060 | 1.65 |
| smart_motion_speed_change | 17583058 | 0.06 |
| smart_motion_accel_change | 17606829 | 0.06 |
| battery_budget_60_samples | 839205 | 1.19 |
| battery_budget_heavy_drain | 426266 | 2.35 |
| battery_budget_single_sample | 24033233 | 0.04 |


### 2026-06-09 — Commit 5015d5b

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 93896 | 10.65 |
| schedule_isWithin_5_entries | 85251 | 11.73 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 636942 | 1.57 |
| location_fromMap_toMap_roundtrip | 467289 | 2.14 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 93109 | 10.74 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2631578 | 0.38 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 446428 | 2.24 |
| config_toMap | 125628 | 7.96 |
| config_roundtrip | 97465 | 10.26 |
| state_fromMap | 432900 | 2.31 |
| state_toMap | 120336 | 8.31 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1369863 | 0.73 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22356 | 44.73 |
| http_config_ssl_toMap | 735294 | 1.36 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 595238 | 1.68 |
| smart_motion_speed_change | 23442417 | 0.04 |
| smart_motion_accel_change | 23525295 | 0.04 |
| battery_budget_single_sample | 23765171 | 0.04 |
| battery_budget_heavy_drain | 679175 | 1.47 |
| battery_budget_60_samples | 1308436 | 0.76 |


### 2026-06-09 — Commit e8f326f

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 84961 | 11.77 |
| schedule_isWithin_5_entries | 78064 | 12.81 |
| location_fromMap | 1587301 | 0.63 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 465116 | 2.15 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 91996 | 10.87 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 427350 | 2.34 |
| config_toMap | 125628 | 7.96 |
| config_roundtrip | 97181 | 10.29 |
| state_fromMap | 400000 | 2.50 |
| state_toMap | 119617 | 8.36 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2127659 | 0.47 |
| route_context_roundtrip | 1315789 | 0.76 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21843 | 45.78 |
| http_config_ssl_toMap | 729927 | 1.37 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 595238 | 1.68 |
| smart_motion_speed_change | 21956630 | 0.05 |
| battery_budget_heavy_drain | 665754 | 1.50 |
| battery_budget_60_samples | 1287262 | 0.78 |
| battery_budget_single_sample | 22037057 | 0.05 |
| smart_motion_accel_change | 22149828 | 0.05 |


### 2026-06-09 — Commit 1ff327c

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 91491 | 10.93 |
| schedule_isWithin_5_entries | 83963 | 11.91 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 471698 | 2.12 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 92936 | 10.76 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 440528 | 2.27 |
| config_toMap | 120048 | 8.33 |
| config_roundtrip | 96805 | 10.33 |
| state_fromMap | 413223 | 2.42 |
| state_toMap | 115207 | 8.68 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1408450 | 0.71 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22722 | 44.01 |
| http_config_ssl_toMap | 704225 | 1.42 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 578034 | 1.73 |
| battery_budget_60_samples | 1307080 | 0.77 |
| smart_motion_accel_change | 23445040 | 0.04 |
| smart_motion_speed_change | 23455029 | 0.04 |
| battery_budget_heavy_drain | 677520 | 1.48 |
| battery_budget_single_sample | 23602676 | 0.04 |


### 2026-06-09 — Commit 511ffb0

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 91407 | 10.94 |
| schedule_isWithin_5_entries | 83682 | 11.95 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 632911 | 1.58 |
| location_fromMap_toMap_roundtrip | 458715 | 2.18 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1515151 | 0.66 |
| carbon_trip_100_locations | 92764 | 10.78 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2631578 | 0.38 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 431034 | 2.32 |
| config_toMap | 125628 | 7.96 |
| config_roundtrip | 96805 | 10.33 |
| state_fromMap | 401606 | 2.49 |
| state_toMap | 118343 | 8.45 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1388888 | 0.72 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 21992 | 45.47 |
| http_config_ssl_toMap | 724637 | 1.38 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 598802 | 1.67 |
| battery_budget_heavy_drain | 677378 | 1.48 |
| battery_budget_single_sample | 23772192 | 0.04 |
| smart_motion_speed_change | 23444023 | 0.04 |
| battery_budget_60_samples | 1306775 | 0.77 |
| smart_motion_accel_change | 23500639 | 0.04 |


### 2026-06-09 — Commit 1ce3cd8

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 85251 | 11.73 |
| schedule_isWithin_5_entries | 77639 | 12.88 |
| location_fromMap | 1612903 | 0.62 |
| location_toMap | 641025 | 1.56 |
| location_fromMap_toMap_roundtrip | 465116 | 2.15 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 90744 | 11.02 |
| carbon_onLocation | 3846153 | 0.26 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 431034 | 2.32 |
| config_toMap | 125628 | 7.96 |
| config_roundtrip | 96246 | 10.39 |
| state_fromMap | 403225 | 2.48 |
| state_toMap | 120627 | 8.29 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21349 | 46.84 |
| http_config_ssl_toMap | 729927 | 1.37 |
| http_config_ssl_fromMap | 2564102 | 0.39 |
| http_config_ssl_roundtrip | 584795 | 1.71 |
| battery_budget_60_samples | 1288114 | 0.78 |
| smart_motion_accel_change | 22012300 | 0.05 |
| smart_motion_speed_change | 21984918 | 0.05 |
| battery_budget_heavy_drain | 665275 | 1.50 |
| battery_budget_single_sample | 22027713 | 0.05 |


### 2026-06-09 — Commit fe689b7

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 92165 | 10.85 |
| schedule_isWithin_5_entries | 83194 | 12.02 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 662251 | 1.51 |
| location_fromMap_toMap_roundtrip | 483091 | 2.07 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4761904 | 0.21 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 91743 | 10.90 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 438596 | 2.28 |
| config_toMap | 126262 | 7.92 |
| config_roundtrip | 96899 | 10.32 |
| state_fromMap | 413223 | 2.42 |
| state_toMap | 122850 | 8.14 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1388888 | 0.72 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22598 | 44.25 |
| http_config_ssl_toMap | 740740 | 1.35 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 598802 | 1.67 |
| smart_motion_speed_change | 23438800 | 0.04 |
| battery_budget_single_sample | 23741438 | 0.04 |
| smart_motion_accel_change | 23494974 | 0.04 |
| battery_budget_heavy_drain | 676394 | 1.48 |
| battery_budget_60_samples | 1306575 | 0.77 |


### 2026-06-09 — Commit 5bc3a1f

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 92165 | 10.85 |
| schedule_isWithin_5_entries | 83194 | 12.02 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 649350 | 1.54 |
| location_fromMap_toMap_roundtrip | 467289 | 2.14 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 90991 | 10.99 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 454545 | 2.20 |
| config_toMap | 124533 | 8.03 |
| config_roundtrip | 96711 | 10.34 |
| state_fromMap | 431034 | 2.32 |
| state_toMap | 120048 | 8.33 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 22386 | 44.67 |
| http_config_ssl_toMap | 729927 | 1.37 |
| http_config_ssl_fromMap | 2941176 | 0.34 |
| http_config_ssl_roundtrip | 588235 | 1.70 |
| smart_motion_speed_change | 22777476 | 0.04 |
| battery_budget_60_samples | 1309568 | 0.76 |
| smart_motion_accel_change | 23185469 | 0.04 |
| battery_budget_heavy_drain | 677596 | 1.48 |
| battery_budget_single_sample | 23691912 | 0.04 |


### 2026-06-09 — Commit cf90d57

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 84530 | 11.83 |
| schedule_isWithin_5_entries | 76804 | 13.02 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 471698 | 2.12 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 90661 | 11.03 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 436681 | 2.29 |
| config_toMap | 126103 | 7.93 |
| config_roundtrip | 97656 | 10.24 |
| state_fromMap | 411522 | 2.43 |
| state_toMap | 120481 | 8.30 |
| route_context_toMap | 2857142 | 0.35 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21838 | 45.79 |
| http_config_ssl_toMap | 740740 | 1.35 |
| http_config_ssl_fromMap | 2777777 | 0.36 |
| http_config_ssl_roundtrip | 595238 | 1.68 |
| battery_budget_60_samples | 1288486 | 0.78 |
| battery_budget_heavy_drain | 665649 | 1.50 |
| smart_motion_speed_change | 21931515 | 0.05 |
| smart_motion_accel_change | 21918091 | 0.05 |
| battery_budget_single_sample | 22018357 | 0.05 |


### 2026-06-08 — Commit 93c1614

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 84033 | 11.90 |
| schedule_isWithin_5_entries | 77160 | 12.96 |
| location_fromMap | 1612903 | 0.62 |
| location_toMap | 636942 | 1.57 |
| location_fromMap_toMap_roundtrip | 469483 | 2.13 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1515151 | 0.66 |
| carbon_trip_100_locations | 91324 | 10.95 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 440528 | 2.27 |
| config_toMap | 125944 | 7.94 |
| config_roundtrip | 97751 | 10.23 |
| state_fromMap | 414937 | 2.41 |
| state_toMap | 120048 | 8.33 |
| route_context_toMap | 2857142 | 0.35 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1351351 | 0.74 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21805 | 45.86 |
| http_config_ssl_toMap | 740740 | 1.35 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 598802 | 1.67 |
| battery_budget_single_sample | 22006129 | 0.05 |
| battery_budget_60_samples | 1284839 | 0.78 |
| battery_budget_heavy_drain | 665137 | 1.50 |
| smart_motion_accel_change | 22098439 | 0.05 |
| smart_motion_speed_change | 21983144 | 0.05 |


### 2026-06-08 — Commit d8d67cf

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 90579 | 11.04 |
| schedule_isWithin_5_entries | 81566 | 12.26 |
| location_fromMap | 1666666 | 0.60 |
| location_toMap | 641025 | 1.56 |
| location_fromMap_toMap_roundtrip | 458715 | 2.18 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1515151 | 0.66 |
| carbon_trip_100_locations | 91407 | 10.94 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 444444 | 2.25 |
| config_toMap | 122699 | 8.15 |
| config_roundtrip | 95510 | 10.47 |
| state_fromMap | 420168 | 2.38 |
| state_toMap | 118343 | 8.45 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1388888 | 0.72 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 22202 | 45.04 |
| http_config_ssl_toMap | 719424 | 1.39 |
| http_config_ssl_fromMap | 2777777 | 0.36 |
| http_config_ssl_roundtrip | 584795 | 1.71 |
| smart_motion_speed_change | 23219617 | 0.04 |
| battery_budget_60_samples | 1306105 | 0.77 |
| smart_motion_accel_change | 23443136 | 0.04 |
| battery_budget_single_sample | 23577651 | 0.04 |
| battery_budget_heavy_drain | 676895 | 1.48 |


### 2026-06-08 — Commit cb73d3a

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 91743 | 10.90 |
| schedule_isWithin_5_entries | 84459 | 11.84 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 666666 | 1.50 |
| location_fromMap_toMap_roundtrip | 483091 | 2.07 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4761904 | 0.21 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 92764 | 10.78 |
| carbon_onLocation | 4166666 | 0.24 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2631578 | 0.38 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 448430 | 2.23 |
| config_toMap | 127226 | 7.86 |
| config_roundtrip | 98135 | 10.19 |
| state_fromMap | 418410 | 2.39 |
| state_toMap | 120772 | 8.28 |
| route_context_toMap | 3030303 | 0.33 |
| route_context_fromMap | 2325581 | 0.43 |
| route_context_roundtrip | 1408450 | 0.71 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 22578 | 44.29 |
| http_config_ssl_toMap | 740740 | 1.35 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 606060 | 1.65 |
| battery_budget_heavy_drain | 675957 | 1.48 |
| smart_motion_speed_change | 23456914 | 0.04 |
| battery_budget_single_sample | 23769704 | 0.04 |
| battery_budget_60_samples | 1310532 | 0.76 |
| smart_motion_accel_change | 23445883 | 0.04 |


### 2026-06-08 — Commit dc14492

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2702702 | 0.37 |
| schedule_matches | 91157 | 10.97 |
| schedule_isWithin_5_entries | 82440 | 12.13 |
| location_fromMap | 1694915 | 0.59 |
| location_toMap | 636942 | 1.57 |
| location_fromMap_toMap_roundtrip | 460829 | 2.17 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 93720 | 10.67 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 436681 | 2.29 |
| config_toMap | 124533 | 8.03 |
| config_roundtrip | 95785 | 10.44 |
| state_fromMap | 413223 | 2.42 |
| state_toMap | 118343 | 8.45 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2272727 | 0.44 |
| route_context_roundtrip | 1388888 | 0.72 |
| sync_body_context_toMap_50 | 8333333 | 0.12 |
| sync_body_context_fromMap_50 | 21886 | 45.69 |
| http_config_ssl_toMap | 719424 | 1.39 |
| http_config_ssl_fromMap | 2941176 | 0.34 |
| http_config_ssl_roundtrip | 581395 | 1.72 |
| battery_budget_60_samples | 1298427 | 0.77 |
| battery_budget_heavy_drain | 677655 | 1.48 |
| smart_motion_accel_change | 23421072 | 0.04 |
| battery_budget_single_sample | 23747140 | 0.04 |
| smart_motion_speed_change | 23373084 | 0.04 |


### 2026-06-08 — Commit af5b09e

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2631578 | 0.38 |
| schedule_matches | 83822 | 11.93 |
| schedule_isWithin_5_entries | 76687 | 13.04 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 641025 | 1.56 |
| location_fromMap_toMap_roundtrip | 465116 | 2.15 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1538461 | 0.65 |
| carbon_trip_100_locations | 90661 | 11.03 |
| carbon_onLocation | 3703703 | 0.27 |
| carbon_setActivity | 7692307 | 0.13 |
| carbon_cumulative_report | 2439024 | 0.41 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 414937 | 2.41 |
| config_toMap | 124688 | 8.02 |
| config_roundtrip | 95602 | 10.46 |
| state_fromMap | 398406 | 2.51 |
| state_toMap | 119617 | 8.36 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2222222 | 0.45 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 6666666 | 0.15 |
| sync_body_context_fromMap_50 | 21824 | 45.82 |
| http_config_ssl_toMap | 724637 | 1.38 |
| http_config_ssl_fromMap | 2777777 | 0.36 |
| http_config_ssl_roundtrip | 595238 | 1.68 |
| battery_budget_single_sample | 22014726 | 0.05 |
| smart_motion_accel_change | 22139497 | 0.05 |
| battery_budget_60_samples | 1288643 | 0.78 |
| battery_budget_heavy_drain | 665151 | 1.50 |
| smart_motion_speed_change | 22009583 | 0.05 |


### 2026-06-08 — Commit 747e3f5

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 83752 | 11.94 |
| schedule_isWithin_5_entries | 77041 | 12.98 |
| location_fromMap | 1612903 | 0.62 |
| location_toMap | 641025 | 1.56 |
| location_fromMap_toMap_roundtrip | 469483 | 2.13 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 90171 | 11.09 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 414937 | 2.41 |
| config_toMap | 126582 | 7.90 |
| config_roundtrip | 96432 | 10.37 |
| state_fromMap | 403225 | 2.48 |
| state_toMap | 119474 | 8.37 |
| route_context_toMap | 2857142 | 0.35 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1315789 | 0.76 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21510 | 46.49 |
| http_config_ssl_toMap | 735294 | 1.36 |
| http_config_ssl_fromMap | 2857142 | 0.35 |
| http_config_ssl_roundtrip | 595238 | 1.68 |
| battery_budget_heavy_drain | 665857 | 1.50 |
| smart_motion_speed_change | 22039800 | 0.05 |
| battery_budget_single_sample | 22043005 | 0.05 |
| battery_budget_60_samples | 1285779 | 0.78 |
| smart_motion_accel_change | 22184135 | 0.05 |


### 2026-06-07 — Commit 5475e90

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 84817 | 11.79 |
| schedule_isWithin_5_entries | 76804 | 13.02 |
| location_fromMap | 1612903 | 0.62 |
| location_toMap | 645161 | 1.55 |
| location_fromMap_toMap_roundtrip | 471698 | 2.12 |
| location_copyWithCoords | 11111111 | 0.09 |
| geofence_fromMap_circular | 4347826 | 0.23 |
| geofence_fromMap_polygon | 1562500 | 0.64 |
| carbon_trip_100_locations | 91240 | 10.96 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2564102 | 0.39 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 436681 | 2.29 |
| config_toMap | 126422 | 7.91 |
| config_roundtrip | 97656 | 10.24 |
| state_fromMap | 416666 | 2.40 |
| state_toMap | 120918 | 8.27 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21819 | 45.83 |
| http_config_ssl_toMap | 729927 | 1.37 |
| http_config_ssl_fromMap | 2777777 | 0.36 |
| http_config_ssl_roundtrip | 595238 | 1.68 |
| battery_budget_heavy_drain | 665901 | 1.50 |
| smart_motion_speed_change | 21970457 | 0.05 |
| battery_budget_single_sample | 22031177 | 0.05 |
| battery_budget_60_samples | 1287250 | 0.78 |
| smart_motion_accel_change | 22171059 | 0.05 |


### 2026-06-07 — Commit 0b6ceeb

**Environment:** Dart 3.12.1, ubuntu-latest (CI)

| Benchmark | ops/sec | µs/op |
|---|---:|---:|
| schedule_parse | 2777777 | 0.36 |
| schedule_matches | 84745 | 11.80 |
| schedule_isWithin_5_entries | 77821 | 12.85 |
| location_fromMap | 1639344 | 0.61 |
| location_toMap | 632911 | 1.58 |
| location_fromMap_toMap_roundtrip | 473933 | 2.11 |
| location_copyWithCoords | 10000000 | 0.10 |
| geofence_fromMap_circular | 4545454 | 0.22 |
| geofence_fromMap_polygon | 1587301 | 0.63 |
| carbon_trip_100_locations | 90252 | 11.08 |
| carbon_onLocation | 4000000 | 0.25 |
| carbon_setActivity | 9090909 | 0.11 |
| carbon_cumulative_report | 2500000 | 0.40 |
| persist_decider_location | 20000000 | 0.05 |
| persist_decider_geofence | 20000000 | 0.05 |
| config_fromMap | 436681 | 2.29 |
| config_toMap | 125470 | 7.97 |
| config_roundtrip | 96246 | 10.39 |
| state_fromMap | 409836 | 2.44 |
| state_toMap | 119331 | 8.38 |
| route_context_toMap | 2941176 | 0.34 |
| route_context_fromMap | 2173913 | 0.46 |
| route_context_roundtrip | 1333333 | 0.75 |
| sync_body_context_toMap_50 | 7692307 | 0.13 |
| sync_body_context_fromMap_50 | 21574 | 46.35 |
| http_config_ssl_toMap | 735294 | 1.36 |
| http_config_ssl_fromMap | 2777777 | 0.36 |
| http_config_ssl_roundtrip | 591715 | 1.69 |
| smart_motion_speed_change | 22015332 | 0.05 |
| battery_budget_single_sample | 21932225 | 0.05 |
| battery_budget_60_samples | 1283457 | 0.78 |
| battery_budget_heavy_drain | 664337 | 1.51 |
| smart_motion_accel_change | 22169826 | 0.05 |


