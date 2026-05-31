import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:tracelet_platform_interface/src/rust/api_dart/battery_budget.dart';
import 'package:tracelet_platform_interface/src/rust/state/battery_budget.dart';

/// Rust-powered battery budget engine.
class BatteryBudgetEngine {
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

  int getRecommendedIntervalMs(int defaultIntervalMs) {
    if (_inner == null) return defaultIntervalMs;
    final result = _inner!.getRecommendedIntervalMs(
      defaultIntervalMs: PlatformInt64Util.from(defaultIntervalMs),
    );
    return _toInt(result);
  }

  bool shouldThrottleLocation() {
    return _inner?.shouldThrottleLocation() ?? false;
  }

  bool isCharging() {
    return _inner?.isCharging() ?? false;
  }

  double get targetBudgetPerHour {
    // The dart side cannot directly access this from inner if it's not exposed,
    // but we can expose it via an FRB getter or just store it.
    // Wait, the tests check engine.targetBudgetPerHour! Let's store it.
    return _targetBudgetPerHour; // We need to add this field.
  }

  late final double _targetBudgetPerHour;

  double get distanceFilter => _inner?.getDistanceFilter() ?? 10.0;
  int get accuracyIndex => _inner?.getAccuracyIndex() ?? 0;
  int? get periodicInterval => _inner?.getPeriodicInterval();

  void reset() {
    _inner?.reset();
  }
}
