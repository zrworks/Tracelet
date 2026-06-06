import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:tracelet_platform_interface/src/rust/api_dart/battery_budget.dart';
import 'package:tracelet_platform_interface/src/rust/state/battery_budget.dart';

/// Rust-powered battery budget engine.
class BatteryBudgetEngine {
  /// Creates a new [BatteryBudgetEngine].
  ///
  /// The [targetBudgetPerHour] defines the maximum acceptable battery drain per hour.
  /// The [initialDistanceFilter] sets the starting distance filter in meters.
  /// The [initialAccuracyIndex] sets the starting accuracy level.
  /// The [initialPeriodicInterval] sets the starting periodic interval in milliseconds.
  /// The [clock] can be optionally injected for testing purposes.
  BatteryBudgetEngine({
    double targetBudgetPerHour = 3.0,
    double initialDistanceFilter = 10.0,
    int initialAccuracyIndex = 0,
    int? initialPeriodicInterval,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       _targetBudgetPerHour = targetBudgetPerHour {
    if (!kIsWeb) {
      _inner = BatteryBudgetEngineDart(
        targetBudgetPerHour: targetBudgetPerHour,
        initialDistanceFilter: initialDistanceFilter,
        initialAccuracyIndex: initialAccuracyIndex,
        initialPeriodicInterval: initialPeriodicInterval,
      );
    }
  }
  BatteryBudgetEngineDart? _inner;
  final DateTime Function() _clock;

  /// Processes a new battery sample and returns a [BudgetAdjustmentEvent] if
  /// the engine determines the tracking parameters should be adjusted.
  ///
  /// Provide the current [batteryLevel] (0.0 to 1.0) and whether the device
  /// [isCharging].
  BudgetAdjustmentEvent? processSample(
    double batteryLevel, {
    bool isCharging = false,
  }) {
    if (_inner == null) return null;
    return _inner!.processSample(
      level: batteryLevel,
      isCharging: isCharging,
      timestampMs: PlatformInt64Util.from(_clock().millisecondsSinceEpoch),
    );
  }

  static int _toInt(dynamic val) {
    if (val is BigInt) return val.toInt();
    if (val is int) return val;
    return int.parse(val.toString());
  }

  /// Calculates the recommended polling interval based on the current battery drain.
  ///
  /// Provide the [defaultIntervalMs] as the base interval.
  int getRecommendedIntervalMs(int defaultIntervalMs) {
    if (_inner == null) return defaultIntervalMs;
    final result = _inner!.getRecommendedIntervalMs(
      defaultIntervalMs: PlatformInt64Util.from(defaultIntervalMs),
    );
    return _toInt(result);
  }

  /// Returns true if the engine determines that location tracking should be
  /// throttled down to save battery.
  bool shouldThrottleLocation() {
    return _inner?.shouldThrottleLocation() ?? false;
  }

  /// Returns true if the device is currently charging.
  bool isCharging() {
    return _inner?.isCharging() ?? false;
  }

  /// The target battery drain allowed per hour.
  double get targetBudgetPerHour {
    // The dart side cannot directly access this from inner if it's not exposed,
    // but we can expose it via an FRB getter or just store it.
    // Wait, the tests check engine.targetBudgetPerHour! Let's store it.
    return _targetBudgetPerHour; // We need to add this field.
  }

  late final double _targetBudgetPerHour;

  /// The current dynamic distance filter applied by the engine.
  double get distanceFilter => _inner?.getDistanceFilter() ?? 10.0;

  /// The current dynamic accuracy index applied by the engine.
  int get accuracyIndex => _inner?.getAccuracyIndex() ?? 0;

  /// The current dynamic periodic interval applied by the engine.
  int? get periodicInterval => _inner?.getPeriodicInterval();

  /// Resets the engine state, clearing history and resetting filters to initial values.
  void reset() {
    _inner?.reset();
  }
}
