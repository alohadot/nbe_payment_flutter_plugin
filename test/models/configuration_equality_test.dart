import 'dart:ui' show Color, Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:nbe_payment_flutter_plugin/nbe_payment_flutter_plugin.dart';

GatewayConfiguration _configuration({
  Color toolbarColor = const Color(0xFF006A4E),
  ChallengeButtonStyle resendStyle = const ChallengeButtonStyle(
    cornerRadius: 4,
  ),
  String? applePayMerchantIdentifier = 'merchant.com.example',
}) => GatewayConfiguration(
  merchantId: 'TESTNBE000123',
  merchantName: 'My Store',
  merchantUrl: 'https://mystore.example',
  region: GatewayRegion.mtf,
  challengeLocale: const Locale('ar'),
  challengeUi: ChallengeUiCustomization(
    toolbar: ChallengeToolbarStyle(backgroundColor: toolbarColor),
    android: AndroidChallengeCustomization(
      buttonStyles: {ChallengeButtonType.resend: resendStyle},
    ),
    ios: const IosChallengeCustomization(appearance: ChallengeAppearance.dark),
  ),
  wallet: WalletConfiguration(
    applePayMerchantIdentifier: applePayMerchantIdentifier,
  ),
);

void main() {
  test('configurations built separately with the same values are equal', () {
    expect(_configuration(), _configuration());
    expect(_configuration().hashCode, _configuration().hashCode);
  });

  test('a difference deep in the challenge customization breaks equality', () {
    expect(
      _configuration(),
      isNot(_configuration(toolbarColor: const Color(0xFF000000))),
    );
    expect(
      _configuration(),
      isNot(
        _configuration(
          resendStyle: const ChallengeButtonStyle(cornerRadius: 8),
        ),
      ),
    );
  });

  test('a difference in wallet configuration breaks equality', () {
    expect(
      _configuration(),
      isNot(_configuration(applePayMerchantIdentifier: null)),
    );
  });
}
