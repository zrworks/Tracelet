import 'dart:async';
import 'dart:js_interop';

import 'package:tracelet_platform_interface/tracelet_platform_interface.dart'
    show AuthorizationStatus;
import 'package:tracelet_web/src/web_event_dispatcher.dart';
import 'package:web/web.dart' as web;

// ignore: unused_import — needed for jsify extension

/// Permissions and connectivity engine for Tracelet web.
///
/// Uses `navigator.permissions` API for querying geolocation permission,
/// `Notification.permission` for notification permission, and
/// `navigator.onLine` + events for connectivity tracking.
class WebPermissionsEngine {
  /// Initializes the web permissions engine.
  WebPermissionsEngine(this._events);

  final WebEventDispatcher _events;

  /// Subscription to online/offline events.
  bool _connectivityListening = false;

  /// Cached JS wrappers for event listeners — `.toJS` must return the same
  /// object for both `addEventListener` and `removeEventListener` (D-H6).
  late final _onOnlineJS = _onOnline.toJS;
  late final _onOfflineJS = _onOffline.toJS;

  /// Start listening for connectivity changes.
  void startConnectivityMonitoring() {
    if (_connectivityListening) return;
    _connectivityListening = true;

    web.window.addEventListener('online', _onOnlineJS);
    web.window.addEventListener('offline', _onOfflineJS);
  }

  void _onOnline(web.Event event) {
    _events.emitConnectivityChange(true);
  }

  void _onOffline(web.Event event) {
    _events.emitConnectivityChange(false);
  }

  /// Stop listening for connectivity changes.
  void stopConnectivityMonitoring() {
    if (!_connectivityListening) return;
    _connectivityListening = false;

    web.window.removeEventListener('online', _onOnlineJS);
    web.window.removeEventListener('offline', _onOfflineJS);
  }

  // ---------------------------------------------------------------------------
  // Location permission
  // ---------------------------------------------------------------------------

  /// Query geolocation permission status.
  ///
  /// Returns [AuthorizationStatus] index:
  /// - 0 = notDetermined (prompt)
  /// - 2 = whenInUse (granted — web has no "always" distinction)
  /// - 4 = deniedForever (denied)
  Future<int> getPermissionStatus() async {
    try {
      final descriptor =
          <String, String>{'name': 'geolocation'}.jsify()! as JSObject;
      final status = await web.window.navigator.permissions
          .query(descriptor)
          .toDart
          .timeout(const Duration(seconds: 2));
      return _mapPermissionState(status.state);
    } catch (_) {
      // Permissions API not supported or timed out (Safari bug) — assume prompt.
      return 0; // notDetermined
    }
  }

  /// Request location permission.
  ///
  /// On web, the browser prompts implicitly when `getCurrentPosition` is
  /// called. We trigger a one-shot position request to force the prompt.
  Future<int> requestPermission() async {
    final completer = Completer<int>();

    try {
      _events.log(
        'debug',
        '[Tracelet Web] Requesting geolocation permission via getCurrentPosition...',
      );
      web.window.navigator.geolocation.getCurrentPosition(
        (web.GeolocationPosition pos) {
          _events.log(
            'debug',
            '[Tracelet Web] getCurrentPosition success callback fired',
          );
          if (!completer.isCompleted) completer.complete(2); // whenInUse
        }.toJS,
        (web.GeolocationPositionError err) {
          _events.log(
            'debug',
            '[Tracelet Web] getCurrentPosition error callback fired: code=${err.code}, message=${err.message}',
          );
          if (err.code == 1) {
            // PERMISSION_DENIED
            if (!completer.isCompleted) completer.complete(4); // deniedForever
          } else {
            // Other error (position unavailable, timeout)
            if (!completer.isCompleted) completer.complete(0); // notDetermined
          }
        }.toJS,
        web.PositionOptions(timeout: 15000), // Enforce browser timeout
      );
    } catch (e) {
      _events.log(
        'error',
        '[Tracelet Web] requestPermission synchronous error: $e',
      );
      if (!completer.isCompleted) completer.complete(4); // deniedForever
    }

    // Add a Dart-side timeout to prevent indefinite hangs if the browser
    // silently ignores the request (e.g., due to lost user gesture or iframe policy).
    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        _events.log(
          'error',
          '[Tracelet Web] requestPermission timed out without browser response.',
        );
        if (!completer.isCompleted) completer.complete(0); // notDetermined
        return 0;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Notification permission
  // ---------------------------------------------------------------------------

  /// Queries the current notification permission status.
  Future<int> getNotificationPermissionStatus() async {
    try {
      final permission = web.Notification.permission;
      switch (permission) {
        case 'granted':
          return 3; // always
        case 'denied':
          return 4; // deniedForever
        default:
          return 0; // notDetermined
      }
    } catch (_) {
      return 3; // Notifications API not available — return granted.
    }
  }

  /// Requests permission to display notifications.
  Future<int> requestNotificationPermission() async {
    try {
      final result = await web.Notification.requestPermission().toDart;
      switch (result) {
        case 'granted':
          return 3; // always
        case 'denied':
          return 4; // deniedForever
        default:
          return 0; // notDetermined
      }
    } catch (_) {
      return 3; // Notifications API not available.
    }
  }

  // ---------------------------------------------------------------------------
  // Motion permission (stub — no web equivalent for most browsers)
  // ---------------------------------------------------------------------------

  /// Queries the motion permission status (stub for Web).
  Future<int> getMotionPermissionStatus() async => 3; // always (granted)

  /// Requests motion permission (stub for Web).
  Future<int> requestMotionPermission() async => 3; // always (granted)

  // ---------------------------------------------------------------------------
  // Provider state
  // ---------------------------------------------------------------------------

  /// Gets the current state of location providers and permissions.
  Future<Map<String, Object?>> getProviderState() async {
    final permStatus = await getPermissionStatus();
    final isOnline = web.window.navigator.onLine;

    return <String, Object?>{
      'enabled': true, // Browser always has geolocation capability
      'status': permStatus,
      'gps': true, // Browser abstracts this
      'network': isOnline,
      'accuracyAuthorization': 0, // full
    };
  }

  // ---------------------------------------------------------------------------
  // Device info
  // ---------------------------------------------------------------------------

  /// Retrieves device and browser information.
  Map<String, Object?> getDeviceInfo() {
    final ua = web.window.navigator.userAgent;
    final platform = web.window.navigator.platform;

    return <String, Object?>{
      'model': _parseBrowserName(ua),
      'manufacturer': 'Web',
      'version': _parseBrowserVersion(ua),
      'platform': platform,
      'framework': 'Flutter Web',
    };
  }

  // ---------------------------------------------------------------------------
  // Sensors
  // ---------------------------------------------------------------------------

  /// Retrieves available device sensors.
  Map<String, Object?> getSensors() {
    return <String, Object?>{
      'platform': 'web',
      'accelerometer': false, // Could detect via Generic Sensor API
      'gyroscope': false,
      'magnetometer': false,
      'significantMotion': false,
    };
  }

  // ---------------------------------------------------------------------------
  // Connectivity
  // ---------------------------------------------------------------------------

  /// Whether the device currently has an active network connection.
  bool get isConnected => web.window.navigator.onLine;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  int _mapPermissionState(String state) {
    switch (state) {
      case 'granted':
        return 2; // whenInUse
      case 'denied':
        return 4; // deniedForever
      case 'prompt':
      default:
        return 0; // notDetermined
    }
  }

  static String _parseBrowserName(String ua) {
    if (ua.contains('Chrome') && !ua.contains('Edg')) return 'Chrome';
    if (ua.contains('Edg')) return 'Edge';
    if (ua.contains('Firefox')) return 'Firefox';
    if (ua.contains('Safari') && !ua.contains('Chrome')) return 'Safari';
    if (ua.contains('Opera') || ua.contains('OPR')) return 'Opera';
    return 'Unknown Browser';
  }

  /// Pre-compiled browser version patterns — avoids recompiling on every call (D-M5).
  static final List<RegExp> _browserVersionPatterns = [
    RegExp(r'Chrome/(\d+[\.\d]*)'),
    RegExp(r'Firefox/(\d+[\.\d]*)'),
    RegExp(r'Safari/(\d+[\.\d]*)'),
    RegExp(r'Edg/(\d+[\.\d]*)'),
    RegExp(r'OPR/(\d+[\.\d]*)'),
  ];

  static String _parseBrowserVersion(String ua) {
    final patterns = _browserVersionPatterns;
    for (final p in patterns) {
      final match = p.firstMatch(ua);
      if (match != null) return match.group(1) ?? '';
    }
    return '';
  }

  /// Cleans up resources.
  void dispose() {
    stopConnectivityMonitoring();
  }
}
