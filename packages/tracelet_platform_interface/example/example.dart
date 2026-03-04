// ignore_for_file: avoid_print

import 'package:tracelet_platform_interface/tracelet_platform_interface.dart';

/// Example showing how platform implementations extend [TraceletPlatform].
///
/// This package is not intended for direct use — it provides the abstract
/// interface that platform-specific packages (tracelet_android, tracelet_ios,
/// tracelet_web) implement. See the [tracelet](https://pub.dev/packages/tracelet)
/// package for the app-facing API.
void main() {
  // Access the current platform implementation singleton.
  final platform = TraceletPlatform.instance;
  print('Platform implementation: ${platform.runtimeType}');
}
