import 'package:flutter/material.dart';
import 'package:tracelet/tracelet.dart' hide State;

import '../doctor_theme.dart';
import 'common.dart';

/// Displays pending database queue count and mock location status.
class DatabaseCard extends StatelessWidget {
  /// Creates a [DatabaseCard].
  const DatabaseCard({required this.health, super.key});

  /// The health check data.
  final HealthCheck health;

  @override
  Widget build(BuildContext context) {
    final queueColor = health.locationCount == 0
        ? DoctorTheme.success
        : health.locationCount < 100
            ? DoctorTheme.accent
            : health.locationCount < 500
                ? DoctorTheme.warning
                : DoctorTheme.error;

    return DiagnosticCard(
      icon: Icons.storage_rounded,
      title: 'Database',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pending Locations', style: DoctorTheme.cardBodyStyle),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: queueColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${health.locationCount}',
                  style: DoctorTheme.cardTitleStyle.copyWith(
                    color: queueColor,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          BoolRow(
            label: 'Mock Locations',
            value: health.mockLocationsDetected,
            invertColor: true,
          ),
          InfoRow(
            label: 'Platform',
            value: health.platform.isNotEmpty ? health.platform : '—',
          ),
          InfoRow(
            label: 'OS Version',
            value: health.osVersion.isNotEmpty ? health.osVersion : '—',
          ),
        ],
      ),
    );
  }
}
