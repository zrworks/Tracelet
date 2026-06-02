import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'tracelet_sync_method_channel.dart';

abstract class TraceletSyncPlatform extends PlatformInterface {
  /// Constructs a TraceletSyncPlatform.
  TraceletSyncPlatform() : super(token: _token);

  static final Object _token = Object();

  static TraceletSyncPlatform _instance = MethodChannelTraceletSync();

  /// The default instance of [TraceletSyncPlatform] to use.
  ///
  /// Defaults to [MethodChannelTraceletSync].
  static TraceletSyncPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [TraceletSyncPlatform] when
  /// they register themselves.
  static set instance(TraceletSyncPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
