import 'package:meta/meta.dart';
import 'package:tracelet_platform_interface/tracelet_platform_interface.dart';
import '_helpers.dart';

/// Android-specific configuration settings.
///
/// These settings are ignored on iOS and Web.
@immutable
class AndroidConfig {
  /// Creates a new [AndroidConfig] with optional overrides.
  const AndroidConfig({
    this.locationUpdateInterval = 1000,
    this.fastestLocationUpdateInterval = 500,
    this.deferTime = 0,
    this.allowIdenticalLocations = false,
    this.geofenceModeHighAccuracy = false,
    this.periodicUseForegroundService = false,
    this.periodicUseExactAlarms = false,
    this.scheduleUseAlarmManager = false,
    this.foregroundService = const ForegroundServiceConfig(),
  });

  /// The desired interval (in milliseconds) between location updates.
  /// Defaults to `1000`.
  final int locationUpdateInterval;

  /// The fastest interval (in milliseconds) the app is able to receive
  /// location updates. Defaults to `500`.
  final int fastestLocationUpdateInterval;

  /// Maximum wait time (ms) for location updates. Defaults to `0`.
  final int deferTime;

  /// Allow recording identical consecutive locations. Defaults to `false`.
  final bool allowIdenticalLocations;

  /// Enable high-accuracy geofence monitoring during geofence-only mode.
  /// Defaults to `false`.
  final bool geofenceModeHighAccuracy;

  /// Whether to use a foreground service for periodic mode.
  /// Defaults to `false` (uses WorkManager).
  final bool periodicUseForegroundService;

  /// Use exact alarms instead of WorkManager for periodic scheduling.
  /// Requires `SCHEDULE_EXACT_ALARM` permission on API 31+.
  /// Defaults to `false`.
  final bool periodicUseExactAlarms;

  /// Use `AlarmManager` for precise schedule execution.
  /// Defaults to `false` (uses WorkManager).
  final bool scheduleUseAlarmManager;

  /// Foreground service notification configuration.
  final ForegroundServiceConfig foregroundService;

  /// Creates an [AndroidConfig] from a map.
  factory AndroidConfig.fromMap(Map<String, Object?> map) {
    final fgMap = safeMap(map['foregroundService']);
    return AndroidConfig(
      locationUpdateInterval: ensureInt(
        map['locationUpdateInterval'],
        fallback: 1000,
      ),
      fastestLocationUpdateInterval: ensureInt(
        map['fastestLocationUpdateInterval'],
        fallback: 500,
      ),
      deferTime: ensureInt(map['deferTime'], fallback: 0),
      allowIdenticalLocations: ensureBool(
        map['allowIdenticalLocations'],
        fallback: false,
      ),
      geofenceModeHighAccuracy: ensureBool(
        map['geofenceModeHighAccuracy'],
        fallback: false,
      ),
      periodicUseForegroundService: ensureBool(
        map['periodicUseForegroundService'],
        fallback: false,
      ),
      periodicUseExactAlarms: ensureBool(
        map['periodicUseExactAlarms'],
        fallback: false,
      ),
      scheduleUseAlarmManager: ensureBool(
        map['scheduleUseAlarmManager'],
        fallback: false,
      ),
      foregroundService: fgMap != null
          ? ForegroundServiceConfig.fromMap(fgMap)
          : const ForegroundServiceConfig(),
    );
  }

  /// Converts to Pigeon [TlAndroidConfig].
  TlAndroidConfig toTlConfig() => TlAndroidConfig(
        locationUpdateInterval: locationUpdateInterval,
        fastestLocationUpdateInterval: fastestLocationUpdateInterval,
        deferTime: deferTime,
        allowIdenticalLocations: allowIdenticalLocations,
        geofenceModeHighAccuracy: geofenceModeHighAccuracy,
        periodicUseForegroundService: periodicUseForegroundService,
        periodicUseExactAlarms: periodicUseExactAlarms,
        scheduleUseAlarmManager: scheduleUseAlarmManager,
        foregroundService: foregroundService.toTlConfig(),
      );

  /// Serializes to a map.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'locationUpdateInterval': locationUpdateInterval,
      'fastestLocationUpdateInterval': fastestLocationUpdateInterval,
      'deferTime': deferTime,
      'allowIdenticalLocations': allowIdenticalLocations,
      'geofenceModeHighAccuracy': geofenceModeHighAccuracy,
      'periodicUseForegroundService': periodicUseForegroundService,
      'periodicUseExactAlarms': periodicUseExactAlarms,
      'scheduleUseAlarmManager': scheduleUseAlarmManager,
      'foregroundService': foregroundService.toMap(),
    };
  }

  @override
  String toString() =>
      'AndroidConfig(locationUpdateInterval: $locationUpdateInterval, '
      'foregroundService: $foregroundService)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AndroidConfig &&
          runtimeType == other.runtimeType &&
          locationUpdateInterval == other.locationUpdateInterval &&
          fastestLocationUpdateInterval ==
              other.fastestLocationUpdateInterval &&
          deferTime == other.deferTime &&
          allowIdenticalLocations == other.allowIdenticalLocations &&
          geofenceModeHighAccuracy == other.geofenceModeHighAccuracy &&
          periodicUseForegroundService == other.periodicUseForegroundService &&
          periodicUseExactAlarms == other.periodicUseExactAlarms &&
          scheduleUseAlarmManager == other.scheduleUseAlarmManager &&
          foregroundService == other.foregroundService;

  @override
  int get hashCode => Object.hash(
    locationUpdateInterval,
    fastestLocationUpdateInterval,
    deferTime,
    allowIdenticalLocations,
    geofenceModeHighAccuracy,
    periodicUseForegroundService,
    periodicUseExactAlarms,
    scheduleUseAlarmManager,
    foregroundService,
  );
}

/// Configuration for the Android foreground service notification.
@immutable
class ForegroundServiceConfig {
  const ForegroundServiceConfig({
    this.enabled = true,
    this.channelId = 'tracelet_channel',
    this.channelName = 'Tracelet',
    this.notificationTitle = 'Tracelet',
    this.notificationText = 'Tracking location in background',
    this.notificationColor,
    this.notificationSmallIcon,
    this.notificationLargeIcon,
    this.notificationPriority = NotificationPriority.defaultPriority,
    this.notificationOngoing = true,
    this.actions = const <String>[],
  });

  final bool enabled;
  final String channelId;
  final String channelName;
  final String notificationTitle;
  final String notificationText;
  final String? notificationColor;
  final String? notificationSmallIcon;
  final String? notificationLargeIcon;
  final NotificationPriority notificationPriority;
  final bool notificationOngoing;
  final List<String> actions;

  factory ForegroundServiceConfig.fromMap(Map<String, Object?> map) {
    final rawActions = map['actions'];
    final actionsList = <String>[];
    if (rawActions is List) {
      for (final item in rawActions) {
        if (item is String) actionsList.add(item);
      }
    }
    return ForegroundServiceConfig(
      enabled: ensureBool(map['enabled'], fallback: true),
      channelId: map['channelId'] as String? ?? 'tracelet_channel',
      channelName: map['channelName'] as String? ?? 'Tracelet',
      notificationTitle: map['notificationTitle'] as String? ?? 'Tracelet',
      notificationText:
          map['notificationText'] as String? ??
          'Tracking location in background',
      notificationColor: map['notificationColor'] as String?,
      notificationSmallIcon: map['notificationSmallIcon'] as String?,
      notificationLargeIcon: map['notificationLargeIcon'] as String?,
      notificationPriority: _parseNotificationPriority(
        map['notificationPriority'],
      ),
      notificationOngoing: ensureBool(
        map['notificationOngoing'],
        fallback: true,
      ),
      actions: actionsList,
    );
  }

  /// Converts to Pigeon [TlForegroundServiceConfig].
  TlForegroundServiceConfig toTlConfig() => TlForegroundServiceConfig(
        enabled: enabled,
        channelId: channelId,
        channelName: channelName,
        notificationTitle: notificationTitle,
        notificationText: notificationText,
        notificationColor: notificationColor,
        notificationSmallIcon: notificationSmallIcon,
        notificationLargeIcon: notificationLargeIcon,
        notificationPriority: TlNotificationPriority.values[notificationPriority.index],
        notificationOngoing: notificationOngoing,
        actions: actions,
      );

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'enabled': enabled,
      'channelId': channelId,
      'channelName': channelName,
      'notificationTitle': notificationTitle,
      'notificationText': notificationText,
      'notificationColor': notificationColor,
      'notificationSmallIcon': notificationSmallIcon,
      'notificationLargeIcon': notificationLargeIcon,
      'notificationPriority': notificationPriority.index,
      'notificationOngoing': notificationOngoing,
      'actions': actions,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ForegroundServiceConfig &&
          runtimeType == other.runtimeType &&
          enabled == other.enabled &&
          channelId == other.channelId &&
          channelName == other.channelName &&
          notificationTitle == other.notificationTitle &&
          notificationText == other.notificationText &&
          notificationColor == other.notificationColor &&
          notificationSmallIcon == other.notificationSmallIcon &&
          notificationLargeIcon == other.notificationLargeIcon &&
          notificationPriority == other.notificationPriority &&
          notificationOngoing == other.notificationOngoing &&
          actions == other.actions;

  @override
  int get hashCode => Object.hash(
        enabled,
        channelId,
        channelName,
        notificationTitle,
        notificationText,
        notificationColor,
        notificationSmallIcon,
        notificationLargeIcon,
        notificationPriority,
        notificationOngoing,
        actions,
      );
}

NotificationPriority _parseNotificationPriority(Object? value) {
  final index = value is int ? value : 2;
  if (index < 0 || index >= NotificationPriority.values.length) {
    return NotificationPriority.defaultPriority;
  }
  return NotificationPriority.values[index];
}
