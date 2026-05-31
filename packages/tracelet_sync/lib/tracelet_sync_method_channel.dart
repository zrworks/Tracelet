import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'tracelet_sync_platform_interface.dart';

/// An implementation of [TraceletSyncPlatform] that uses method channels.
class MethodChannelTraceletSync extends TraceletSyncPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('tracelet_sync');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
