import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:tracelet/tracelet.dart' hide State;

class IssuesPage extends StatefulWidget {
  const IssuesPage({super.key});

  @override
  State<IssuesPage> createState() => _IssuesPageState();
}

class _IssuesPageState extends State<IssuesPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool _isTracking = false;
  final Map<int, String> _statuses = {};
  final Map<int, GlobalKey> _keys = {};

  final List<int> _allIssues = [115, 117, 118, 120];

  @override
  void initState() {
    super.initState();
    for (final issue in _allIssues) {
      _keys[issue] = GlobalKey();
      _statuses[issue] = 'Idle';
    }
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _setStatus(int issue, String status) {
    if (mounted) {
      setState(() {
        _statuses[issue] = status;
      });
    }
  }

  void _scrollTo(int issue) {
    final key = _keys[issue];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
    }
  }

  // ==== ISSUE 115 ====
  Future<void> _startIssue115Tracking() async {
    try {
      _setStatus(115, 'Requesting permissions...');
      await Tracelet.requestLocationAuthorization();
      _setStatus(115, 'Starting Tracelet with Issue 115 Config...');

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
        _setStatus(
          115,
          'Tracking Started. Put app in background and check Energy Impact.',
        );
      });
    } catch (e) {
      _setStatus(115, 'Error: $e');
    }
  }

  Future<void> _stopTracking() async {
    try {
      final state = await Tracelet.stop();
      setState(() {
        _isTracking = state.enabled;
        _setStatus(115, 'Tracking Stopped.');
      });
    } catch (e) {
      _setStatus(115, 'Error stopping: $e');
    }
  }

  // ==== ISSUE 117 ====
  Future<void> _testIssue117() async {
    _setStatus(117, 'Testing Issue 117 (Custom Sync Body)...');
    try {
      await Tracelet.destroyLocations();
      final server = await HttpServer.bind('127.0.0.1', 8080);
      server.listen((req) async {
        final content = await utf8.decoder.bind(req).join();
        if (content.contains('"custom_payload_test":"success"')) {
          _setStatus(117, '✅ SUCCESS: Issue 117 Passed! Custom body received.');
        } else {
          _setStatus(117, '❌ FAILED: Issue 117 Failed! Wrong payload.');
        }
        req.response.statusCode = 200;
        req.response.write('{"success":true}');
        await req.response.close();
        await server.close(force: true);
      });

      Tracelet.setSyncBodyBuilder((context) async {
        return {'custom_payload_test': 'success', 'points': context.locations};
      });

      await Tracelet.ready(
        const Config(
          http: HttpConfig(url: 'http://127.0.0.1:8080/sync', autoSync: false),
        ),
      );

      await Tracelet.insertLocation(
        const Location(
          uuid: 'test-issue-117-uuid',
          timestamp: '2026-06-06T11:27:54.443591+00:00',
          isMoving: false,
          odometer: 0,
          coords: Coords(latitude: 37.7749, longitude: -122.4194, accuracy: 10),
        ).toMap(),
      );

      await Tracelet.sync();
      Tracelet.setSyncBodyBuilder(null);
    } catch (e) {
      _setStatus(117, '❌ FAILED: Issue 117 Error: $e');
    }
  }

  // ==== ISSUE 118 ====
  Future<void> _testIssue118Valid() async {
    _setStatus(118, 'Testing Issue 118 (Valid SSL Pinning)...');
    try {
      await Tracelet.destroyLocations();
      final socket = await SecureSocket.connect(
        'jsonplaceholder.typicode.com',
        443,
      );
      final cert = socket.peerCertificate;
      if (cert == null) {
        _setStatus(118, '❌ FAILED: Could not get peer certificate');
        return;
      }
      final validFingerprint = sha256
          .convert(cert.der)
          .toString()
          .toUpperCase();
      socket.destroy();

      await Tracelet.ready(
        Config(
          http: HttpConfig(
            url: 'https://jsonplaceholder.typicode.com/posts',
            autoSync: false,
            sslPinningFingerprints: [validFingerprint],
          ),
        ),
      );

      await Tracelet.insertLocation(
        const Location(
          uuid: 'test-issue-118-valid',
          timestamp: '2026-06-06T11:27:54.443591+00:00',
          isMoving: false,
          odometer: 0,
          coords: Coords(latitude: 37.7749, longitude: -122.4194, accuracy: 10),
        ).toMap(),
      );

      await Tracelet.sync();

      final count = await Tracelet.getCount();
      if (count == 0) {
        _setStatus(
          118,
          '✅ SUCCESS: Valid fingerprint allowed sync ($validFingerprint).',
        );
      } else {
        _setStatus(
          118,
          '❌ FAILED: Valid fingerprint was blocked! (sync failed)',
        );
      }
    } catch (e) {
      _setStatus(118, '❌ FAILED: Unexpected error: $e');
    }
  }

  Future<void> _testIssue118Invalid() async {
    _setStatus(118, 'Testing Issue 118 (Invalid SSL Pinning)...');
    try {
      await Tracelet.destroyLocations();
      await Tracelet.ready(
        const Config(
          http: HttpConfig(
            url: 'https://jsonplaceholder.typicode.com/posts',
            autoSync: false,
            // Completely fake fingerprint
            sslPinningFingerprints: [
              'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55',
            ],
          ),
        ),
      );

      await Tracelet.insertLocation(
        const Location(
          uuid: 'test-issue-118-invalid',
          timestamp: '2026-06-06T11:27:54.443591+00:00',
          isMoving: false,
          odometer: 0,
          coords: Coords(latitude: 37.7749, longitude: -122.4194, accuracy: 10),
        ).toMap(),
      );

      await Tracelet.sync();

      final count = await Tracelet.getCount();
      if (count > 0) {
        _setStatus(
          118,
          '✅ SUCCESS: Invalid fingerprint successfully blocked sync!',
        );
      } else {
        _setStatus(118, '❌ FAILED: Invalid fingerprint somehow allowed sync!');
      }
    } catch (e) {
      _setStatus(118, '❌ FAILED: Unexpected error: $e');
    }
  }

  Future<void> _runIssue118All() async {
    await _testIssue118Valid();
    await Future.delayed(const Duration(seconds: 3));
    await _testIssue118Invalid();
  }

  // ==== ISSUE 120 ====
  Future<void> _testIssue120() async {
    _setStatus(120, 'Testing Issue 120 (Rust Parity)...');
    try {
      const channel = MethodChannel('com.tracelet/debug');
      final result = await channel.invokeMapMethod<String, dynamic>(
        'debugVerifyRustParity',
      );

      if (result == null) {
        _setStatus(120, '❌ FAILED: Null result from debug channel.');
        return;
      }

      final missingGeo = List<String>.from(result['missingGeo'] as List);
      final missingMotion = List<String>.from(result['missingMotion'] as List);

      if (missingGeo.isEmpty && missingMotion.isEmpty) {
        _setStatus(
          120,
          '✅ SUCCESS: All configuration properties are aligned with the Rust Core.',
        );
      } else {
        _setStatus(
          120,
          '❌ FAILED: Missing properties.\nGeo: $missingGeo\nMotion: $missingMotion',
        );
      }
    } on PlatformException catch (e) {
      _setStatus(120, '❌ FAILED: Issue 120 Error: ${e.message}');
    } catch (e) {
      _setStatus(120, '❌ FAILED: Issue 120 Error: $e');
    }
  }

  Future<void> _executeAll() async {
    for (final issue in _allIssues) {
      _scrollTo(issue);
      if (issue == 115) {
        await _startIssue115Tracking();
        await Future.delayed(const Duration(seconds: 3));
        await _stopTracking();
      } else if (issue == 117) {
        await _testIssue117();
        await Future.delayed(const Duration(seconds: 2));
      } else if (issue == 118) {
        await _runIssue118All();
      } else if (issue == 120) {
        await _testIssue120();
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Widget _buildIssueCard({
    required int issueNumber,
    required String title,
    required String description,
    required List<Widget> actions,
  }) {
    if (_searchQuery.isNotEmpty &&
        !issueNumber.toString().contains(_searchQuery)) {
      return const SizedBox.shrink();
    }

    final status = _statuses[issueNumber] ?? 'Idle';
    final isSuccess = status.contains('✅ SUCCESS');
    final isFailure = status.contains('❌ FAILED') || status.contains('Error');
    final isRunning =
        status.contains('Testing') ||
        status.contains('Requesting') ||
        status.contains('Starting');

    var statusColor = Colors.grey.shade700;
    if (isSuccess) statusColor = Colors.green.shade700;
    if (isFailure) statusColor = Colors.red.shade700;
    if (isRunning) statusColor = Colors.blue.shade700;

    return Card(
      key: _keys[issueNumber],
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Issue #$issueNumber: $title',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Status: $status',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Issues Test List')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search by Issue Number',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _executeAll,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Execute All'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildIssueCard(
                  issueNumber: 115,
                  title: 'Battery Drain Test',
                  description:
                      'Tests iOS SDK with pausesLocationUpdatesAutomatically = false.',
                  actions: [
                    FilledButton.icon(
                      onPressed: _isTracking ? null : _startIssue115Tracking,
                      icon: const Icon(Icons.battery_alert),
                      label: const Text('Start Tracking'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isTracking ? _stopTracking : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop Tracking'),
                    ),
                  ],
                ),
                _buildIssueCard(
                  issueNumber: 117,
                  title: 'Custom Sync Body Bypass',
                  description:
                      'Tests that TraceletSync intercepts the batch correctly and uses the custom body builder instead of the default structure.',
                  actions: [
                    FilledButton.icon(
                      onPressed: _testIssue117,
                      icon: const Icon(Icons.cloud_sync),
                      label: const Text('Test Custom Sync Body'),
                    ),
                  ],
                ),
                _buildIssueCard(
                  issueNumber: 118,
                  title: 'SSL Pinning Fingerprints',
                  description:
                      'Verifies that sync correctly validates against SHA-256 certificate fingerprints and blocks invalid connections natively.',
                  actions: [
                    FilledButton.icon(
                      onPressed: _testIssue118Valid,
                      icon: const Icon(Icons.lock_open),
                      label: const Text('Test Valid Fingerprint'),
                    ),
                    FilledButton.icon(
                      onPressed: _testIssue118Invalid,
                      icon: const Icon(Icons.lock),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      label: const Text('Test Invalid Fingerprint'),
                    ),
                  ],
                ),
                _buildIssueCard(
                  issueNumber: 120,
                  title: 'Rust Core Parity',
                  description:
                      'Verifies that UniFFI Rust classes have all properties required by the Dart Config models to prevent silent dropping during serialization.',
                  actions: [
                    FilledButton.icon(
                      onPressed: _testIssue120,
                      icon: const Icon(Icons.sync_problem),
                      label: const Text('Test Config Parity'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
