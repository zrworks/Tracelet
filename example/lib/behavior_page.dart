import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:tracelet/tracelet.dart' as tl;
// FRB engine handles — drive the real Rust detection logic with synthetic
// input so the features can be demoed without actually driving/crashing.
// ignore_for_file: implementation_imports
import 'package:tracelet_platform_interface/src/rust/api_dart/telematics.dart';
import 'package:tracelet_platform_interface/src/rust/api_dart/impact.dart';
import 'package:tracelet_platform_interface/src/rust/api_dart/transport_mode.dart';
import 'package:tracelet_platform_interface/src/rust/algorithms/impact.dart'
    as frb
    show ImpactConfig;

/// Demo page for the 3.3.0 behavior features: driving telematics, crash/fall
/// detection, and the fused transport-mode classifier.
///
/// Kept on its own page so the (already large) dashboard/issues pages stay lean.
/// Toggling a feature calls `Tracelet.setConfig` on the running instance and
/// subscribes to the corresponding event stream.
class BehaviorPage extends StatefulWidget {
  const BehaviorPage({super.key});

  @override
  State<BehaviorPage> createState() => _BehaviorPageState();
}

class _BehaviorPageState extends State<BehaviorPage> {
  bool _driving = false;
  bool _crash = false;
  bool _classifier = false;

  final List<String> _log = [];
  String _mode = 'unknown';
  tl.ImpactEvent? _pendingImpact;

  StreamSubscription<tl.DrivingEvent>? _drivingSub;
  StreamSubscription<tl.ImpactEvent>? _impactSub;
  StreamSubscription<tl.ModeChangeEvent>? _modeSub;

  @override
  void dispose() {
    _drivingSub?.cancel();
    _impactSub?.cancel();
    _modeSub?.cancel();
    super.dispose();
  }

  void _logLine(String s) {
    setState(() {
      _log.insert(0, '${TimeOfDay.now().format(context)}  $s');
      if (_log.length > 40) _log.removeLast();
    });
  }

  bool _ready = false;

  /// Ensures the SDK is initialized so config/streams/simulation work even if
  /// the user opened this page before pressing Initialize on the main screen.
  ///
  /// Non-clobbering: re-applies the *current* active config, which is a no-op
  /// when already initialized and surfaces `NOT_READY` otherwise — in which case
  /// we initialize with that same (default) config.
  Future<void> _ensureReady() async {
    if (_ready) return;
    try {
      await tl.Tracelet.setConfig(tl.Tracelet.activeConfig);
    } on PlatformException catch (e) {
      if (e.code == 'NOT_READY') {
        await tl.Tracelet.ready(tl.Tracelet.activeConfig);
        _logLine('ℹ️ Initialized Tracelet for this demo');
      } else {
        rethrow;
      }
    }
    _ready = true;
  }

  Future<void> _applyConfig() async {
    await _ensureReady();
    await tl.Tracelet.setConfig(
      tl.Config(
        telematics: tl.TelematicsConfig(
          enableDrivingEvents: _driving,
          // A modest limit so speeding is demoable without a highway.
          speedLimitKmh: _driving ? 30 : 0,
        ),
        classifier: tl.ClassifierConfig(enableFusedClassifier: _classifier),
        impact: tl.ImpactConfig(enableCrashDetection: _crash),
      ),
    );
  }

  Future<void> _toggleDriving(bool v) async {
    setState(() => _driving = v);
    await _applyConfig();
    if (v) {
      _drivingSub ??= tl.Tracelet.drivingEventStream.listen((e) {
        _logLine(
          '🚗 ${e.kind}  sev=${e.severity.toStringAsFixed(2)}  '
          'val=${e.value.toStringAsFixed(2)}',
        );
      });
    } else {
      _drivingSub?.cancel();
      _drivingSub = null;
    }
  }

  Future<void> _toggleCrash(bool v) async {
    setState(() => _crash = v);
    await _applyConfig();
    if (v) {
      _impactSub ??= tl.Tracelet.impactStream.listen((e) {
        if (e.isPotential) {
          setState(() => _pendingImpact = e);
          _logLine(
            '⚠️ ${e.kind}  peak=${e.peakG.toStringAsFixed(1)}g  '
            '(cancel within window)',
          );
        } else {
          setState(() => _pendingImpact = null);
          _logLine(
            '🆘 CONFIRMED ${e.kind}  peak=${e.peakG.toStringAsFixed(1)}g',
          );
        }
      });
    } else {
      _impactSub?.cancel();
      _impactSub = null;
      setState(() => _pendingImpact = null);
    }
  }

  Future<void> _toggleClassifier(bool v) async {
    setState(() => _classifier = v);
    await _applyConfig();
    if (v) {
      _modeSub ??= tl.Tracelet.modeChangeStream.listen((e) {
        setState(() => _mode = e.mode);
        _logLine('🚶 mode → ${e.mode}  (${e.confidence.toStringAsFixed(2)})');
      });
    } else {
      _modeSub?.cancel();
      _modeSub = null;
    }
  }

  Future<void> _cancelImpact() async {
    final e = _pendingImpact;
    if (e == null) return;
    await tl.Tracelet.cancelImpact(e.id);
    setState(() => _pendingImpact = null);
    _logLine('✋ cancelled impact #${e.id}');
  }

  /// Runs the real Rust engines (via flutter_rust_bridge) with synthetic input
  /// so each detection can be demoed on-device without actually driving. This
  /// is a self-contained demo: it does not require tracking to be started, but
  /// it does need the Rust library initialized — [_ensureReady] handles that.
  Future<void> _simulate(String scenario) async {
    await _ensureReady();
    try {
      switch (scenario) {
        case 'brake':
          final e = TelematicsEngineDart();
          e.processFix(
            speed: 22,
            heading: 90,
            latitude: 0,
            longitude: 0,
            timestampMs: 0,
          );
          for (final ev in e.processFix(
            speed: 5,
            heading: 90,
            latitude: 0,
            longitude: 0,
            timestampMs: 1000,
          )) {
            _logLine(
              '🚗 ${ev.kind}  val=${ev.value.toStringAsFixed(2)}g (sim)',
            );
          }
        case 'accel':
          final e = TelematicsEngineDart();
          e.processFix(
            speed: 4,
            heading: 90,
            latitude: 0,
            longitude: 0,
            timestampMs: 0,
          );
          for (final ev in e.processFix(
            speed: 15,
            heading: 90,
            latitude: 0,
            longitude: 0,
            timestampMs: 1000,
          )) {
            _logLine(
              '🚗 ${ev.kind}  val=${ev.value.toStringAsFixed(2)}g (sim)',
            );
          }
        case 'corner':
          final e = TelematicsEngineDart();
          e.processFix(
            speed: 15,
            heading: 0,
            latitude: 0,
            longitude: 0,
            timestampMs: 0,
          );
          for (final ev in e.processFix(
            speed: 15,
            heading: 45,
            latitude: 0,
            longitude: 0,
            timestampMs: 1000,
          )) {
            _logLine(
              '🚗 ${ev.kind}  val=${ev.value.toStringAsFixed(2)}g (sim)',
            );
          }
        case 'crash':
          final d = ImpactDetectorDart(
            config: const frb.ImpactConfig(
              enableCrash: true,
              enableFall: false,
              crashGThreshold: 3,
              crashMinSpeedKmh: 25,
              fallGThreshold: 2.5,
              confirmWindowMs: 15000,
              minConfidence: 0.6,
            ),
          );
          final c = d.onImpactWindow(
            peakG: 5,
            speedBeforeMps: 60 / 3.6,
            isOnFoot: false,
            latitude: 0,
            longitude: 0,
            nowMs: 0,
          );
          if (c != null) {
            _logLine(
              '🆘 ${c.kind}  peak=${c.peakG.toStringAsFixed(1)}g (sim) '
              '→ would auto-confirm in ${(c.confirmDeadlineMs / 1000).round()}s',
            );
          }
        case 'vehicle':
          final cl = TransportModeClassifierDart();
          final steady = List<double>.filled(10, 0.05);
          cl.classifySamples(
            magnitudesG: steady,
            durationMs: 1000,
            speedMps: 60 / 3.6,
            nowMs: 0,
          );
          final r = cl.classifySamples(
            magnitudesG: steady,
            durationMs: 1000,
            speedMps: 60 / 3.6,
            nowMs: 9000,
          );
          _logLine(
            '🚦 mode → ${r.mode.name} (${r.confidence.toStringAsFixed(2)}) (sim)',
          );
      }
    } catch (e) {
      _logLine('⚠️ simulate failed: $e (is the SDK initialized?)');
    }
  }

  /// Exercises the telematics SQLite log: persist a test event, read it back,
  /// or clear it. This is the path used by Tracelet Doctor and verifies that
  /// `getTelematicsEvents` / `simulateTelematicsEvent` / `destroyTelematicsEvents`
  /// round-trip through the real on-device database.
  Future<void> _dbAction(String action) async {
    await _ensureReady();
    try {
      switch (action) {
        case 'persist':
          final ok = await tl.Tracelet.simulateTelematicsEvent(
            eventType: 'harsh_braking',
            severity: 0.85,
            latitude: 37.422,
            longitude: -122.084,
          );
          _logLine('💾 persisted test event → DB (ok=$ok)');
        case 'load':
          final events = await tl.Tracelet.getTelematicsEvents(50);
          _logLine('💾 DB has ${events.length} event(s)');
          for (final e in events.take(5)) {
            _logLine(
              '   • ${e.eventType}  sev=${e.severity.toStringAsFixed(2)}  '
              '@${e.latitude.toStringAsFixed(3)},${e.longitude.toStringAsFixed(3)}',
            );
          }
        case 'clear':
          final ok = await tl.Tracelet.destroyTelematicsEvents();
          _logLine('💾 cleared telematics DB (ok=$ok)');
      }
    } catch (e) {
      _logLine('⚠️ DB action failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driving & Safety (3.3.0)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Opt-in behavior engines. Enable, then start tracking and move or '
            'drive. All default OFF — they never run unless switched on here.',
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Driving events'),
            subtitle: const Text(
              'harsh braking / acceleration / cornering / speeding (limit 30 km/h)',
            ),
            value: _driving,
            onChanged: _toggleDriving,
          ),
          SwitchListTile(
            title: const Text('Crash detection'),
            subtitle: const Text(
              'high-g impact while moving → cancel countdown',
            ),
            value: _crash,
            onChanged: _toggleCrash,
          ),
          SwitchListTile(
            title: const Text('Transport-mode classifier'),
            subtitle: Text('fused accel + GPS — current mode: $_mode'),
            value: _classifier,
            onChanged: _toggleClassifier,
          ),
          if (_pendingImpact != null)
            Card(
              color: Colors.red.shade100,
              child: ListTile(
                leading: const Icon(Icons.warning, color: Colors.red),
                title: Text('Possible ${_pendingImpact!.kind}'),
                subtitle: Text(
                  'peak ${_pendingImpact!.peakG.toStringAsFixed(1)}g — '
                  'auto-confirms unless cancelled',
                ),
                trailing: FilledButton(
                  onPressed: _cancelImpact,
                  child: const Text("I'm fine"),
                ),
              ),
            ),
          const Divider(height: 32),
          const Text(
            'Simulate (runs the real Rust engines with synthetic input)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => _simulate('brake'),
                child: const Text('Hard brake'),
              ),
              OutlinedButton(
                onPressed: () => _simulate('accel'),
                child: const Text('Rapid accel'),
              ),
              OutlinedButton(
                onPressed: () => _simulate('corner'),
                child: const Text('Sharp turn'),
              ),
              OutlinedButton(
                onPressed: () => _simulate('crash'),
                child: const Text('Crash'),
              ),
              OutlinedButton(
                onPressed: () => _simulate('vehicle'),
                child: const Text('Vehicle mode'),
              ),
            ],
          ),
          const Divider(height: 32),
          const Text(
            'Stored telematics (SQLite DB)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => _dbAction('persist'),
                child: const Text('Persist test event'),
              ),
              OutlinedButton(
                onPressed: () => _dbAction('load'),
                child: const Text('Load from DB'),
              ),
              OutlinedButton(
                onPressed: () => _dbAction('clear'),
                child: const Text('Clear DB'),
              ),
            ],
          ),
          const Divider(height: 32),
          const Text(
            'Event log',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_log.isEmpty) const Text('— no events yet —'),
          ..._log.map(
            (l) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(l, style: const TextStyle(fontFamily: 'monospace')),
            ),
          ),
        ],
      ),
    );
  }
}
