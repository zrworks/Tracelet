import 'package:flutter/material.dart';
import 'package:tracelet/tracelet.dart' hide State;

import '../doctor_theme.dart';
import 'common.dart';

/// Displays permission statuses (location, motion, accuracy).
class PermissionCard extends StatelessWidget {
  /// Creates a [PermissionCard].
  const PermissionCard({required this.health, super.key});

  /// The health check data.
  final HealthCheck health;

  @override
  Widget build(BuildContext context) {
    final permColor = switch (health.locationPermission) {
      AuthorizationStatus.always => DoctorTheme.success,
      AuthorizationStatus.whenInUse => DoctorTheme.warning,
      _ => DoctorTheme.error,
    };
    final permLabel = switch (health.locationPermission) {
      AuthorizationStatus.always => 'Always',
      AuthorizationStatus.whenInUse => 'When In Use',
      AuthorizationStatus.denied => 'Denied',
      AuthorizationStatus.deniedForever => 'Denied Forever',
      AuthorizationStatus.notDetermined => 'Not Determined',
    };

    final motionLabel = switch (health.motionPermission) {
      0 => 'Not Determined',
      1 => 'Restricted',
      2 => 'Denied',
      3 => 'Granted',
      _ => 'Unknown',
    };
    final motionColor = health.motionPermission == 3
        ? DoctorTheme.success
        : health.motionPermission == 0
        ? DoctorTheme.warning
        : DoctorTheme.error;

    final accuracyLabel =
        health.accuracyAuthorization == AccuracyAuthorization.full
        ? 'Full'
        : 'Reduced';
    final accuracyColor =
        health.accuracyAuthorization == AccuracyAuthorization.full
        ? DoctorTheme.success
        : DoctorTheme.warning;

    return DiagnosticCard(
      icon: Icons.shield_rounded,
      title: 'Permissions',
      trailing: StatusChip(label: permLabel, color: permColor),
      child: Column(
        children: [
          InfoRow(label: 'Location', value: permLabel, valueColor: permColor),
          InfoRow(
            label: 'Motion Activity',
            value: motionLabel,
            valueColor: motionColor,
          ),
          InfoRow(
            label: 'Accuracy',
            value: accuracyLabel,
            valueColor: accuracyColor,
          ),
        ],
      ),
    );
  }
}
