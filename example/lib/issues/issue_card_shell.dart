import 'package:flutter/material.dart';

/// Shared visual shell for the issue verification cards (#212/#213/#214):
/// title, description, a monospace status box, and a single Run button.
class IssueCardShell extends StatelessWidget {
  const IssueCardShell({
    required this.title,
    required this.description,
    required this.status,
    required this.running,
    required this.onRun,
    super.key,
    this.runLabel = 'Run Test',
  });

  final String title;
  final String description;
  final String status;
  final bool running;

  /// Invoked when the Run button is tapped. May be async; the return value is
  /// ignored (a `Future<void> Function()` is assignable to `VoidCallback`).
  final VoidCallback onRun;
  final String runLabel;

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
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                status,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: running ? null : onRun,
              icon: const Icon(Icons.play_arrow),
              label: Text(runLabel),
            ),
          ],
        ),
      ),
    );
  }
}
