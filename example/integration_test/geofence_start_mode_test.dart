import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracelet/tracelet.dart';

/// Integration test for geofence ENTER detection during continuous tracking
/// (`Tracelet.start()`) with `geofenceModeHighAccuracy: true`.
///
/// Verifies that the software geofence evaluator fires `onGeofence` events
/// when the device is inside a registered geofence's radius during
/// continuous location tracking mode.
///
/// Related: GitHub issue #51
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Geofence during continuous tracking (issue #51)', () {
    late StreamSubscription<Location> locationSub;
    late StreamSubscription<GeofenceEvent> geofenceSub;

    tearDown(() async {
      await Tracelet.stop();
      await Tracelet.removeGeofences();
    });

    testWidgets(
      'addGeofence around current position triggers ENTER during start()',
      (tester) async {
        // 1) Initialize Tracelet with high-accuracy geofence mode
        await Tracelet.ready(
          const Config(
            geofence: GeofenceConfig(
              geofenceProximityRadius: 10000,
              geofenceInitialTriggerEntry: true,
            ),
            geo: GeoConfig(
              desiredAccuracy: DesiredAccuracy.high,
              locationAuthorizationRequest: LocationAuthorizationRequest.always,
              distanceFilter: 0.0,
              geofenceModeHighAccuracy: true,
              filter: LocationFilter(rejectMockLocations: false),
            ),
            app: AppConfig(stopOnTerminate: true, startOnBoot: false),
            logger: LoggerConfig(debug: true, logLevel: LogLevel.verbose),
          ),
        );

        // 2) Get the device's current position to place a geofence on top of it
        final currentPos = await Tracelet.getCurrentPosition(
          desiredAccuracy: DesiredAccuracy.high,
          timeout: 30,
        );
        final lat = currentPos.coords.latitude;
        final lng = currentPos.coords.longitude;

        debugPrint('[TEST] Device position: $lat, $lng');

        // 3) Register a geofence centered on the current device position
        //    with a generous radius so the device is definitely inside
        final testGeofence = Geofence(
          identifier: 'test-issue-51',
          latitude: lat,
          longitude: lng,
          radius: 500, // 500m radius centered on device
          notifyOnEntry: true,
          notifyOnExit: true,
        );
        final added = await Tracelet.addGeofence(testGeofence);
        expect(added, isTrue, reason: 'Geofence should be added successfully');

        // Verify it's persisted
        final exists = await Tracelet.geofenceExists('test-issue-51');
        expect(exists, isTrue, reason: 'Geofence should exist in DB');

        // 4) Start continuous tracking
        final startState = await Tracelet.start();
        expect(startState.enabled, isTrue);

        // 5) Listen for geofence events with a timeout
        final geofenceCompleter = Completer<GeofenceEvent>();
        geofenceSub = Tracelet.onGeofence((event) {
          debugPrint(
            '[TEST] Geofence event: ${event.identifier} → ${event.action}',
          );
          if (event.identifier == 'test-issue-51' &&
              !geofenceCompleter.isCompleted) {
            geofenceCompleter.complete(event);
          }
        });

        // 6) Also listen for at least 1 location to confirm tracking works
        final locationCompleter = Completer<Location>();
        locationSub = Tracelet.onLocation((loc) {
          debugPrint(
            '[TEST] Location: ${loc.coords.latitude}, ${loc.coords.longitude} '
            'acc=${loc.coords.accuracy}m',
          );
          if (!locationCompleter.isCompleted) {
            locationCompleter.complete(loc);
          }
        });

        // Force moving state to ensure location updates flow
        await Tracelet.changePace(true);

        // 7) Wait for a location update (confirms tracking is active)
        final location = await locationCompleter.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw TestFailure(
            'No location received within 30s — tracking may not be active',
          ),
        );
        expect(location.coords.latitude, isNonZero);
        debugPrint('[TEST] Location confirmed — tracking is active');

        // 8) Wait for geofence ENTER event
        //    The software evaluator should fire ENTER on the next location fix
        //    since the device is inside the 500m geofence.
        try {
          final geoEvent = await geofenceCompleter.future.timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TestFailure(
              'No geofence ENTER event received within 30s.\n'
              'Device is at ($lat, $lng), geofence centered at same position '
              'with 500m radius. Software evaluator (geofenceModeHighAccuracy) '
              'should have fired ENTER.',
            ),
          );

          expect(geoEvent.identifier, equals('test-issue-51'));
          expect(geoEvent.action, equals(GeofenceAction.enter));
          debugPrint(
            '[TEST] ✅ Geofence ENTER received for ${geoEvent.identifier}',
          );
        } finally {
          locationSub.cancel();
          geofenceSub.cancel();
        }
      },
    );
  });
}
