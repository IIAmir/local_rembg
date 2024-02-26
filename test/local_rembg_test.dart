import 'package:flutter_test/flutter_test.dart';
import 'package:local_rembg/local_rembg.dart';
import 'package:local_rembg/local_rembg_platform_interface.dart';
import 'package:local_rembg/local_rembg_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockLocalRembgPlatform
    with MockPlatformInterfaceMixin
    implements LocalRembgPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final LocalRembgPlatform initialPlatform = LocalRembgPlatform.instance;

  test('$MethodChannelLocalRembg is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelLocalRembg>());
  });

  test('getPlatformVersion', () async {
    LocalRembg localRembgPlugin = LocalRembg();
    MockLocalRembgPlatform fakePlatform = MockLocalRembgPlatform();
    LocalRembgPlatform.instance = fakePlatform;

    expect(await localRembgPlugin.getPlatformVersion(), '42');
  });
}
