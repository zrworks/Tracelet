import 'package:flutter/material.dart';
import 'package:tracelet/tracelet.dart' hide State;

import '../doctor_theme.dart';
import 'common.dart';

/// Displays current tracking state (enabled, mode, motion, odometer).
class TrackingCard extends StatelessWidget {
  /// Creates a [TrackingCard].
  const TrackingCard({required this.health, super.key});

  /// The health check data.
  final HealthCheck health;

  @override
  Widget build(BuildContext context) {
    final stateColor = health.trackingEnabled
        ? DoctorTheme.success
        : DoctorTheme.muted;
    final stateLabel = health.trackingEnabled ? 'Active' : 'Inactive';

    final modeLabel = switch (health.trackingMode) {
      TrackingMode.location => 'Location',
      TrackingMode.geofences => 'Geofences',
      TrackingMode.periodic => 'Periodic',
    };

    return DiagnosticCard(
      icon: Icons.gps_fixed_rounded,
      title: 'Tracking',
      trailing: StatusChip(label: stateLabel, color: stateColor),
      child: Column(
        children: [
          InfoRow(label: 'Mode', value: modeLabel),
          InfoRow(
            label: 'Motion',
            value: health.isMoving ? 'Moving' : 'Stationary',
            valueColor: health.isMoving
                ? DoctorTheme.accent
                : DoctorTheme.textSecondary,
          ),
          InfoRow(
            label: 'Odometer',
            value: '${(health.odometer / 1000).toStringAsFixed(2)} km',
          ),
          BoolRow(label: 'Scheduler', value: health.schedulerEnabled),
          BoolRow(
            label: 'Location Services',
            value: health.locationServicesEnabled,
          ),
        ],
      ),
    );
  }
}
