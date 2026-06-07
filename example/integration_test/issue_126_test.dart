import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracelet/tracelet.dart';
import 'package:tracelet_sync/tracelet_sync.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Issue 126: sync-body locations use the nested schema and keep route_context',
    (tester) async {
      await TraceletSync.initialize();

      await Tracelet.ready(
        const Config(
          // No server is needed — the custom body builder captures the payload
          // before the (failing) HTTP POST; autoSync off keeps it manual.
          http: HttpConfig(url: 'http://127.0.0.1:8126/sync', autoSync: false),
        ),
      );

      await Tracelet.destroyLocations();
      await Tracelet.clearRouteContext();
      await Tracelet.setRouteContext(const RouteContext(taskId: 'task-126'));

      final captured = Completer<List<Map<String, Object?>>>();
      Tracelet.setSyncBodyBuilder((context) async {
        if (!captured.isCompleted) captured.complete(context.locations);
        return {'status': 'intercepted'};
      });

      await Tracelet.insertLocation({
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'coords': {'latitude': 48.8566, 'longitude': 2.3522, 'accuracy': 5.0},
        'activity': {'type': 'walking', 'confidence': 100},
      });

      await Tracelet.sync();

      final locations = await captured.future.timeout(
        const Duration(seconds: 15),
      );
      Tracelet.setSyncBodyBuilder(null);

      expect(locations, isNotEmpty);
      final first = locations.first;

      // The DB-sourced map must match the live onLocation nested schema —
      // not a flat map with a raw String activity (Issue #126).
      expect(
        first['coords'],
        isA<Map<Object?, Object?>>(),
        reason: 'coords must be nested',
      );
      expect(
        first['activity'],
        isA<Map<Object?, Object?>>(),
        reason: 'activity must be a nested map, not a String',
      );
      expect(
        first.containsKey('latitude'),
        isFalse,
        reason: 'must not be flat (no top-level latitude)',
      );
      expect((first['coords']! as Map)['latitude'], 48.8566);
      expect((first['activity']! as Map)['type'], 'walking');
      expect(first['battery'], isA<Map<Object?, Object?>>());

      // route_context must survive into extras.route_context.
      final extras = first['extras'] as Map<Object?, Object?>?;
      final routeContext = extras?['route_context'] as Map<Object?, Object?>?;
      expect(
        routeContext?['taskId'],
        'task-126',
        reason: 'route_context (audit metadata) must be preserved',
      );

      // The nested map must parse cleanly into a Location without TypeErrors.
      final loc = Location.fromMap(Map<String, Object?>.from(first));
      expect(loc.coords.latitude, 48.8566);
      expect(loc.extras['route_context'], isA<Map<Object?, Object?>>());

      await Tracelet.stop();
    },
  );
}
