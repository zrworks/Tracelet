import 'package:flutter_test/flutter_test.dart';
import 'package:tracelet_sync/tracelet_sync.dart';
import 'package:tracelet_sync/tracelet_sync_platform_interface.dart';
import 'package:tracelet_sync/tracelet_sync_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockTraceletSyncPlatform
    with MockPlatformInterfaceMixin
    implements TraceletSyncPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final TraceletSyncPlatform initialPlatform = TraceletSyncPlatform.instance;

  test('$MethodChannelTraceletSync is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelTraceletSync>());
  });

  test('getPlatformVersion', () async {
    TraceletSync traceletSyncPlugin = TraceletSync();
    MockTraceletSyncPlatform fakePlatform = MockTraceletSyncPlatform();
    TraceletSyncPlatform.instance = fakePlatform;

    expect(await traceletSyncPlugin.getPlatformVersion(), '42');
  });
}
