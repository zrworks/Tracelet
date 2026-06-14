import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracelet/tracelet.dart';

/// Validates the 3.3.0 telematics database log (insert → retrieve → destroy)
/// against the real native SQLite store, on-device. This is the "db logs"
/// feature surfaced by `simulateTelematicsEvent` / `getTelematicsEvents` /
/// `destroyTelematicsEvents` (used by the Tracelet Doctor overlay).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Tracelet.ready(const Config());
  });

  testWidgets('telematics events persist, retrieve, and destroy', (
    tester,
  ) async {
    // Start from a clean slate.
    await Tracelet.destroyTelematicsEvents();
    expect(await Tracelet.getTelematicsEvents(50), isEmpty);

    // Insert (the Doctor/simulate path writes to the DB).
    final inserted = await Tracelet.simulateTelematicsEvent(
      eventType: 'harsh_braking',
      severity: 0.85,
      latitude: 37.422,
      longitude: -122.084,
    );
    expect(inserted, isTrue);

    // Retrieve it back.
    final events = await Tracelet.getTelematicsEvents(50);
    expect(events, isNotEmpty);
    expect(events.first.eventType, 'harsh_braking');
    expect(events.first.severity, closeTo(0.85, 0.001));
    expect(events.first.latitude, closeTo(37.422, 0.001));

    // Destroy clears the log.
    final destroyed = await Tracelet.destroyTelematicsEvents();
    expect(destroyed, isTrue);
    expect(await Tracelet.getTelematicsEvents(50), isEmpty);
  });
}
