import 'package:flutter_test/flutter_test.dart';
import 'package:tracelet/tracelet.dart';

void main() {
  group('SyncBodyContext (#214)', () {
    test('fromMap reads locations + telematics', () {
      final ctx = SyncBodyContext.fromMap(const <String, Object?>{
        'locations': [
          {'lat': 1.0},
          {'lat': 2.0},
        ],
        'telematics': [
          {'event_type': 'harsh_braking', 'severity': 0.8},
        ],
      });
      expect(ctx.locations, hasLength(2));
      expect(ctx.telematics, hasLength(1));
      expect(ctx.telematics.first['event_type'], 'harsh_braking');
    });

    test('fromMap defaults telematics to empty when absent', () {
      final ctx = SyncBodyContext.fromMap(const <String, Object?>{
        'locations': [
          {'lat': 1.0},
        ],
      });
      expect(ctx.locations, hasLength(1));
      expect(ctx.telematics, isEmpty);
    });

    test('fromPlatform accepts the new {locations, telematics} map', () {
      final ctx = SyncBodyContext.fromPlatform(const <Object?, Object?>{
        'locations': [
          {'lat': 1.0},
        ],
        'telematics': [
          {'event_type': 'speeding'},
        ],
      });
      expect(ctx.locations, hasLength(1));
      expect(ctx.telematics, hasLength(1));
      expect(ctx.telematics.first['event_type'], 'speeding');
    });

    test('fromPlatform accepts the legacy bare-list shape (empty telematics)', () {
      final ctx = SyncBodyContext.fromPlatform(const <Object?>[
        {'lat': 1.0},
        {'lat': 2.0},
      ]);
      expect(ctx.locations, hasLength(2));
      expect(ctx.telematics, isEmpty);
    });

    test('fromPlatform filters non-map entries', () {
      final ctx = SyncBodyContext.fromPlatform(const <Object?>[
        {'lat': 1.0},
        'garbage',
        42,
      ]);
      expect(ctx.locations, hasLength(1));
    });

    test('toMap round-trips both fields', () {
      const ctx = SyncBodyContext(
        locations: [
          {'lat': 1.0},
        ],
        telematics: [
          {'event_type': 'crash'},
        ],
      );
      final map = ctx.toMap();
      expect(map['locations'], hasLength(1));
      expect((map['telematics']! as List).first, {'event_type': 'crash'});
    });

    test('default constructor has empty telematics', () {
      const ctx = SyncBodyContext(locations: []);
      expect(ctx.telematics, isEmpty);
    });
  });
}
