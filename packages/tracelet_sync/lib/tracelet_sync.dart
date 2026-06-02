import 'package:flutter/services.dart';

class TraceletSync {
  static const MethodChannel _channel = MethodChannel('tracelet_sync');

  /// Initializes the Tracelet Sync Engine natively.
  /// This registers the sync logic as a LocationDataSink within the core LocationEngine.
  static Future<void> initialize() async {
    await _channel.invokeMethod('initialize');
  }
}
