import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tracelet/tracelet.dart' hide State;

import 'doctor_theme.dart';
import 'widgets/battery_oem_card.dart';
import 'widgets/database_card.dart';
import 'widgets/permission_card.dart';
import 'widgets/sensor_grid.dart';
import 'widgets/tracking_card.dart';
import 'widgets/warning_list.dart';

/// A drop-in diagnostic overlay for Tracelet.
///
/// Shows a detailed health check of the plugin's operational state including
/// permissions, tracking state, battery/OEM health, sensor availability,
/// database queue, and actionable warnings.
///
/// ## Usage
///
/// ```dart
/// // Show as a modal bottom sheet:
/// TraceletDoctor.show(context);
/// ```
///
/// The overlay calls [Tracelet.getHealth] internally to gather all diagnostic
/// data. No additional setup is required — just call [show].
class TraceletDoctor {
  TraceletDoctor._();

  /// Shows the Tracelet Doctor diagnostic sheet as a modal bottom sheet.
  ///
  /// This is the primary entry point. Call this from a button, debug menu,
  /// or shake gesture handler.
  ///
  /// ```dart
  /// ElevatedButton(
  ///   onPressed: () => TraceletDoctor.show(context),
  ///   child: const Text('Run Diagnostics'),
  /// );
  /// ```
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _DoctorSheetContent(),
    );
  }
}

class _DoctorSheetContent extends StatefulWidget {
  const _DoctorSheetContent();

  @override
  State<_DoctorSheetContent> createState() => _DoctorSheetContentState();
}

class _DoctorSheetContentState extends State<_DoctorSheetContent>
    with SingleTickerProviderStateMixin {
  HealthCheck? _health;
  bool _loading = true;
  String? _error;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _runCheck();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _runCheck() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final health = await Tracelet.getHealth();
      if (mounted) {
        setState(() {
          _health = health;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _copyReport() async {
    final health = _health;
    if (health == null) return;

    final json = const JsonEncoder.withIndent('  ').convert(health.toMap());
    await Clipboard.setData(ClipboardData(text: json));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Diagnostic report copied to clipboard'),
          backgroundColor: DoctorTheme.accent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.88),
      decoration: const BoxDecoration(
        color: DoctorTheme.sheetBackground,
        borderRadius: DoctorTheme.sheetRadius,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          _buildHeader(),
          const Divider(color: DoctorTheme.cardBorder, height: 1),
          Expanded(
            child: _loading
                ? _buildLoading()
                : _error != null
                    ? _buildError()
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: DoctorTheme.muted.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final health = _health;
    final warningCount = health?.warningCount ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.health_and_safety_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tracelet Doctor', style: DoctorTheme.titleStyle),
                if (health != null)
                  Text(
                    warningCount == 0
                        ? 'All systems healthy'
                        : '$warningCount warning${warningCount > 1 ? 's' : ''} detected',
                    style: DoctorTheme.cardBodyStyle.copyWith(
                      color: warningCount == 0
                          ? DoctorTheme.success
                          : DoctorTheme.warning,
                    ),
                  ),
              ],
            ),
          ),
          if (health != null) ...[
            _HeaderButton(
              icon: Icons.copy_rounded,
              tooltip: 'Copy Report',
              onPressed: _copyReport,
            ),
            const SizedBox(width: 6),
            _HeaderButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Re-run',
              onPressed: _runCheck,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (_, __) => Opacity(
          opacity: 0.4 + _pulseController.value * 0.6,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.health_and_safety_rounded,
                color: DoctorTheme.accent,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Running diagnostics…',
                style: DoctorTheme.cardBodyStyle.copyWith(
                  color: DoctorTheme.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: DoctorTheme.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Diagnostics failed',
              style: DoctorTheme.cardTitleStyle.copyWith(
                color: DoctorTheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: DoctorTheme.cardBodyStyle,
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _runCheck,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: DoctorTheme.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final health = _health!;

    return ListView(
      padding: DoctorTheme.contentPadding,
      children: [
        // Warnings section
        _SectionLabel(
          label: 'WARNINGS',
          count: health.warningCount,
        ),
        const SizedBox(height: 8),
        WarningList(warnings: health.warnings),
        const SizedBox(height: DoctorTheme.cardSpacing + 8),

        // Permissions
        const _SectionLabel(label: 'PERMISSIONS'),
        const SizedBox(height: 8),
        PermissionCard(health: health),
        const SizedBox(height: DoctorTheme.cardSpacing),

        // Tracking
        const _SectionLabel(label: 'TRACKING STATE'),
        const SizedBox(height: 8),
        TrackingCard(health: health),
        const SizedBox(height: DoctorTheme.cardSpacing),

        // Battery & OEM
        const _SectionLabel(label: 'BATTERY & OEM'),
        const SizedBox(height: 8),
        BatteryOemCard(health: health),
        const SizedBox(height: DoctorTheme.cardSpacing),

        // Sensors
        const _SectionLabel(label: 'SENSORS'),
        const SizedBox(height: 8),
        SensorGrid(health: health),
        const SizedBox(height: DoctorTheme.cardSpacing),

        // Database
        const _SectionLabel(label: 'DATABASE & DEVICE'),
        const SizedBox(height: 8),
        DatabaseCard(health: health, onLocationsCleared: _runCheck),
        const SizedBox(height: DoctorTheme.cardSpacing),

        // Timestamp footer
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Checked at ${_formatTimestamp(health.timestamp)}',
              style: DoctorTheme.cardBodyStyle.copyWith(
                fontSize: 11,
                color: DoctorTheme.muted,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  String _formatTimestamp(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final s = local.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.count});
  final String label;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: DoctorTheme.sectionStyle),
        if (count != null && count! > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: DoctorTheme.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: DoctorTheme.chipStyle.copyWith(
                color: DoctorTheme.warning,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: DoctorTheme.cardSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: DoctorTheme.cardBorder,
              width: 0.5,
            ),
          ),
          child: Icon(icon, size: 18, color: DoctorTheme.accent),
        ),
      ),
    );
  }
}
