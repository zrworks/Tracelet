import '../types/enums.dart';

/// Contextual data used by [AdaptiveSamplingEngine] to compute the
/// optimal distance filter for each location fix.
///
/// This bundles battery state, detected activity, and speed so the engine
/// can make a holistic decision about sampling aggressiveness.
class AdaptiveContext {
  /// Creates an [AdaptiveContext].
  ///
  /// - [batteryLevel]: Battery percentage as 0.0–1.0 (-1 if unknown).
  /// - [isCharging]: Whether the device is plugged in.
  /// - [activityType]: Last detected motion activity.
  /// - [activityConfidence]: Confidence of the detected activity.
  /// - [speed]: Current speed in m/s (0 or negative if unknown).
  const AdaptiveContext({
    this.batteryLevel = -1.0,
    this.isCharging = false,
    this.activityType = ActivityType.unknown,
    this.activityConfidence = ActivityConfidence.low,
    this.speed = 0,
  });

  /// Battery level as a fraction (0.0 = empty, 1.0 = full, -1 = unknown).
  final double batteryLevel;

  /// Whether the device is currently charging.
  final bool isCharging;

  /// The last detected motion activity type.
  final ActivityType activityType;

  /// The confidence of the detected activity.
  final ActivityConfidence activityConfidence;

  /// Current speed in m/s (0 or negative if unknown).
  final double speed;

  @override
  String toString() =>
      'AdaptiveContext(battery=$batteryLevel, charging=$isCharging, '
      'activity=$activityType@$activityConfidence, speed=$speed)';
}

/// Result of an adaptive sampling computation.
///
/// Contains the computed effective distance filter and a breakdown of the
/// factors that produced it, useful for logging and debugging.
class AdaptiveSamplingResult {
  /// Creates an [AdaptiveSamplingResult].
  const AdaptiveSamplingResult({
    required this.effectiveDistanceFilter,
    required this.baseDistanceFilter,
    required this.activityFactor,
    required this.batteryFactor,
    required this.speedFactor,
    required this.source,
  });

  /// The computed distance filter in meters.
  final double effectiveDistanceFilter;

  /// The original base distance filter from config.
  final double baseDistanceFilter;

  /// Multiplier applied based on detected activity.
  final double activityFactor;

  /// Multiplier applied based on battery state.
  final double batteryFactor;

  /// Multiplier from speed-based elasticity.
  final double speedFactor;

  /// Which factor was the primary source of the calculation.
  final AdaptiveSource source;

  @override
  String toString() =>
      'AdaptiveSamplingResult(effective=${effectiveDistanceFilter.toStringAsFixed(1)}m, '
      'base=${baseDistanceFilter.toStringAsFixed(1)}m, '
      'activity=$activityFactor, battery=$batteryFactor, '
      'speed=$speedFactor, source=$source)';
}

/// Which factor was the primary driver of the adaptive calculation.
enum AdaptiveSource {
  /// Activity-based profile was used.
  activity,

  /// Speed-based elasticity was used (activity unknown or low confidence).
  speed,

  /// Static — no adaptive adjustment was applied.
  static_,
}

/// Calculates optimal distance filters based on multi-factor context.
///
/// The adaptive sampling engine replaces the simple speed-only elasticity
/// in [LocationProcessor] with a holistic approach that considers:
///
/// 1. **Activity type** — Detected motion (still / walking / driving) sets
///    an activity-appropriate base distance profile.
/// 2. **Battery state** — Progressively increases the distance filter as
///    battery drains, unless the device is charging.
/// 3. **Speed** — Fine-tunes the result using speed-based elasticity when
///    activity type is unknown or has low confidence.
///
/// ## Activity profiles (distance filter targets)
///
/// | Activity     | Distance filter | Rationale |
/// |--------------|----------------|-----------|
/// | still        | 500m           | Minimal sampling to save battery |
/// | walking      | 50m            | Pedestrian-grade accuracy |
/// | running      | 30m            | Higher cadence than walking |
/// | onFoot       | 50m            | Same as walking |
/// | onBicycle    | 25m            | Cyclist speeds need denser sampling |
/// | inVehicle    | 10m            | Vehicle tracking needs high density |
/// | unknown      | speed-based    | Falls back to elasticity formula |
///
/// ## Battery scaling (applied multiplicatively)
///
/// | Battery %      | Factor | Effect |
/// |----------------|--------|--------|
/// | > 50%          | 1.0    | No change |
/// | 20–50%         | 1.5    | 50% wider filter |
/// | 10–20%         | 2.5    | 150% wider filter |
/// | < 10%          | 5.0    | 400% wider filter |
/// | Charging       | 1.0    | No battery scaling |
/// | Unknown (-1)   | 1.0    | No battery scaling |
///
/// ## Usage
///
/// ```dart
/// final engine = AdaptiveSamplingEngine(baseDistanceFilter: 10.0);
/// final result = engine.compute(AdaptiveContext(
///   activityType: ActivityType.walking,
///   activityConfidence: ActivityConfidence.high,
///   batteryLevel: 0.35,
///   isCharging: false,
///   speed: 1.4,
/// ));
/// print(result.effectiveDistanceFilter); // 75.0 (50m × 1.5 battery)
/// ```
class AdaptiveSamplingEngine {
  /// Creates an [AdaptiveSamplingEngine].
  ///
  /// - [baseDistanceFilter]: The configured `distanceFilter` from [GeoConfig].
  /// - [elasticityMultiplier]: The configured multiplier for speed-based
  ///   scaling. Only used when falling back to speed-based elasticity.
  const AdaptiveSamplingEngine({
    required this.baseDistanceFilter,
    this.elasticityMultiplier = 1.0,
  });

  /// The base distance filter in meters from config.
  final double baseDistanceFilter;

  /// Elasticity multiplier for speed-based fallback.
  final double elasticityMultiplier;

  // ─────────────────────────────────────────────────────────────────────────
  // Activity distance profiles (meters)
  // ─────────────────────────────────────────────────────────────────────────

  /// Distance filter profile for [ActivityType.still].
  static const double distanceStill = 500.0;

  /// Distance filter profile for [ActivityType.walking] and
  /// [ActivityType.onFoot].
  static const double distanceWalking = 50.0;

  /// Distance filter profile for [ActivityType.running].
  static const double distanceRunning = 30.0;

  /// Distance filter profile for [ActivityType.onBicycle].
  static const double distanceBicycle = 25.0;

  /// Distance filter profile for [ActivityType.inVehicle].
  static const double distanceVehicle = 10.0;

  // ─────────────────────────────────────────────────────────────────────────
  // Battery thresholds
  // ─────────────────────────────────────────────────────────────────────────

  /// Battery level above which no scaling is applied.
  static const double batteryHighThreshold = 0.50;

  /// Battery level below which moderate scaling kicks in.
  static const double batteryMediumThreshold = 0.20;

  /// Battery level below which aggressive scaling kicks in.
  static const double batteryLowThreshold = 0.10;

  /// Scaling factor when battery is between [batteryMediumThreshold] and
  /// [batteryHighThreshold].
  static const double batteryMediumFactor = 1.5;

  /// Scaling factor when battery is between [batteryLowThreshold] and
  /// [batteryMediumThreshold].
  static const double batteryLowFactor = 2.5;

  /// Scaling factor when battery is below [batteryLowThreshold].
  static const double batteryCriticalFactor = 5.0;

  /// Compute the optimal distance filter for the given [context].
  ///
  /// Returns an [AdaptiveSamplingResult] with the effective distance filter
  /// and a breakdown of factors.
  AdaptiveSamplingResult compute(AdaptiveContext context) {
    double activityFactor = 1.0;
    double speedFactor = 1.0;
    var source = AdaptiveSource.static_;

    // ── Activity-based distance ───────────────────────────────────────────
    // Use activity profiles when confidence is medium or high and the
    // activity type is known.
    final useActivity =
        context.activityType != ActivityType.unknown &&
        context.activityConfidence != ActivityConfidence.low;

    if (useActivity) {
      final activityDistance = _activityDistance(context.activityType);
      // Express as a factor relative to the base distance filter so that
      // battery scaling and the user's configured base are respected.
      activityFactor = activityDistance / baseDistanceFilter;
      source = AdaptiveSource.activity;
    } else if (context.speed > 0) {
      // Fallback: speed-based elasticity (same formula as LocationProcessor).
      final mult = elasticityMultiplier < 0.1 ? 0.1 : elasticityMultiplier;
      speedFactor = (context.speed / 10.0).clamp(1.0, 10.0) * mult;
      source = AdaptiveSource.speed;
    }

    // ── Battery scaling ───────────────────────────────────────────────────
    final batteryFactor = _batteryFactor(
      context.batteryLevel,
      context.isCharging,
    );

    // ── Combine ───────────────────────────────────────────────────────────
    // When using activity profiles, the distance is:
    //   activityDistance × batteryFactor
    // When using speed elasticity, the distance is:
    //   baseDistanceFilter × speedFactor × batteryFactor
    // When neither is active:
    //   baseDistanceFilter × batteryFactor
    final double effective;
    switch (source) {
      case AdaptiveSource.activity:
        effective = baseDistanceFilter * activityFactor * batteryFactor;
      case AdaptiveSource.speed:
        effective = baseDistanceFilter * speedFactor * batteryFactor;
      case AdaptiveSource.static_:
        effective = baseDistanceFilter * batteryFactor;
    }

    return AdaptiveSamplingResult(
      effectiveDistanceFilter: effective,
      baseDistanceFilter: baseDistanceFilter,
      activityFactor: activityFactor,
      batteryFactor: batteryFactor,
      speedFactor: speedFactor,
      source: source,
    );
  }

  /// Returns the distance filter target for a given [activity].
  double _activityDistance(ActivityType activity) {
    switch (activity) {
      case ActivityType.still:
        return distanceStill;
      case ActivityType.walking:
      case ActivityType.onFoot:
        return distanceWalking;
      case ActivityType.running:
        return distanceRunning;
      case ActivityType.onBicycle:
        return distanceBicycle;
      case ActivityType.inVehicle:
        return distanceVehicle;
      case ActivityType.unknown:
        return baseDistanceFilter;
    }
  }

  /// Returns the battery scaling factor.
  ///
  /// Returns 1.0 when:
  /// - Battery is above 50%
  /// - Device is charging
  /// - Battery level is unknown (-1)
  double _batteryFactor(double batteryLevel, bool isCharging) {
    // No scaling while charging or when battery level is unknown.
    if (isCharging || batteryLevel < 0) return 1.0;

    if (batteryLevel < batteryLowThreshold) return batteryCriticalFactor;
    if (batteryLevel < batteryMediumThreshold) return batteryLowFactor;
    if (batteryLevel < batteryHighThreshold) return batteryMediumFactor;
    return 1.0;
  }
}
