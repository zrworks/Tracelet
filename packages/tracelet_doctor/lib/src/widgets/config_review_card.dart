import 'package:flutter/material.dart';
import 'package:tracelet/tracelet.dart' hide State;

import '../doctor_theme.dart';
import 'common.dart';

/// Analyzes the active Tracelet configuration for common misconfigurations,
/// missing headless handlers, and HTTP sync issues.
class ConfigReviewCard extends StatelessWidget {
  /// Creates a [ConfigReviewCard].
  const ConfigReviewCard({required this.health, super.key});

  /// The health check data.
  final HealthCheck health;

  @override
  Widget build(BuildContext context) {
    final issues = _detectIssues();

    return DiagnosticCard(
      icon: Icons.tune_rounded,
      title: 'Configuration',
      trailing: StatusChip(
        label: issues.isEmpty ? 'OK' : '${issues.length} issue${issues.length > 1 ? 's' : ''}',
        color: issues.isEmpty ? DoctorTheme.success : DoctorTheme.warning,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Headless status
          _HeadlessRow(),
          const SizedBox(height: 4),
          // Boot status
          BoolRow(
            label: 'Did Launch in Background',
            value: health.didLaunchInBackground,
          ),
          BoolRow(
            label: 'Device Rebooted',
            value: health.didDeviceReboot,
          ),
          if (issues.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...issues.map((i) => _IssueRow(issue: i)),
          ],
        ],
      ),
    );
  }

  List<_ConfigIssue> _detectIssues() {
    final issues = <_ConfigIssue>[];

    // 1. Headless not registered on a mobile platform
    if (health.platform != 'web' && !Tracelet.isHeadlessRegistered) {
      issues.add(const _ConfigIssue(
        icon: Icons.code_off_rounded,
        message: 'No headless task registered — background events '
            'will be lost when the app is terminated.',
        severity: _Severity.warning,
      ));
    }

    // 2. Tracking active but location permission not "always"
    if (health.trackingEnabled &&
        health.locationPermission != AuthorizationStatus.always) {
      issues.add(const _ConfigIssue(
        icon: Icons.location_off_rounded,
        message: 'Tracking is active but location permission is not "Always" '
            '— background updates may stop.',
        severity: _Severity.error,
      ));
    }

    // 3. Mock locations detected while tracking
    if (health.trackingEnabled && health.mockLocationsDetected) {
      issues.add(const _ConfigIssue(
        icon: Icons.warning_amber_rounded,
        message: 'Mock locations detected while tracking is active '
            '— location data may be spoofed.',
        severity: _Severity.error,
      ));
    }

    // 4. Power save mode ON during active tracking
    if (health.trackingEnabled && health.isPowerSaveMode) {
      issues.add(const _ConfigIssue(
        icon: Icons.battery_saver_rounded,
        message: 'Power Save mode is ON during active tracking '
            '— OS may throttle GPS updates.',
        severity: _Severity.warning,
      ));
    }

    // 5. Aggressive OEM + no battery optimization exemption
    if (health.isAggressiveOem && !health.isIgnoringBatteryOptimizations) {
      issues.add(_ConfigIssue(
        icon: Icons.phonelink_erase_rounded,
        message: '${health.manufacturer} is known to kill background apps '
            'and battery optimizations are not disabled.',
        severity: _Severity.error,
      ));
    }

    return issues;
  }
}

class _HeadlessRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final registered = Tracelet.isHeadlessRegistered;
    final color = registered ? DoctorTheme.success : DoctorTheme.warning;
    final icon = registered
        ? Icons.check_circle_rounded
        : Icons.warning_amber_rounded;
    final label = registered ? 'Registered' : 'Not Registered';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Headless Task', style: DoctorTheme.cardBodyStyle),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: DoctorTheme.cardBodyStyle.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, size: 16, color: color),
            ],
          ),
        ],
      ),
    );
  }
}

enum _Severity { warning, error }

class _ConfigIssue {
  const _ConfigIssue({
    required this.icon,
    required this.message,
    required this.severity,
  });
  final IconData icon;
  final String message;
  final _Severity severity;
}

class _IssueRow extends StatelessWidget {
  const _IssueRow({required this.issue});
  final _ConfigIssue issue;

  @override
  Widget build(BuildContext context) {
    final color = issue.severity == _Severity.error
        ? DoctorTheme.error
        : DoctorTheme.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(issue.icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              issue.message,
              style: DoctorTheme.cardBodyStyle.copyWith(
                color: DoctorTheme.textPrimary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
