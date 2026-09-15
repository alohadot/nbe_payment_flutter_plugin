import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nbe_payment_flutter_plugin/nbe_payment_flutter_plugin_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelNbePaymentFlutterPlugin platform = MethodChannelNbePaymentFlutterPlugin();
  const MethodChannel channel = MethodChannel('nbe_payment_flutter_plugin');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return '42';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
