import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracelet/tracelet.dart';
import 'package:tracelet_sync/tracelet_sync.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Motion State & HTTP Sync Lifecycle Tests', () {
    late HttpServer server;
    late StreamController<String> requestController;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      requestController = StreamController<String>.broadcast();

      server.listen((req) async {
        final content = await utf8.decoder.bind(req).join();
        requestController.add(content);
        req.response.statusCode = 200;
        req.response.write('{"success":true}');
        req.response.close();
      });

      // Ensure clean state before each test
      await Tracelet.stop();
      await Tracelet.destroyLocations();
    });

    tearDown(() async {
      await Tracelet.stop();
      await Tracelet.destroyLocations();
      await server.close();
      await requestController.close();
    });

    testWidgets('State changes and auto-sync in FOREGROUND and BACKGROUND', (
      tester,
    ) async {
      final port = server.port;

      // 1. Initialize Tracelet with auto-sync pointing to our local server
      await Tracelet.ready(
        Config(
          http: HttpConfig(
            url: 'http://127.0.0.1:$port/sync',
            autoSync: true,
            autoSyncDelay: 1000,
            batchSync: true,
            maxBatchSize: 1, // trigger immediately
          ),
          motion: const MotionConfig(
            motionDetectionMode: MotionDetectionMode.speed,
          ),
          app: const AppConfig(
            stopOnTerminate: false, // For killed state simulation
          ),
        ),
      );

      // Initialize sync plugin
      await TraceletSync.initialize();

      // Start tracking
      await Tracelet.start();

      // ---- FOREGROUND STATE TESTING ----

      // Force moving state
      await Tracelet.changePace(true);
      await Future.delayed(const Duration(seconds: 1)); // allow state to update

      var state = await Tracelet.getState();
      expect(
        state.isMoving,
        isTrue,
        reason: 'changePace(true) should transition state to MOVING',
      );

      // Insert a mock location to trigger auto-sync in foreground
      await Tracelet.insertLocation({
        'uuid': 'foreground-uuid',
        'timestamp': DateTime.now().toIso8601String(),
        'latitude': 37.7749,
        'longitude': -122.4194,
        'accuracy': 10.0,
        'speed': 0.0,
        'heading': 0.0,
        'altitude': 0.0,
      });

      // Wait for foreground HTTP sync
      var payloadString = await requestController.stream.first.timeout(
        const Duration(seconds: 10),
      );
      var payload = jsonDecode(payloadString);
      expect(
        payloadString,
        contains('foreground-uuid'),
        reason: 'Foreground sync should deliver the location',
      );

      // Force stationary state
      await Tracelet.changePace(false);
      await Future.delayed(const Duration(seconds: 1));

      state = await Tracelet.getState();
      expect(
        state.isMoving,
        isFalse,
        reason: 'changePace(false) should transition state to STATIONARY',
      );

      // ---- BACKGROUND STATE TESTING ----

      // Simulate app going to background
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await Future.delayed(const Duration(seconds: 1));

      // Force moving state while in background
      await Tracelet.changePace(true);
      await Future.delayed(const Duration(seconds: 1));

      state = await Tracelet.getState();
      expect(
        state.isMoving,
        isTrue,
        reason:
            'State should be able to transition to MOVING while in background',
      );

      // Insert a mock location to trigger auto-sync in background
      await Tracelet.insertLocation({
        'uuid': 'background-uuid',
        'timestamp': DateTime.now().toIso8601String(),
        'latitude': 34.0522,
        'longitude': -118.2437,
        'accuracy': 10.0,
        'speed': 15.0,
        'heading': 0.0,
        'altitude': 0.0,
      });

      // Wait for background HTTP sync
      payloadString = await requestController.stream.first.timeout(
        const Duration(seconds: 10),
      );
      payload = jsonDecode(payloadString);
      expect(
        payloadString,
        contains('background-uuid'),
        reason: 'Background auto-sync should deliver the location',
      );

      // Simulate app returning to foreground
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      // ---- KILLED STATE CONFIGURATION CHECK ----

      // While we cannot test a true OS-level process kill in Flutter Integration Tests,
      // we can verify that the stopOnTerminate flag is correctly bound to the state,
      // which is the prerequisite for native killed-state persistence and background job execution.
      state = await Tracelet.getState();
      expect(
        state.config?.app.stopOnTerminate,
        isFalse,
        reason:
            'stopOnTerminate=false must be correctly registered for killed-state auto-sync to function',
      );
    });
  });
}
