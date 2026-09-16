/// Versions bundled in this release of the plugin.
///
/// Kept in sync with pubspec.yaml and the bundled native SDKs by
/// test/api/nbe_payment_versions_test.dart.
abstract final class NbePaymentVersions {
  /// Version of this plugin, as in pubspec.yaml.
  static const String plugin = '0.1.1';

  /// Mastercard Gateway Android SDK bundled in `android/gateway-repo`.
  static const String androidGatewaySdk = '2.0.17';

  /// Mastercard Gateway iOS SDK bundled in `ios/Frameworks`.
  static const String iosGatewaySdk = '2.0.14';
}
