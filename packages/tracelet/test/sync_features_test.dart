import 'package:flutter_test/flutter_test.dart';
import 'package:tracelet/tracelet.dart';

void main() {
  // ==========================================================================
  // RouteContext
  // ==========================================================================
  group('RouteContext', () {
    test('constructs with all fields', () {
      const ctx = RouteContext(
        ownerId: 'owner-1',
        driverId: 'driver-7',
        taskId: 'delivery-42',
        trackingSessionId: 'sess-abc',
        startedAt: '2025-01-01T00:00:00Z',
        custom: {'region': 'eu-west'},
      );
      expect(ctx.ownerId, 'owner-1');
      expect(ctx.driverId, 'driver-7');
      expect(ctx.taskId, 'delivery-42');
      expect(ctx.trackingSessionId, 'sess-abc');
      expect(ctx.startedAt, '2025-01-01T00:00:00Z');
      expect(ctx.custom, {'region': 'eu-west'});
    });

    test('defaults to empty custom map', () {
      const ctx = RouteContext(taskId: 'task-1');
      expect(ctx.custom, isEmpty);
    });

    test('round-trip serialization preserves all fields', () {
      const ctx = RouteContext(
        ownerId: 'o1',
        driverId: 'd2',
        taskId: 't3',
        trackingSessionId: 's4',
        startedAt: '2025-06-15T12:00:00Z',
        custom: {'key': 'val'},
      );
      final map = ctx.toMap();
      final restored = RouteContext.fromMap(map);
      expect(restored.ownerId, 'o1');
      expect(restored.driverId, 'd2');
      expect(restored.taskId, 't3');
      expect(restored.trackingSessionId, 's4');
      expect(restored.startedAt, '2025-06-15T12:00:00Z');
      expect(restored.custom, {'key': 'val'});
    });

    test('toMap omits null fields', () {
      const ctx = RouteContext(taskId: 'task-1');
      final map = ctx.toMap();
      expect(map.containsKey('ownerId'), false);
      expect(map.containsKey('driverId'), false);
      expect(map.containsKey('taskId'), true);
      expect(map.containsKey('custom'), false); // empty map omitted
    });

    test('fromMap handles empty map', () {
      final ctx = RouteContext.fromMap(const {});
      expect(ctx.ownerId, isNull);
      expect(ctx.taskId, isNull);
      expect(ctx.custom, isEmpty);
    });

    test('fromMap coerces custom map values to strings', () {
      final ctx = RouteContext.fromMap({
        'taskId': 'task-1',
        'custom': {'count': 42, 'active': true},
      });
      expect(ctx.custom['count'], '42');
      expect(ctx.custom['active'], 'true');
    });

    test('equality', () {
      const a = RouteContext(taskId: 'task-1', driverId: 'driver-1');
      const b = RouteContext(taskId: 'task-1', driverId: 'driver-1');
      const c = RouteContext(taskId: 'task-2', driverId: 'driver-1');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('toString contains key fields', () {
      const ctx = RouteContext(taskId: 'task-1', driverId: 'driver-7');
      final str = ctx.toString();
      expect(str, contains('taskId: task-1'));
      expect(str, contains('driverId: driver-7'));
    });
  });

  // ==========================================================================
  // SyncBodyContext
  // ==========================================================================
  group('SyncBodyContext', () {
    test('constructs with locations list', () {
      const ctx = SyncBodyContext(
        locations: [
          {'uuid': 'loc-1', 'latitude': 48.8566},
          {'uuid': 'loc-2', 'latitude': 52.5200},
        ],
      );
      expect(ctx.locations, hasLength(2));
      expect(ctx.locations[0]['uuid'], 'loc-1');
    });

    test('round-trip serialization', () {
      const ctx = SyncBodyContext(
        locations: [
          {'uuid': 'loc-1', 'latitude': 48.8566, 'longitude': 2.3522},
        ],
      );
      final map = ctx.toMap();
      final restored = SyncBodyContext.fromMap(map);
      expect(restored.locations, hasLength(1));
      expect(restored.locations[0]['uuid'], 'loc-1');
    });

    test('fromMap handles empty locations', () {
      final ctx = SyncBodyContext.fromMap({'locations': <Object>[]});
      expect(ctx.locations, isEmpty);
    });

    test('fromMap handles missing locations key', () {
      final ctx = SyncBodyContext.fromMap(const {});
      expect(ctx.locations, isEmpty);
    });

    test('fromMap filters non-map entries', () {
      final ctx = SyncBodyContext.fromMap({
        'locations': [
          {'uuid': 'valid'},
          'not-a-map',
          42,
          {'uuid': 'also-valid'},
        ],
      });
      expect(ctx.locations, hasLength(2));
      expect(ctx.locations[0]['uuid'], 'valid');
      expect(ctx.locations[1]['uuid'], 'also-valid');
    });
  });
}
