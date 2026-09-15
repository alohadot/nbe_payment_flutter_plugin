import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'nbe_payment_flutter_plugin_platform_interface.dart';

/// An implementation of [NbePaymentFlutterPluginPlatform] that uses method channels.
class MethodChannelNbePaymentFlutterPlugin extends NbePaymentFlutterPluginPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('nbe_payment_flutter_plugin');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
