import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:tracelet/tracelet.dart' hide State;

class IssuesPage extends StatefulWidget {
  const IssuesPage({super.key});

  @override
  State<IssuesPage> createState() => _IssuesPageState();
}

class _IssuesPageState extends State<IssuesPage> {
  bool _isTracking = false;
  String _status = 'Idle';

  Future<void> _startIssue115Tracking() async {
    try {
      setState(() => _status = 'Requesting permissions...');

      // Basic permissions
      await Tracelet.requestLocationAuthorization();

      setState(() => _status = 'Starting Tracelet with Issue 115 Config...');

      // Configuration to reproduce Issue 115
      // - pausesLocationUpdatesAutomatically: false
      // - High accuracy
      // - distanceFilter > 0 (e.g. 10m)
      // - motionDetectionMode: activity (or something that doesn't force distanceFilter=0)

      await Tracelet.ready(
        Config(
          motion: MotionConfig(
            motionDetectionMode: MotionDetectionMode.smart,
            stopTimeout: 1,
            speedStationaryDelay: 15,
            activityRecognitionInterval: 5000,
            shakeThreshold: Platform.isIOS ? 0.95 : 2.5,
            stillThreshold: Platform.isIOS ? 0.2 : 0.4,
            stillSampleCount: Platform.isIOS ? 50 : 25,
            speedMovingThreshold: 1.2,
            speedWakeConfirmCount: 2,
            stationaryPeriodicInterval: 900,
            stationaryPeriodicAccuracy: DesiredAccuracy.low,
          ),
        ),
      );

      final state = await Tracelet.start();

      setState(() {
        _isTracking = state.enabled;
        _status =
            'Tracking Started. Put app in background and check Energy Impact.';
      });
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _stopTracking() async {
    try {
      final state = await Tracelet.stop();
      setState(() {
        _isTracking = state.enabled;
        _status = 'Tracking Stopped.';
      });
    } catch (e) {
      setState(() => _status = 'Error stopping: $e');
    }
  }

  Future<void> _testIssue117() async {
    setState(() => _status = 'Testing Issue 117 (Custom Sync Body)...');
    try {
      // 1. Setup local HTTP server
      final server = await HttpServer.bind('127.0.0.1', 8080);
      server.listen((req) async {
        final content = await utf8.decoder.bind(req).join();
        if (content.contains('"custom_payload_test":"success"')) {
          setState(() => _status = 'Issue 117 Passed! Custom body received.');
        } else {
          setState(() => _status = 'Issue 117 Failed! Wrong payload.');
        }
        req.response.statusCode = 200;
        req.response.write('{"success":true}');
        await req.response.close();
        await server.close(force: true);
      });

      // 2. Set custom sync body builder
      Tracelet.setSyncBodyBuilder((context) async {
        return {'custom_payload_test': 'success', 'points': context.locations};
      });

      // 3. Initialize Tracelet pointing to our local server
      await Tracelet.ready(
        const Config(
          http: HttpConfig(url: 'http://127.0.0.1:8080/sync', autoSync: false),
        ),
      );

      // 4. Insert dummy location
      await Tracelet.insertLocation(
        const Location(
          uuid: 'test-issue-117-uuid',
          timestamp: '2026-06-06T11:27:54.443591+00:00',
          isMoving: false,
          odometer: 0,
          coords: Coords(latitude: 37.7749, longitude: -122.4194, accuracy: 10),
        ).toMap(),
      );

      // 5. Trigger sync
      await Tracelet.sync();

      // Cleanup
      Tracelet.setSyncBodyBuilder(null);
    } catch (e) {
      setState(() => _status = 'Issue 117 Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Issues Test List')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              'Issue #115: Battery Drain Test',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tests iOS SDK with pausesLocationUpdatesAutomatically = false.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _isTracking ? null : _startIssue115Tracking,
              icon: const Icon(Icons.battery_alert),
              label: const Text('Start Tracking (Issue 115 Config)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isTracking ? _stopTracking : null,
              icon: const Icon(Icons.stop),
              label: const Text('Stop Tracking'),
            ),
            const Divider(height: 48),

            const Text(
              'Issue #117: Custom Sync Body Bypass',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tests that TraceletSync intercepts the batch correctly and uses '
              'the custom body builder instead of the default structure.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _testIssue117,
              icon: const Icon(Icons.cloud_sync),
              label: const Text('Test Custom Sync Body (Issue 117)'),
            ),

            const SizedBox(height: 48),
            Text(
              'Status: $_status',
              style: TextStyle(
                color: _status.contains('Passed')
                    ? Colors.green
                    : (_isTracking ? Colors.red : Colors.grey),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
