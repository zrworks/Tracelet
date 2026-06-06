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

  /// Stream of continuous location updates.
  Stream<Map<String, Object?>> get onLocation => _locationController.stream;

  /// Stream of device motion state changes.
  Stream<Map<String, Object?>> get onMotionChange =>
      _motionChangeController.stream;

  /// Stream of activity recognition changes.
  Stream<Map<String, Object?>> get onActivityChange =>
      _activityChangeController.stream;

  /// Stream of location provider state changes.
  Stream<Map<String, Object?>> get onProviderChange =>
      _providerChangeController.stream;

  /// Stream of geofence transition events.
  Stream<Map<String, Object?>> get onGeofence => _geofenceController.stream;

  /// Stream of changes to registered geofences.
  Stream<Map<String, Object?>> get onGeofencesChange =>
      _geofencesChangeController.stream;

  /// Stream of heartbeat events.
  Stream<Map<String, Object?>> get onHeartbeat => _heartbeatController.stream;

  /// Stream of HTTP sync events.
  Stream<Map<String, Object?>> get onHttp => _httpController.stream;

  /// Stream of schedule state changes.
  Stream<Map<String, Object?>> get onSchedule => _scheduleController.stream;

  /// Stream of power save mode changes.
  Stream<bool> get onPowerSaveChange => _powerSaveChangeController.stream;

  /// Stream of network connectivity changes.
  Stream<Map<String, Object?>> get onConnectivityChange =>
      _connectivityChangeController.stream;

  /// Stream of plugin enabled state changes.
  Stream<bool> get onEnabledChange => _enabledChangeController.stream;

  /// Stream of notification action button clicks.
  Stream<String> get onNotificationAction =>
      _notificationActionController.stream;

  /// Stream of authorization events.
  Stream<Map<String, Object?>> get onAuthorization =>
      _authorizationController.stream;

  /// Stream of continuous location updates requested via watchPosition.
  Stream<Map<String, Object?>> get onWatchPosition =>
      _watchPositionController.stream;

  // ---------------------------------------------------------------------------
  // Emit methods
  // ---------------------------------------------------------------------------

  /// Broadcasts a location update.
  void emitLocation(Map<String, Object?> location) {
    if (!_locationController.isClosed) _locationController.add(location);
  }

  /// Broadcasts a motion state change.
  void emitMotionChange(Map<String, Object?> location) {
    if (!_motionChangeController.isClosed) {
      _motionChangeController.add(location);
    }
  }

  /// Broadcasts an activity change.
  void emitActivityChange(Map<String, Object?> event) {
    if (!_activityChangeController.isClosed) {
      _activityChangeController.add(event);
    }
  }

  /// Broadcasts a provider state change.
  void emitProviderChange(Map<String, Object?> event) {
    if (!_providerChangeController.isClosed) {
      _providerChangeController.add(event);
    }
  }

  /// Broadcasts a geofence transition.
  void emitGeofence(Map<String, Object?> event) {
    if (!_geofenceController.isClosed) _geofenceController.add(event);
  }

  /// Broadcasts a geofence registration change.
  void emitGeofencesChange(Map<String, Object?> event) {
    if (!_geofencesChangeController.isClosed) {
      _geofencesChangeController.add(event);
    }
  }

  /// Broadcasts a heartbeat event.
  void emitHeartbeat(Map<String, Object?> location) {
    if (!_heartbeatController.isClosed) {
      _heartbeatController.add(<String, Object?>{'location': location});
    }
  }

  /// Broadcasts an HTTP sync event.
  void emitHttp(Map<String, Object?> event) {
    if (!_httpController.isClosed) _httpController.add(event);
  }

  /// Broadcasts a schedule state change.
  void emitSchedule(Map<String, Object?> state) {
    if (!_scheduleController.isClosed) _scheduleController.add(state);
  }

  /// Broadcasts a connectivity change.
  void emitConnectivityChange(bool connected) {
    if (!_connectivityChangeController.isClosed) {
      _connectivityChangeController.add(<String, Object?>{
        'connected': connected,
      });
    }
  }

  /// Broadcasts an enabled state change.
  void emitEnabledChange(bool enabled) {
    if (!_enabledChangeController.isClosed) {
      _enabledChangeController.add(enabled);
    }
  }

  /// Broadcasts an authorization event.
  void emitAuthorization(Map<String, Object?> event) {
    if (!_authorizationController.isClosed) _authorizationController.add(event);
  }

  /// Broadcasts a watchPosition location update.
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

  /// Closes all active event streams.
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
