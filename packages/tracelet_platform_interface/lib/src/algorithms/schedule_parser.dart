import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:tracelet_platform_interface/src/rust/api_dart/schedule.dart';

/// Rust-powered schedule parsing and matching.
class ScheduleParser {
  ScheduleParser._(); // Prevent instantiation.

  static final ScheduleParserDart _inner = ScheduleParserDart();

  /// Check whether [now] (or the current time) falls within any of the
  /// given [schedules].
  static bool isWithinSchedule(List<String> schedules, [DateTime? now]) {
    if (schedules.isEmpty) return false;
    now ??= DateTime.now();
    return _inner.isWithinSchedule(
      schedules: schedules,
      timestampMs: PlatformInt64Util.from(now.millisecondsSinceEpoch),
      tzOffsetSeconds: now.timeZoneOffset.inSeconds,
    );
  }

  /// Check whether a single [schedule] string matches the given [now] time.
  static bool matchesSchedule(String schedule, DateTime now) {
    return isWithinSchedule([schedule], now);
  }

  static int _toInt(dynamic val) {
    if (val is BigInt) return val.toInt();
    if (val is int) return val;
    return int.parse(val.toString());
  }

  /// Calculate the next start and stop timestamps from a schedule string.
  static ({DateTime? start, DateTime? stop}) calculateNextAlarms(
    String schedule, [
    DateTime? now,
  ]) {
    now ??= DateTime.now();
    final alarms = _inner.calculateNextAlarms(
      schedules: [schedule],
      timestampMs: PlatformInt64Util.from(now.millisecondsSinceEpoch),
      tzOffsetSeconds: now.timeZoneOffset.inSeconds,
    );
    final startMs = _toInt(alarms.nextStartMs);
    final stopMs = _toInt(alarms.nextStopMs);
    return (
      start: startMs > 0 ? DateTime.fromMillisecondsSinceEpoch(startMs) : null,
      stop: stopMs > 0 ? DateTime.fromMillisecondsSinceEpoch(stopMs) : null,
    );
  }

  /// Parse a schedule string into a [ScheduleWindow], or `null` if
  /// the format is invalid.
  static ScheduleWindow? parse(String schedule) {
    final parts = schedule.trim().split(' ');
    if (parts.length != 2) return null;

    final dayRange = parts[0].split('-');
    final timeRange = parts[1].split('-');
    if (dayRange.length != 2 || timeRange.length != 2) return null;

    try {
      final dayStart = int.parse(dayRange[0]);
      final dayEnd = int.parse(dayRange[1]);
      final startMinutes = _parseTime(timeRange[0]);
      final endMinutes = _parseTime(timeRange[1]);
      if (startMinutes == null || endMinutes == null) return null;

      return ScheduleWindow(
        dayStart: dayStart,
        dayEnd: dayEnd,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
      );
    } catch (_) {
      return null;
    }
  }

  static int? _parseTime(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }
}

/// A parsed schedule window representing active days and times.
class ScheduleWindow {
  const ScheduleWindow({
    required this.dayStart,
    required this.dayEnd,
    required this.startMinutes,
    required this.endMinutes,
  });

  /// 1 (Monday) to 7 (Sunday).
  final int dayStart;
  final int dayEnd;

  /// Minutes since midnight.
  final int startMinutes;
  final int endMinutes;

  String get startTime =>
      '${(startMinutes ~/ 60).toString().padLeft(2, '0')}:${(startMinutes % 60).toString().padLeft(2, '0')}';
  String get endTime =>
      '${(endMinutes ~/ 60).toString().padLeft(2, '0')}:${(endMinutes % 60).toString().padLeft(2, '0')}';

  @override
  String toString() {
    return 'ScheduleWindow(days=$dayStart-$dayEnd, time=$startTime-$endTime)';
  }
}
