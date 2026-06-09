import 'package:flutter_test/flutter_test.dart';
import 'package:tracelet/tracelet.dart';

void main() {
  // The SDK's raw geofence payload as delivered to a headless (killed-state)
  // isolate: geofence fields nested under 'geofence', coords at the top level.
  Map<String, Object?> structuredPayload(String action) => <String, Object?>{
    'uuid': 'abc-123',
    'event': 'geofence',
    'timestamp': '2026-06-09T00:00:00.000Z',
    'coords': <String, Object?>{'latitude': 12.345, 'longitude': 67.89},
    'geofence': <String, Object?>{
      'identifier': 'office',
      'action': action,
      'extras': <String, Object?>{'tier': 'gold'},
    },
  };

  group(
    'GeofenceEvent.fromMap — structured (headless/killed-state) payload',
    () {
      test('EXIT is not mislabeled as ENTER', () {
        final event = GeofenceEvent.fromMap(structuredPayload('EXIT'));
        expect(event.action, GeofenceAction.exit);
        expect(event.identifier, 'office');
        expect(event.location.coords.latitude, 12.345);
        expect(event.location.coords.longitude, 67.89);
        expect(event.extras['tier'], 'gold');
      });

      test('ENTER maps to enter', () {
        expect(
          GeofenceEvent.fromMap(structuredPayload('ENTER')).action,
          GeofenceAction.enter,
        );
      });

      test('DWELL maps to dwell', () {
        expect(
          GeofenceEvent.fromMap(structuredPayload('DWELL')).action,
          GeofenceAction.dwell,
        );
      });
    },
  );

  group('GeofenceEvent.fromMap — flat (foreground) payload', () {
    test('EXIT still maps to exit', () {
      final event = GeofenceEvent.fromMap(const <String, Object?>{
        'identifier': 'legacy_zone',
        'action': 'exit',
        'location': <String, Object?>{
          'coords': <String, Object?>{'latitude': 1.0, 'longitude': 2.0},
        },
        'extras': <String, Object?>{'k': 'v'},
      });
      expect(event.action, GeofenceAction.exit);
      expect(event.identifier, 'legacy_zone');
      expect(event.location.coords.latitude, 1.0);
      expect(event.extras['k'], 'v');
    });
  });

  test('unknown/missing action defaults to enter', () {
    expect(
      GeofenceEvent.fromMap(const <String, Object?>{
        'geofence': <String, Object?>{'identifier': 'x'},
      }).action,
      GeofenceAction.enter,
    );
  });
}
