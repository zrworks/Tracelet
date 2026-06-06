import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:meta/meta.dart';
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
  /// await Tracelet.ready(Config.balanced(overrides: {
  ///   'http': httpConfig.toMap(),
  /// }));
  /// ```
  static Future<HttpConfig> buildHttpConfig({
    required String databaseUrl,
    required String path,
    bool autoSync = true,
    bool batchSync = true,
    int maxBatchSize = 250,
    FirebaseAuth? auth,
  }) async {
    // Strip trailing slashes from the URL and leading/trailing slashes from the path
    final cleanUrl = databaseUrl.replaceAll(RegExp(r'/$'), '');
    final cleanPath = path.replaceAll(RegExp(r'^/|/$'), '');

    final authInstance = auth ?? FirebaseAuth.instance;
    final user = authInstance.currentUser;
    final token = user != null ? await user.getIdToken() : null;

    // The .json extension is strictly required for the Firebase RTDB REST API
    // Firebase RTDB requires the client ID token as a query parameter (?auth=), NOT a Bearer header.
    var url = '$cleanUrl/$cleanPath.json';
    if (token != null) {
      url += '?auth=$token';
    }

    return HttpConfig(
      url: url,
      autoSync: autoSync,
      batchSync: batchSync,
      maxBatchSize: maxBatchSize,
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
  static Future<void> configureTokenRefresh({FirebaseAuth? auth}) async {
    // 1. Foreground token refresh
    Tracelet.setTokenRefreshCallback(() async {
      await refreshAndUpdateConfig(auth: auth);
      return {};
    });

    // 2. Headless token refresh (when app is terminated)
    await Tracelet.registerHeadlessHeadersCallback(_headlessTokenRefresh);
  }

  /// Refreshes the Firebase ID token and updates the Tracelet config with the new token.
  @visibleForTesting
  static Future<void> refreshAndUpdateConfig({FirebaseAuth? auth}) async {
    final authInstance = auth ?? FirebaseAuth.instance;
    final user = authInstance.currentUser;
    if (user == null) return;

    final token = await user.getIdToken(true);
    if (token == null) return;

    final currentConfig = Tracelet.activeConfig;
    final currentUrl = currentConfig.http.url;
    if (currentUrl == null) return;

    final baseUrl = currentUrl.split('?auth=').first;
    final newUrl = '$baseUrl?auth=$token';

    final updatedHttp = HttpConfig.fromMap({
      ...currentConfig.http.toMap(),
      'url': newUrl,
    });

    final updatedConfig = Config.fromMap({
      ...currentConfig.toMap(),
      'http': updatedHttp.toMap(),
    });

    await Tracelet.setConfig(updatedConfig);
  }
}

/// Called by Tracelet's native HTTP engine in a background isolate when a 401 error occurs
/// and the main app is terminated.
@pragma('vm:entry-point')
Future<void> _headlessTokenRefresh(HeadlessEvent event) async {
  try {
    // Initialize Firebase in the background isolate if it hasn't been already
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    await TraceletFirebase.refreshAndUpdateConfig();
  } catch (e) {
    Tracelet.log(
      'error',
      '[TraceletFirebase] Headless token refresh failed: $e',
    );
  }
}
