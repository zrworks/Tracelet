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

  AndroidConfig copyWith({
    int? locationUpdateInterval,
    int? fastestLocationUpdateInterval,
    int? deferTime,
    bool? allowIdenticalLocations,
    bool? geofenceModeHighAccuracy,
    bool? periodicUseForegroundService,
    bool? periodicUseExactAlarms,
    bool? scheduleUseAlarmManager,
    ForegroundServiceConfig? foregroundService,
  }) {
    return AndroidConfig(
      locationUpdateInterval:
          locationUpdateInterval ?? this.locationUpdateInterval,
      fastestLocationUpdateInterval:
          fastestLocationUpdateInterval ?? this.fastestLocationUpdateInterval,
      deferTime: deferTime ?? this.deferTime,
      allowIdenticalLocations:
          allowIdenticalLocations ?? this.allowIdenticalLocations,
      geofenceModeHighAccuracy:
          geofenceModeHighAccuracy ?? this.geofenceModeHighAccuracy,
      periodicUseForegroundService:
          periodicUseForegroundService ?? this.periodicUseForegroundService,
      periodicUseExactAlarms:
          periodicUseExactAlarms ?? this.periodicUseExactAlarms,
      scheduleUseAlarmManager:
          scheduleUseAlarmManager ?? this.scheduleUseAlarmManager,
      foregroundService: foregroundService ?? this.foregroundService,
    );
  }

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
    this.showNotificationOnPauseOnly = false,
    this.actions = const <String>[],
  });

  ForegroundServiceConfig copyWith({
    bool? enabled,
    String? channelId,
    String? channelName,
    String? notificationTitle,
    String? notificationText,
    String? notificationColor,
    String? notificationSmallIcon,
    String? notificationLargeIcon,
    NotificationPriority? notificationPriority,
    bool? notificationOngoing,
    bool? showNotificationOnPauseOnly,
    List<String>? actions,
  }) {
    return ForegroundServiceConfig(
      enabled: enabled ?? this.enabled,
      channelId: channelId ?? this.channelId,
      channelName: channelName ?? this.channelName,
      notificationTitle: notificationTitle ?? this.notificationTitle,
      notificationText: notificationText ?? this.notificationText,
      notificationColor: notificationColor ?? this.notificationColor,
      notificationSmallIcon:
          notificationSmallIcon ?? this.notificationSmallIcon,
      notificationLargeIcon:
          notificationLargeIcon ?? this.notificationLargeIcon,
      notificationPriority: notificationPriority ?? this.notificationPriority,
      notificationOngoing: notificationOngoing ?? this.notificationOngoing,
      showNotificationOnPauseOnly:
          showNotificationOnPauseOnly ?? this.showNotificationOnPauseOnly,
      actions: actions ?? this.actions,
    );
  }

  /// Whether the foreground service notification is enabled.
  /// Defaults to `true`.
  final bool enabled;

  /// The unique channel ID for the foreground service notification.
  /// Defaults to `'tracelet_channel'`.
  final String channelId;

  /// The user-visible channel name for the foreground service notification.
  /// Defaults to `'Tracelet'`.
  final String channelName;

  /// The notification title shown in the status bar/drawer.
  /// Defaults to `'Tracelet'`.
  final String notificationTitle;

  /// The notification body text.
  /// Defaults to `'Tracking location in background'`.
  final String notificationText;

  /// The hex color code for the notification's accent color (e.g. `'#4CAF50'`).
  /// Defaults to `null`.
  final String? notificationColor;

  /// The resource name for the notification's small icon.
  /// Defaults to `null`.
  final String? notificationSmallIcon;

  /// The resource name for the notification's large icon.
  /// Defaults to `null`.
  final String? notificationLargeIcon;

  /// The notification priority level.
  /// Defaults to [NotificationPriority.defaultPriority].
  final NotificationPriority notificationPriority;

  /// Whether the notification is persistent and cannot be swiped away by the user.
  /// Defaults to `true`.
  final bool notificationOngoing;

  /// Whether the notification is only shown when the app is in the background (paused).
  ///
  /// When `true`, the persistent notification is automatically dismissed when the app
  /// enters the foreground and restored when it enters the background.
  ///
  /// Defaults to `false`.
  final bool showNotificationOnPauseOnly;

  /// Action buttons to display inside the notification drawer (e.g. `['Stop', 'Sync']`).
  /// Defaults to empty list.
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
      showNotificationOnPauseOnly: ensureBool(
        map['showNotificationOnPauseOnly'],
        fallback: false,
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
    notificationPriority:
        TlNotificationPriority.values[notificationPriority.index],
    notificationOngoing: notificationOngoing,
    showNotificationOnPauseOnly: showNotificationOnPauseOnly,
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
      'showNotificationOnPauseOnly': showNotificationOnPauseOnly,
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
          showNotificationOnPauseOnly == other.showNotificationOnPauseOnly &&
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
    showNotificationOnPauseOnly,
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
