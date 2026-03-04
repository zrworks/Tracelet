// ignore_for_file: avoid_print

/// Web implementation of the Tracelet background geolocation plugin.
///
/// This package is auto-registered by the Flutter plugin system — you don't
/// need to use it directly. See the
/// [tracelet](https://pub.dev/packages/tracelet) package for the app-facing
/// API.
///
/// ```dart
/// import 'package:tracelet/tracelet.dart' as tl;
///
/// Future<void> main() async {
///   tl.Tracelet.onLocation((location) {
///     print('${location.coords.latitude}, ${location.coords.longitude}');
///   });
///
///   await tl.Tracelet.ready(tl.Config(
///     geo: tl.GeoConfig(desiredAccuracy: tl.DesiredAccuracy.high),
///   ));
///
///   await tl.Tracelet.start();
/// }
/// ```
void main() {
  print('Use the tracelet package — this plugin registers automatically.');
}
