import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tracelet/tracelet.dart' hide State;

/// Issue #204 — `requestSyncBody` (the custom sync-body builder) must be invoked
/// exactly ONCE per batch. The bug caused two sync providers to fire
/// independently for the same batch, producing duplicate uploads.
///
/// This test registers a counting sync-body builder, seeds a couple of
/// locations, enables auto-sync with a short delay, and reports how many times
/// the builder was invoked for the batch. Expected: 1 invocation per batch.
class Issue204Card extends StatefulWidget {
  const Issue204Card({super.key});

  @override
  State<Issue204Card> createState() => _Issue204CardState();
}

class _Issue204CardState extends State<Issue204Card> {
  String _status = 'Idle';
  bool _running = false;
  int _invocations = 0;

  void _setStatus(String text) {
    if (mounted) setState(() => _status = text);
  }

  Future<void> _test() async {
    setState(() {
      _running = true;
      _invocations = 0;
    });
    try {
      _setStatus('Requesting permissions...');
      final auth = await Tracelet.requestLocationAuthorization();
      if (auth != AuthorizationStatus.always &&
          auth != AuthorizationStatus.whenInUse) {
        _setStatus('❌ FAILED: Permission denied');
        return;
      }

      // Count every requestSyncBody invocation.
      await Tracelet.setSyncBodyBuilder((ctx) async {
        _invocations++;
        if (mounted) setState(() {});
        return {'records': ctx.locations};
      });

      _setStatus('Configuring auto-sync (delay 2s, batch)...');
      await Tracelet.ready(
        Config.passive().copyWith(
          http: const HttpConfig(
            url: 'https://httpbin.org/post',
            batchSync: true,
            autoSyncDelay: 2000,
          ),
          logger: const LoggerConfig(debug: true, logLevel: LogLevel.verbose),
        ),
      );

      await Tracelet.start();

      _setStatus('Seeding 2 locations...');
      await Tracelet.getCurrentPosition(persist: true, samples: 1);
      await Tracelet.getCurrentPosition(persist: true, samples: 1);

      _setStatus('Waiting for auto-sync to fire...');
      await Future<void>.delayed(const Duration(seconds: 6));

      await Tracelet.stop();
      await Tracelet.setSyncBodyBuilder(null);

      if (_invocations == 0) {
        _setStatus(
          '⚠️ No sync fired (check network/url). invocations = $_invocations',
        );
      } else if (_invocations == 1) {
        _setStatus(
          '✅ SUCCESS: requestSyncBody fired exactly once for the batch '
          '(invocations = $_invocations). No duplicate sync.',
        );
      } else {
        _setStatus(
          '❌ FAILED: requestSyncBody fired $_invocations times for the same '
          'batch — duplicate sync (Issue #204).',
        );
      }
    } catch (e) {
      _setStatus('❌ FAILED: $e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '#204: Duplicate requestSyncBody per batch',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Counts how many times the custom sync-body builder is invoked for '
              'one batch. Expected exactly 1 (duplicate providers would fire 2).',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                '$_status\n\nrequestSyncBody invocations: $_invocations',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _running ? null : _test,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Run Test'),
            ),
          ],
        ),
      ),
    );
  }
}
