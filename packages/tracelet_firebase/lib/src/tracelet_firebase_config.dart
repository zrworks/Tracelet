import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tracelet/tracelet.dart';

/// Adapter to seamlessly integrate Tracelet's native HTTP sync engine with Firebase Realtime Database.
class TraceletFirebase {
  /// Builds a Tracelet [HttpConfig] configured for your Firebase Realtime Database.
  ///
  /// Provide your RTDB [databaseUrl] (e.g. 'https://my-project-default-rtdb.firebaseio.com')
  /// and the [path] where locations should be stored (e.g. 'locations/user123').
  ///
  /// Example:
  /// ```dart
  /// final httpConfig = await TraceletFirebase.buildHttpConfig(
  ///   databaseUrl: 'https://xyz.firebaseio.com',
  ///   path: 'locations/user_123',
  /// );
  ///
  /// await Tracelet.ready(Config(
  ///   geo: GeoConfig(distanceFilter: 50),
  ///   http: httpConfig,
  /// ));
  /// ```
  static Future<HttpConfig> buildHttpConfig({
    required String databaseUrl,
    required String path,
    bool autoSync = true,
    bool batchSync = true,
    int maxBatchSize = 250,
  }) async {
    // Strip trailing slashes from the URL and leading/trailing slashes from the path
    final cleanUrl = databaseUrl.replaceAll(RegExp(r'/$'), '');
    final cleanPath = path.replaceAll(RegExp(r'^/|/$'), '');

    // The .json extension is strictly required for the Firebase RTDB REST API
    final url = '$cleanUrl/$cleanPath.json';

    final user = FirebaseAuth.instance.currentUser;
    final token = user != null ? await user.getIdToken() : null;

    final headers = <String, String>{};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return HttpConfig(
      url: url,
      method: HttpMethod.post, // POST adds data to a list in RTDB
      autoSync: autoSync,
      batchSync: batchSync,
      maxBatchSize: maxBatchSize,
      headers: headers,
    );
  }

  /// Automatically wires up Tracelet to refresh your Firebase auth token
  /// in the background whenever it expires (resolving 401 Unauthorized errors).
  ///
  /// Call this once during your app initialization, before `Tracelet.start()`.
  ///
  /// ```dart
  /// await TraceletFirebase.configureTokenRefresh();
  /// ```
  static Future<void> configureTokenRefresh() async {
    // 1. Foreground token refresh
    Tracelet.setTokenRefreshCallback(() async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {};

      // Force refresh the token
      final token = await user.getIdToken(true);
      if (token == null) return {};

      return {'Authorization': 'Bearer $token'};
    });

    // 2. Headless token refresh (when app is terminated)
    await Tracelet.registerHeadlessHeadersCallback(_headlessTokenRefresh);
  }
}

/// Called by Tracelet's native HTTP engine in a background isolate when a 401 error occurs
/// and the main app is terminated.
@pragma('vm:entry-point')
void _headlessTokenRefresh(HeadlessEvent event) async {
  try {
    // Initialize Firebase in the background isolate if it hasn't been already
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await user.getIdToken(true);
      if (token != null) {
        await Tracelet.setDynamicHeaders({'Authorization': 'Bearer $token'});
      }
    }
  } catch (e) {
    Tracelet.log(
      'error',
      '[TraceletFirebase] Headless token refresh failed: $e',
    );
  }
}
