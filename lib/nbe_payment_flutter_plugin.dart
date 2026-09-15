
import 'nbe_payment_flutter_plugin_platform_interface.dart';

class NbePaymentFlutterPlugin {
  Future<String?> getPlatformVersion() {
    return NbePaymentFlutterPluginPlatform.instance.getPlatformVersion();
  }
}
