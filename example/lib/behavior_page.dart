import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tracelet/tracelet.dart' as tl;

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

  Future<void> _applyConfig() async {
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
        _logLine('🚗 ${e.kind}  sev=${e.severity.toStringAsFixed(2)}  '
            'val=${e.value.toStringAsFixed(2)}');
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
          _logLine('⚠️ ${e.kind}  peak=${e.peakG.toStringAsFixed(1)}g  '
              '(cancel within window)');
        } else {
          setState(() => _pendingImpact = null);
          _logLine('🆘 CONFIRMED ${e.kind}  peak=${e.peakG.toStringAsFixed(1)}g');
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
            subtitle: const Text('high-g impact while moving → cancel countdown'),
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
          const Text('Event log', style: TextStyle(fontWeight: FontWeight.bold)),
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
