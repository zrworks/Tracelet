import '../rust/api_dart/battery_budget.dart';
import '../rust/state/battery_budget.dart';

/// Rust-powered battery budget engine.
class BatteryBudgetEngine {
  late final BatteryBudgetEngineDart _inner;
  final DateTime Function() _clock;

  BatteryBudgetEngine({
    double targetBudgetPerHour = 3.0,
    double initialDistanceFilter = 10.0,
    int initialAccuracyIndex = 0,
    int? initialPeriodicInterval,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       _targetBudgetPerHour = targetBudgetPerHour {
    _inner = BatteryBudgetEngineDart(
      targetBudgetPerHour: targetBudgetPerHour,
      initialDistanceFilter: initialDistanceFilter,
      initialAccuracyIndex: initialAccuracyIndex,
      initialPeriodicInterval: initialPeriodicInterval,
    );
  }

  BudgetAdjustmentEvent? processSample(
    double batteryLevel, {
    bool isCharging = false,
  }) {
    return _inner.processSample(
      level: batteryLevel,
      isCharging: isCharging,
      timestampMs: BigInt.from(_clock().millisecondsSinceEpoch),
    );
  }

  int getRecommendedIntervalMs(int defaultIntervalMs) {
    return _inner
        .getRecommendedIntervalMs(
          defaultIntervalMs: BigInt.from(defaultIntervalMs),
        )
        .toInt();
  }

  bool shouldThrottleLocation() {
    return _inner.shouldThrottleLocation();
  }

  bool isCharging() {
    return _inner.isCharging();
  }

  double get targetBudgetPerHour {
    // The dart side cannot directly access this from inner if it's not exposed,
    // but we can expose it via an FRB getter or just store it.
    // Wait, the tests check engine.targetBudgetPerHour! Let's store it.
    return _targetBudgetPerHour; // We need to add this field.
  }

  late final double _targetBudgetPerHour;

  double get distanceFilter => _inner.getDistanceFilter();
  int get accuracyIndex => _inner.getAccuracyIndex();
  int? get periodicInterval => _inner.getPeriodicInterval();

  void reset() {
    _inner.reset();
  }
}
