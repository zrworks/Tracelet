import 'package:supabase_flutter/supabase_flutter.dart' hide HttpMethod;
import 'package:tracelet/tracelet.dart';

/// Adapter to seamlessly integrate Tracelet's native HTTP sync engine with Supabase.
class TraceletSupabase {
  /// Builds a Tracelet [HttpConfig] fully configured for your Supabase project.
  ///
  /// You must provide exactly one target: either an [rpcFunction] or an [edgeFunction].
  /// You must also provide your [supabaseUrl] and [anonKey].
  ///
  /// Example:
  /// ```dart
  /// final httpConfig = TraceletSupabase.buildHttpConfig(
  ///   supabaseUrl: 'https://xyz.supabase.co',
  ///   anonKey: 'your_anon_key',
  ///   rpcFunction: 'insert_tracelet_locations',
  /// );
  ///
  /// await Tracelet.ready(Config(
  ///   geo: GeoConfig(distanceFilter: 50),
  ///   http: httpConfig,
  /// ));
  /// ```
  static HttpConfig buildHttpConfig({
    required String supabaseUrl,
    required String anonKey,
    String? rpcFunction,
    String? edgeFunction,
    bool autoSync = true,
    bool batchSync = true,
    int maxBatchSize = 250,
  }) {
    assert(
      (rpcFunction != null) ^ (edgeFunction != null),
      'You must provide either an rpcFunction OR an edgeFunction, but not both.',
    );

    final String url;
    if (rpcFunction != null) {
      url = '$supabaseUrl/rest/v1/rpc/$rpcFunction';
    } else {
      url = '$supabaseUrl/functions/v1/$edgeFunction';
    }

    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    final token = session?.accessToken ?? anonKey;

    return HttpConfig(
      url: url,
      method: HttpMethod.post,
      autoSync: autoSync,
      batchSync: batchSync,
      maxBatchSize: maxBatchSize,
      headers: {
        'apikey': anonKey,
        'Authorization': 'Bearer $token',
        'Prefer': 'return=minimal',
      },
    );
  }

  /// Automatically wires up Tracelet to refresh your Supabase auth token
  /// in the background whenever it expires (resolving 401 Unauthorized errors).
  ///
  /// Call this once during your app initialization, before `Tracelet.start()`.
  ///
  /// ```dart
  /// await TraceletSupabase.configureTokenRefresh(anonKey: 'your_anon_key');
  /// ```
  static Future<void> configureTokenRefresh({required String anonKey}) async {
    // 1. Foreground token refresh
    Tracelet.setTokenRefreshCallback(() async {
      final client = Supabase.instance.client;
      await client.auth.refreshSession();
      final token = client.auth.currentSession?.accessToken ?? anonKey;
      return {'Authorization': 'Bearer $token'};
    });

    // 2. Headless token refresh (when app is terminated)
    // We cannot pass anonKey easily to a static headless callback unless we persist it.
    // However, the developer can just read it from their env.dart or dotenv.
    await Tracelet.registerHeadlessHeadersCallback(_headlessTokenRefresh);
  }
}

/// Called by Tracelet's native HTTP engine in a background isolate when a 401 error occurs
/// and the main app is terminated.
@pragma('vm:entry-point')
void _headlessTokenRefresh(HeadlessEvent event) async {
  try {
    final client = Supabase.instance.client;
    await client.auth.refreshSession();
    // In a truly headless environment without anonKey passed in, we just hope accessToken is fresh
    final token = client.auth.currentSession?.accessToken;
    if (token != null) {
      await Tracelet.setDynamicHeaders({'Authorization': 'Bearer $token'});
    }
  } catch (e) {
    Tracelet.log(
      'error',
      '[TraceletSupabase] Headless token refresh failed: $e',
    );
  }
}
