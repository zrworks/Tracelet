import 'package:meta/meta.dart';
import 'package:tracelet/src/models/_helpers.dart';
import 'package:tracelet_platform_interface/tracelet_platform_interface.dart';

/// iOS-specific configuration settings.
///
/// These settings are ignored on Android and Web.
@immutable
class IosConfig {
  /// Creates a new [IosConfig] with optional overrides.
  const IosConfig({
    this.activityType = LocationActivityType.other,
    this.useSignificantChangesOnly = false,
    this.showsBackgroundLocationIndicator = false,
    this.pausesLocationUpdatesAutomatically = false,
    this.locationAuthorizationRequest = LocationAuthorizationRequest.always,
    this.disableLocationAuthorizationAlert = false,
    this.preventSuspend = false,
  });

  /// Creates an [IosConfig] from a map.
  factory IosConfig.fromMap(Map<String, Object?> map) {
    return IosConfig(
      activityType:
          LocationActivityType.values[ensureInt(
            map['activityType'],
            fallback: 0,
          ).clamp(0, LocationActivityType.values.length - 1)],
      useSignificantChangesOnly: ensureBool(
        map['useSignificantChangesOnly'],
        fallback: false,
      ),
      showsBackgroundLocationIndicator: ensureBool(
        map['showsBackgroundLocationIndicator'],
        fallback: false,
      ),
      pausesLocationUpdatesAutomatically: ensureBool(
        map['pausesLocationUpdatesAutomatically'],
        fallback: false,
      ),
      locationAuthorizationRequest: _parseLocationAuthorizationRequest(
        map['locationAuthorizationRequest'],
      ),
      disableLocationAuthorizationAlert: ensureBool(
        map['disableLocationAuthorizationAlert'],
        fallback: false,
      ),
      preventSuspend: ensureBool(map['preventSuspend'], fallback: false),
    );
  }

  /// Hint to the platform about the type of activity being performed.
  /// Defaults to [LocationActivityType.other].
  final LocationActivityType activityType;

  /// Use significant-change monitoring instead of standard location updates.
  /// Saves battery but lower accuracy. Defaults to `false`.
  final bool useSignificantChangesOnly;

  /// Show the blue status bar indicator when tracking in the background.
  /// Defaults to `false`.
  final bool showsBackgroundLocationIndicator;

  /// Allow iOS to automatically pause location updates.
  /// Defaults to `false`.
  final bool pausesLocationUpdatesAutomatically;

  /// The location authorization level to request.
  /// Defaults to [LocationAuthorizationRequest.always].
  final LocationAuthorizationRequest locationAuthorizationRequest;

  /// Disable the automatic alert shown when the user has disabled required
  /// location authorization. Defaults to `false`.
  final bool disableLocationAuthorizationAlert;

  /// Play a silent audio clip to keep the app alive in the background.
  /// Defaults to `false`.
  final bool preventSuspend;

  /// Converts to Pigeon [TlIosConfig].
  TlIosConfig toTlConfig() => TlIosConfig(
    activityType: TlIosActivityType.values[activityType.index],
    useSignificantChangesOnly: useSignificantChangesOnly,
    showsBackgroundLocationIndicator: showsBackgroundLocationIndicator,
    pausesLocationUpdatesAutomatically: pausesLocationUpdatesAutomatically,
    locationAuthorizationRequest:
        locationAuthorizationRequest == LocationAuthorizationRequest.always
        ? TlAuthorizationRequest.always
        : TlAuthorizationRequest.whenInUse,
    disableLocationAuthorizationAlert: disableLocationAuthorizationAlert,
    preventSuspend: preventSuspend,
  );

  /// Serializes to a map.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'activityType': activityType.index,
      'useSignificantChangesOnly': useSignificantChangesOnly,
      'showsBackgroundLocationIndicator': showsBackgroundLocationIndicator,
      'pausesLocationUpdatesAutomatically': pausesLocationUpdatesAutomatically,
      'locationAuthorizationRequest':
          locationAuthorizationRequest == LocationAuthorizationRequest.always
          ? 'Always'
          : 'WhenInUse',
      'disableLocationAuthorizationAlert': disableLocationAuthorizationAlert,
      'preventSuspend': preventSuspend,
    };
  }

  @override
  String toString() =>
      'IosConfig(activityType: $activityType, '
      'preventSuspend: $preventSuspend)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IosConfig &&
          runtimeType == other.runtimeType &&
          activityType == other.activityType &&
          useSignificantChangesOnly == other.useSignificantChangesOnly &&
          showsBackgroundLocationIndicator ==
              other.showsBackgroundLocationIndicator &&
          pausesLocationUpdatesAutomatically ==
              other.pausesLocationUpdatesAutomatically &&
          locationAuthorizationRequest == other.locationAuthorizationRequest &&
          disableLocationAuthorizationAlert ==
              other.disableLocationAuthorizationAlert &&
          preventSuspend == other.preventSuspend;

  @override
  int get hashCode => Object.hash(
    activityType,
    useSignificantChangesOnly,
    showsBackgroundLocationIndicator,
    pausesLocationUpdatesAutomatically,
    locationAuthorizationRequest,
    disableLocationAuthorizationAlert,
    preventSuspend,
  );
}

LocationAuthorizationRequest _parseLocationAuthorizationRequest(Object? value) {
  if (value == 'WhenInUse') return LocationAuthorizationRequest.whenInUse;
  if (value == 'Always') return LocationAuthorizationRequest.always;
  // Fallback to Always for backward compat in background context
  return LocationAuthorizationRequest.always;
}
