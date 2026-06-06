import 'dart:async';

/// Central event dispatcher for Tracelet web.
///
/// Replaces the native EventChannel mechanism. The app-facing `Tracelet`
/// class listens on EventChannels, but on web we register stream controllers
/// directly via the Flutter plugin registrant and emit events here.
///
/// Events are broadcast streams so multiple listeners can subscribe.
class WebEventDispatcher {
  // ---------------------------------------------------------------------------
  // Stream controllers (broadcast)
  // ---------------------------------------------------------------------------

  final StreamController<Map<String, Object?>> _locationController =
      StreamController<Map<String, Object?>>.broadcast();

  final StreamController<Map<String, Object?>> _motionChangeController =
      StreamController<Map<String, Object?>>.broadcast();

  final StreamController<Map<String, Object?>> _activityChangeController =
      StreamController<Map<String, Object?>>.broadcast();

  final StreamController<Map<String, Object?>> _providerChangeController =
      StreamController<Map<String, Object?>>.broadcast();

  final StreamController<Map<String, Object?>> _geofenceController =
      StreamController<Map<String, Object?>>.broadcast();

  final StreamController<Map<String, Object?>> _geofencesChangeController =
      StreamController<Map<String, Object?>>.broadcast();

  final StreamController<Map<String, Object?>> _heartbeatController =
      StreamController<Map<String, Object?>>.broadcast();

  final StreamController<Map<String, Object?>> _httpController =
      StreamController<Map<String, Object?>>.broadcast();

  final StreamController<Map<String, Object?>> _scheduleController =
      StreamController<Map<String, Object?>>.broadcast();

  final StreamController<bool> _powerSaveChangeController =
      StreamController<bool>.broadcast();

  final StreamController<Map<String, Object?>> _connectivityChangeController =
      StreamController<Map<String, Object?>>.broadcast();

  final StreamController<bool> _enabledChangeController =
      StreamController<bool>.broadcast();

  final StreamController<String> _notificationActionController =
      StreamController<String>.broadcast();

  final StreamController<Map<String, Object?>> _authorizationController =
      StreamController<Map<String, Object?>>.broadcast();

  final StreamController<Map<String, Object?>> _watchPositionController =
      StreamController<Map<String, Object?>>.broadcast();

  // ---------------------------------------------------------------------------
  // Public streams
  // ---------------------------------------------------------------------------

  /// Documentation for onLocation.
  Stream<Map<String, Object?>> get onLocation => _locationController.stream;

  /// Documentation for onMotionChange.
  Stream<Map<String, Object?>> get onMotionChange =>
      _motionChangeController.stream;

  /// Documentation for onActivityChange.
  Stream<Map<String, Object?>> get onActivityChange =>
      _activityChangeController.stream;

  /// Documentation for onProviderChange.
  Stream<Map<String, Object?>> get onProviderChange =>
      _providerChangeController.stream;

  /// Documentation for onGeofence.
  Stream<Map<String, Object?>> get onGeofence => _geofenceController.stream;

  /// Documentation for onGeofencesChange.
  Stream<Map<String, Object?>> get onGeofencesChange =>
      _geofencesChangeController.stream;

  /// Documentation for onHeartbeat.
  Stream<Map<String, Object?>> get onHeartbeat => _heartbeatController.stream;

  /// Documentation for onHttp.
  Stream<Map<String, Object?>> get onHttp => _httpController.stream;

  /// Documentation for onSchedule.
  Stream<Map<String, Object?>> get onSchedule => _scheduleController.stream;

  /// Documentation for onPowerSaveChange.
  Stream<bool> get onPowerSaveChange => _powerSaveChangeController.stream;

  /// Documentation for onConnectivityChange.
  Stream<Map<String, Object?>> get onConnectivityChange =>
      _connectivityChangeController.stream;

  /// Documentation for onEnabledChange.
  Stream<bool> get onEnabledChange => _enabledChangeController.stream;

  /// Documentation for onNotificationAction.
  Stream<String> get onNotificationAction =>
      _notificationActionController.stream;

  /// Documentation for onAuthorization.
  Stream<Map<String, Object?>> get onAuthorization =>
      _authorizationController.stream;

  /// Documentation for onWatchPosition.
  Stream<Map<String, Object?>> get onWatchPosition =>
      _watchPositionController.stream;

  // ---------------------------------------------------------------------------
  // Emit methods
  // ---------------------------------------------------------------------------

  /// Documentation for emitLocation.
  void emitLocation(Map<String, Object?> location) {
    if (!_locationController.isClosed) _locationController.add(location);
  }

  /// Documentation for emitMotionChange.
  void emitMotionChange(Map<String, Object?> location) {
    if (!_motionChangeController.isClosed) {
      _motionChangeController.add(location);
    }
  }

  /// Documentation for emitActivityChange.
  void emitActivityChange(Map<String, Object?> event) {
    if (!_activityChangeController.isClosed) {
      _activityChangeController.add(event);
    }
  }

  /// Documentation for emitProviderChange.
  void emitProviderChange(Map<String, Object?> event) {
    if (!_providerChangeController.isClosed) {
      _providerChangeController.add(event);
    }
  }

  /// Documentation for emitGeofence.
  void emitGeofence(Map<String, Object?> event) {
    if (!_geofenceController.isClosed) _geofenceController.add(event);
  }

  /// Documentation for emitGeofencesChange.
  void emitGeofencesChange(Map<String, Object?> event) {
    if (!_geofencesChangeController.isClosed) {
      _geofencesChangeController.add(event);
    }
  }

  /// Documentation for emitHeartbeat.
  void emitHeartbeat(Map<String, Object?> location) {
    if (!_heartbeatController.isClosed) {
      _heartbeatController.add(<String, Object?>{'location': location});
    }
  }

  /// Documentation for emitHttp.
  void emitHttp(Map<String, Object?> event) {
    if (!_httpController.isClosed) _httpController.add(event);
  }

  /// Documentation for emitSchedule.
  void emitSchedule(Map<String, Object?> state) {
    if (!_scheduleController.isClosed) _scheduleController.add(state);
  }

  /// Documentation for emitConnectivityChange.
  void emitConnectivityChange(bool connected) {
    if (!_connectivityChangeController.isClosed) {
      _connectivityChangeController.add(<String, Object?>{
        'connected': connected,
      });
    }
  }

  /// Documentation for emitEnabledChange.
  void emitEnabledChange(bool enabled) {
    if (!_enabledChangeController.isClosed) {
      _enabledChangeController.add(enabled);
    }
  }

  /// Documentation for emitAuthorization.
  void emitAuthorization(Map<String, Object?> event) {
    if (!_authorizationController.isClosed) _authorizationController.add(event);
  }

  /// Documentation for emitWatchPosition.
  void emitWatchPosition(Map<String, Object?> location) {
    if (!_watchPositionController.isClosed) {
      _watchPositionController.add(location);
    }
  }

  // ---------------------------------------------------------------------------
  // Logging
  // ---------------------------------------------------------------------------

  /// Logs a message at the given level.
  ///
  /// This is a lightweight pass-through for sub-engines that don't have direct
  /// access to `WebStorageEngine`. Actual log persistence is handled by the
  /// storage engine via `TraceletWebPlugin.log()`.
  void log(String level, String message) {
    // Output to browser console for diagnostics.
    // ignore: avoid_print
    print('[$level] $message');
  }

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  /// Documentation for dispose.
  void dispose() {
    _locationController.close();
    _motionChangeController.close();
    _activityChangeController.close();
    _providerChangeController.close();
    _geofenceController.close();
    _geofencesChangeController.close();
    _heartbeatController.close();
    _httpController.close();
    _scheduleController.close();
    _powerSaveChangeController.close();
    _connectivityChangeController.close();
    _enabledChangeController.close();
    _notificationActionController.close();
    _authorizationController.close();
    _watchPositionController.close();
  }
}
