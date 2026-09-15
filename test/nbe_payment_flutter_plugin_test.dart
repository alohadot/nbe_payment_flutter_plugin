import 'package:flutter_test/flutter_test.dart';
import 'package:nbe_payment_flutter_plugin/nbe_payment_flutter_plugin.dart';
import 'package:nbe_payment_flutter_plugin/nbe_payment_flutter_plugin_platform_interface.dart';
import 'package:nbe_payment_flutter_plugin/nbe_payment_flutter_plugin_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockNbePaymentFlutterPluginPlatform
    with MockPlatformInterfaceMixin
    implements NbePaymentFlutterPluginPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final NbePaymentFlutterPluginPlatform initialPlatform =
      NbePaymentFlutterPluginPlatform.instance;

  test('$MethodChannelNbePaymentFlutterPlugin is the default instance', () {
    expect(
      initialPlatform,
      isInstanceOf<MethodChannelNbePaymentFlutterPlugin>(),
    );
  });

  test('getPlatformVersion', () async {
    NbePaymentFlutterPlugin nbePaymentFlutterPlugin = NbePaymentFlutterPlugin();
    MockNbePaymentFlutterPluginPlatform fakePlatform =
        MockNbePaymentFlutterPluginPlatform();
    NbePaymentFlutterPluginPlatform.instance = fakePlatform;

    expect(await nbePaymentFlutterPlugin.getPlatformVersion(), '42');
  });
}
