import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tracelet/tracelet.dart' hide State;

class Issue115Page extends StatefulWidget {
  const Issue115Page({super.key});

  @override
  State<Issue115Page> createState() => _Issue115PageState();
}

class _Issue115PageState extends State<Issue115Page> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Issue 115 Battery Drain Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'This page tests the battery drain issue described in Issue #115.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'It configures the iOS SDK with:\n'
              '• pausesLocationUpdatesAutomatically = false\n'
              '• distanceFilter = 10m\n'
              '• Background location enabled\n\n'
              'To test:\n'
              '1. Tap "Start Tracking (Issue 115 Config)"\n'
              '2. Background the app and keep the device stationary.\n'
              '3. Monitor Xcode Energy Impact or Console for battery drain.',
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _isTracking ? null : _startIssue115Tracking,
              icon: const Icon(Icons.battery_alert),
              label: const Text('Start Tracking (Issue 115 Config)'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isTracking ? _stopTracking : null,
              icon: const Icon(Icons.stop),
              label: const Text('Stop Tracking'),
            ),
            const SizedBox(height: 32),
            Text(
              'Status: $_status',
              style: TextStyle(
                color: _isTracking ? Colors.red : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
