import 'dart:ui' show Color, Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:nbe_payment_flutter_plugin/src/generated/payment_api.g.dart';
import 'package:nbe_payment_flutter_plugin/src/mappers/configuration_mapper.dart';
import 'package:nbe_payment_flutter_plugin/src/models/challenge_ui_customization.dart';
import 'package:nbe_payment_flutter_plugin/src/models/gateway_configuration.dart';

void main() {
  test('maps merchant data, region and locale', () {
    const configuration = GatewayConfiguration(
      merchantId: 'TESTNBE000123',
      merchantName: 'My Store',
      merchantUrl: 'https://mystore.example',
      region: GatewayRegion.mtf,
      challengeLocale: Locale('ar', 'EG'),
    );

    final message = toInitializeRequestMessage(configuration);

    expect(message.merchantId, 'TESTNBE000123');
    expect(message.merchantName, 'My Store');
    expect(message.merchantUrl, 'https://mystore.example');
    expect(message.region, GatewayRegion.mtf);
    expect(message.challengeLocale, 'ar-EG');
    expect(message.challengeUi, isNull);
  });

  test('maps challenge customization with colors as ARGB integers', () {
    const configuration = GatewayConfiguration(
      merchantId: 'id',
      merchantName: 'name',
      merchantUrl: 'https://example.com',
      region: GatewayRegion.europe,
      challengeUi: ChallengeUiCustomization(
        toolbar: ChallengeToolbarStyle(
          backgroundColor: Color(0xFF006A4E),
          textColor: Color(0xFFFFFFFF),
          fontSize: 18,
          title: 'Secure Payment',
          cancelText: 'Cancel',
        ),
        button: ChallengeButtonStyle(cornerRadius: 8),
        label: ChallengeLabelStyle(headingTextColor: Color(0x80112233)),
        textBox: ChallengeTextBoxStyle(borderWidth: 1),
        regularFontName: 'Cairo-Regular',
        headingFontName: 'Cairo-Bold',
        android: AndroidChallengeCustomization(
          buttonStyles: {
            ChallengeButtonType.resend: ChallengeButtonStyle(
              backgroundColor: Color(0xFFAA0000),
            ),
          },
        ),
        ios: IosChallengeCustomization(
          primaryBackgroundColor: Color(0xFF000000),
          keyboardAppearance: ChallengeKeyboardAppearance.dark,
          appearance: ChallengeAppearance.dark,
        ),
      ),
    );

    final ui = toInitializeRequestMessage(configuration).challengeUi!;

    expect(ui.toolbar!.backgroundColor, 0xFF006A4E);
    expect(ui.toolbar!.textColor, 0xFFFFFFFF);
    expect(ui.toolbar!.fontSize, 18);
    expect(ui.toolbar!.title, 'Secure Payment');
    expect(ui.toolbar!.cancelText, 'Cancel');
    expect(ui.button!.cornerRadius, 8);
    expect(ui.button!.backgroundColor, isNull);
    expect(ui.label!.headingTextColor, 0x80112233);
    expect(ui.textBox!.borderWidth, 1);
    expect(ui.regularFontName, 'Cairo-Regular');
    expect(ui.headingFontName, 'Cairo-Bold');

    expect(ui.androidButtonStyles, hasLength(1));
    expect(ui.androidButtonStyles!.single.type, ChallengeButtonType.resend);
    expect(ui.androidButtonStyles!.single.style.backgroundColor, 0xFFAA0000);

    expect(ui.ios!.primaryBackgroundColor, 0xFF000000);
    expect(ui.ios!.secondaryBackgroundColor, isNull);
    expect(ui.ios!.keyboardAppearance, ChallengeKeyboardAppearance.dark);
    expect(ui.ios!.appearance, ChallengeAppearance.dark);
  });

  test('omits platform sections that were not provided', () {
    const configuration = GatewayConfiguration(
      merchantId: 'id',
      merchantName: 'name',
      merchantUrl: 'https://example.com',
      region: GatewayRegion.europe,
      challengeUi: ChallengeUiCustomization(),
    );

    final ui = toInitializeRequestMessage(configuration).challengeUi!;

    expect(ui.toolbar, isNull);
    expect(ui.androidButtonStyles, isNull);
    expect(ui.ios, isNull);
  });
}
