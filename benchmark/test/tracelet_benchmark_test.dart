// ignore_for_file: avoid_print
/// Tracelet Performance Benchmark Suite
///
/// Measures throughput and latency of the core Dart algorithms that run
/// on every GPS fix. Results are printed as a machine-parseable table
/// and can be committed to BENCHMARK.md by the CI workflow.
///
/// Run:
///   cd benchmark && flutter test test/tracelet_benchmark_test.dart
///
/// The benchmark uses raw [Stopwatch] instead of adding a dependency on
/// `package:benchmark_harness` — keeping the dep footprint minimal.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tracelet/tracelet.dart';
import 'package:tracelet_platform_interface/tracelet_platform_interface.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// A single benchmark result with name, iterations, and elapsed time.
class _BenchResult {
  _BenchResult(this.name, this.iterations, this.elapsedUs);
  final String name;
  final int iterations;
  final int elapsedUs;

  double get opsPerSec => iterations / (elapsedUs / 1e6);
  double get usPerOp => elapsedUs / iterations;
}

final _results = <_BenchResult>[];

/// Runs [fn] for at least [minDurationMs] ms, then records ops/sec.
void _bench(String name, void Function() fn, {int minDurationMs = 2000}) {
  // Warm-up
  for (var i = 0; i < 1000; i++) {
    fn();
  }

  final sw = Stopwatch()..start();
  var iterations = 0;
  final minUs = minDurationMs * 1000;
  while (sw.elapsedMicroseconds < minUs) {
    fn();
    iterations++;
  }
  sw.stop();
  _results.add(_BenchResult(name, iterations, sw.elapsedMicroseconds));
}

// ─────────────────────────────────────────────────────────────────────────────
// Data generators
// ─────────────────────────────────────────────────────────────────────────────

final _rng = math.Random(42);

/// Generate a GPS track of [n] points with realistic jitter around a center.
List<({double lat, double lng, double acc, int ts})> _generateTrack(int n) {
  var lat = 37.4220;
  var lng = -122.0841;
  final points = <({double lat, double lng, double acc, int ts})>[];
  var ts = 1700000000000; // milliseconds since epoch
  for (var i = 0; i < n; i++) {
    lat += (_rng.nextDouble() - 0.5) * 0.0002;
    lng += (_rng.nextDouble() - 0.5) * 0.0002;
    final acc = 5.0 + _rng.nextDouble() * 50.0;
    points.add((lat: lat, lng: lng, acc: acc, ts: ts));
    ts += 1000; // 1 Hz
  }
  return points;
}

/// Generate a location map for serialization benchmarks.
Map<String, Object?> _generateLocationMap() {
  return <String, Object?>{
    'uuid': 'loc_${_rng.nextInt(1000000)}',
    'timestamp': '2024-11-01T12:34:56.789Z',
    'event': 'motionchange',
    'is_moving': true,
    'odometer': 12345.6,
    'coords': <String, Object?>{
      'latitude': 37.4220 + _rng.nextDouble() * 0.001,
      'longitude': -122.0841 + _rng.nextDouble() * 0.001,
      'accuracy': 16.0,
      'speed': 1.5,
      'speed_accuracy': 0.5,
      'heading': 90.0,
      'heading_accuracy': 5.0,
      'altitude': 30.0,
      'altitude_accuracy': 10.0,
      'floor': null,
      'ellipsoidal_altitude': null,
    },
    'activity': <String, Object?>{'type': 'walking', 'confidence': 85},
    'battery': <String, Object?>{'level': 0.75, 'is_charging': false},
    'extras': <String, Object?>{},
    'is_mock': false,
    'mock_heuristics': null,
    'locationSource': 'gps',
    'reducedAccuracy': false,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Benchmark: Schedule Parser
// ─────────────────────────────────────────────────────────────────────────────

void _benchScheduleParser() {
  _bench('schedule_parse', () {
    ScheduleParser.parse('1-5 09:00-17:00');
  });

  _bench('schedule_matches', () {
    ScheduleParser.matchesSchedule(
      '1-5 09:00-17:00',
      DateTime(2024, 3, 13, 12), // Wednesday noon
    );
  });

  _bench('schedule_isWithin_5_entries', () {
    ScheduleParser.isWithinSchedule([
      '1-5 06:00-09:00',
      '1-5 09:00-17:00',
      '1-5 17:00-22:00',
      '6-7 08:00-20:00',
      '1-7 22:00-06:00',
    ], DateTime(2024, 3, 13, 12));
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Benchmark: Location Serialization
// ─────────────────────────────────────────────────────────────────────────────

void _benchLocationSerialization() {
  final map = _generateLocationMap();

  _bench('location_fromMap', () {
    Location.fromMap(map);
  });

  final loc = Location.fromMap(map);
  _bench('location_toMap', loc.toMap);

  _bench('location_fromMap_toMap_roundtrip', () {
    Location.fromMap(map).toMap();
  });

  _bench('location_copyWithCoords', () {
    loc.copyWithCoords(latitude: 37.4225, longitude: -122.0835);
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Benchmark: Geofence Serialization
// ─────────────────────────────────────────────────────────────────────────────

void _benchGeofenceSerialization() {
  final circularMap = <String, Object?>{
    'identifier': 'geo_1',
    'latitude': 37.422,
    'longitude': -122.084,
    'radius': 200.0,
    'notifyOnEntry': true,
    'notifyOnExit': true,
    'notifyOnDwell': false,
    'loiteringDelay': 0,
    'extras': <String, Object?>{},
    'vertices': <List<double>>[],
  };

  _bench('geofence_fromMap_circular', () {
    Geofence.fromMap(circularMap);
  });

  final polygonMap = <String, Object?>{
    ...circularMap,
    'identifier': 'poly_1',
    'radius': 0,
    'vertices': [
      [37.423, -122.085],
      [37.423, -122.083],
      [37.421, -122.083],
      [37.421, -122.085],
    ],
  };

  _bench('geofence_fromMap_polygon', () {
    Geofence.fromMap(polygonMap);
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Benchmark: Carbon Estimator
// ─────────────────────────────────────────────────────────────────────────────

void _benchCarbonEstimator() {
  final track = _generateTrack(100);

  // Single trip with 100 locations
  _bench('carbon_trip_100_locations', () {
    final est = CarbonEstimator();
    est.startTrip();
    est.setActivity('in_vehicle');
    for (final p in track) {
      est.onLocationReceived(p.lat, p.lng);
    }
    est.endTrip();
  });

  // Per-location cost (hot path)
  _bench('carbon_onLocation', () {
    final est = CarbonEstimator();
    est.startTrip();
    est.setActivity('walking');
    est.onLocationReceived(37.422, -122.084);
    est.onLocationReceived(37.4221, -122.0841);
  });

  // Activity switching
  _bench('carbon_setActivity', () {
    final est = CarbonEstimator();
    est.startTrip();
    est.setActivity('walking');
    est.setActivity('in_vehicle');
    est.setActivity('on_bicycle');
  });

  // Cumulative report generation
  final est = CarbonEstimator();
  for (var trip = 0; trip < 10; trip++) {
    est.startTrip();
    est.setActivity('in_vehicle');
    for (final p in track) {
      est.onLocationReceived(p.lat, p.lng);
    }
    est.endTrip();
  }
  _bench('carbon_cumulative_report', est.getCumulativeReport);
}

// ─────────────────────────────────────────────────────────────────────────────
// Benchmark: Persist Decider
// ─────────────────────────────────────────────────────────────────────────────

void _benchPersistDecider() {
  _bench('persist_decider_location', () {
    PersistDecider.shouldPersistLocation(0, event: 'motionchange');
    PersistDecider.shouldPersistLocation(1, event: 'motionchange');
    PersistDecider.shouldPersistLocation(2, event: 'geofence');
    PersistDecider.shouldPersistLocation(3, event: 'heartbeat');
  });

  _bench('persist_decider_geofence', () {
    PersistDecider.shouldPersistGeofence(0);
    PersistDecider.shouldPersistGeofence(1);
    PersistDecider.shouldPersistGeofence(2);
    PersistDecider.shouldPersistGeofence(3);
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Benchmark: Config Serialization
// ─────────────────────────────────────────────────────────────────────────────

void _benchConfigSerialization() {
  final configMap = const Config().toMap();

  _bench('config_fromMap', () {
    Config.fromMap(configMap);
  });

  const config = Config();
  _bench('config_toMap', config.toMap);

  _bench('config_roundtrip', () {
    Config.fromMap(const Config().toMap());
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Benchmark: State Serialization
// ─────────────────────────────────────────────────────────────────────────────

void _benchStateSerialization() {
  final stateMap = <String, Object?>{
    'enabled': true,
    'trackingMode': 1,
    'isMoving': true,
    'schedulerEnabled': false,
    'odometer': 12345.6,
    'didLaunchInBackground': false,
    'didDeviceReboot': false,
    'config': const Config().toMap(),
  };

  _bench('state_fromMap', () {
    State.fromMap(stateMap);
  });

  final state = State.fromMap(stateMap);
  _bench('state_toMap', state.toMap);
}

// ─────────────────────────────────────────────────────────────────────────────
// Benchmark: RouteContext Serialization
// ─────────────────────────────────────────────────────────────────────────────

void _benchRouteContext() {
  const ctx = RouteContext(
    ownerId: 'owner-1',
    driverId: 'driver-7',
    taskId: 'delivery-42',
    trackingSessionId: 'sess-abc',
    startedAt: '2025-01-01T00:00:00Z',
    custom: {'region': 'eu-west', 'zone': 'A1'},
  );

  _bench('route_context_toMap', () {
    ctx.toMap();
  });

  final map = ctx.toMap();
  _bench('route_context_fromMap', () {
    RouteContext.fromMap(map);
  });

  _bench('route_context_roundtrip', () {
    RouteContext.fromMap(ctx.toMap());
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Benchmark: SyncBodyContext Serialization
// ─────────────────────────────────────────────────────────────────────────────

void _benchSyncBodyContext() {
  // 50-location batch (realistic sync payload)
  final locations = <Map<String, Object?>>[];
  for (var i = 0; i < 50; i++) {
    locations.add(_generateLocationMap());
  }
  final ctx = SyncBodyContext(locations: locations);

  _bench('sync_body_context_toMap_50', ctx.toMap);

  final map = ctx.toMap();
  _bench('sync_body_context_fromMap_50', () {
    SyncBodyContext.fromMap(map);
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Benchmark: HttpConfig with SSL Pinning
// ─────────────────────────────────────────────────────────────────────────────

void _benchHttpConfigSsl() {
  const http = HttpConfig(
    url: 'https://api.example.com/locations',
    headers: {'Authorization': 'Bearer tok', 'X-Device': 'abc'},
    sslPinningCertificates: ['MIIBcert1base64==', 'MIIBcert2base64=='],
    sslPinningFingerprints: ['sha256/AAAA', 'sha256/BBBB'],
  );

  _bench('http_config_ssl_toMap', () {
    http.toMap();
  });

  final map = http.toMap();
  _bench('http_config_ssl_fromMap', () {
    HttpConfig.fromMap(map);
  });

  _bench('http_config_ssl_roundtrip', () {
    HttpConfig.fromMap(http.toMap());
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  test('Tracelet Performance Benchmark', () async {
    await initializeRustLib();
    print('Tracelet Performance Benchmark');
    print('Dart ${Platform.version.split(' ').first}');
    print(
      'Date: ${DateTime.now().toUtc().toIso8601String().substring(0, 19)}Z',
    );
    print('');

    _benchScheduleParser();
    _benchLocationSerialization();
    _benchGeofenceSerialization();
    _benchCarbonEstimator();
    _benchPersistDecider();
    _benchConfigSerialization();
    _benchStateSerialization();
    _benchRouteContext();
    _benchSyncBodyContext();
    _benchHttpConfigSsl();

    // Build table content
    final tableBuffer = StringBuffer();
    tableBuffer.writeln('| Benchmark | ops/sec | µs/op |');
    tableBuffer.writeln('|---|---:|---:|');
    for (final r in _results) {
      tableBuffer.writeln(
        '| ${r.name} | ${r.opsPerSec.toStringAsFixed(0)} | ${r.usPerOp.toStringAsFixed(2)} |',
      );
    }
    final tableString = tableBuffer.toString();
    print('');
    print(tableString);
    try {
      File('benchmark_table.md').writeAsStringSync(tableString);
    } catch (e) {
      print('Warning: Failed to write benchmark_table.md: $e');
    }

    // Build JSON content
    final jsonBuffer = StringBuffer();
    jsonBuffer.writeln('{');
    for (var i = 0; i < _results.length; i++) {
      final r = _results[i];
      final comma = i < _results.length - 1 ? ',' : '';
      jsonBuffer.writeln(
        '  "${r.name}": ${r.usPerOp.toStringAsFixed(2)}$comma',
      );
    }
    jsonBuffer.writeln('}');
    final jsonString = jsonBuffer.toString();
    print('');
    print('--- JSON ---');
    print(jsonString);
    try {
      File('benchmark_results.json').writeAsStringSync(jsonString);
    } catch (e) {
      print('Warning: Failed to write benchmark_results.json: $e');
    }

    // Verify all benchmarks produced results
    expect(_results.length, greaterThanOrEqualTo(28));
    for (final r in _results) {
      expect(
        r.opsPerSec,
        greaterThan(0),
        reason: '${r.name} should have >0 ops/sec',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
