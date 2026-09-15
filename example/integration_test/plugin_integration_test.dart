// Runs inside the example app on a real device or emulator, against the real native SDK.
// Nothing here is faked.
//
// Run with:
//   cd example
//   flutter test integration_test/plugin_integration_test.dart -d <device-id>
//
// Only operations implemented natively so far are covered; tests are added as each native
// method is implemented.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nbe_payment_flutter_plugin/nbe_payment_flutter_plugin.dart';

// Initialization does not validate the merchant against the gateway, so a placeholder ID is
// enough here. Operations that reach the gateway will need a real MTF test merchant.
const _configuration = GatewayConfiguration(
  merchantId: 'TESTMERCHANT',
  merchantName: 'NBE Plugin Integration Test',
  merchantUrl: 'https://example.com',
  region: GatewayRegion.mtf,
  challengeUi: ChallengeUiCustomization(
    toolbar: ChallengeToolbarStyle(
      backgroundColor: Color(0xFF006A4E),
      textColor: Color(0xFFFFFFFF),
      title: 'Secure Payment',
    ),
    button: ChallengeButtonStyle(
      backgroundColor: Color(0x80006A4E),
      cornerRadius: 8,
    ),
    textBox: ChallengeTextBoxStyle(
      borderColor: Color(0xFF999999),
      borderWidth: 1,
    ),
    android: AndroidChallengeCustomization(
      buttonStyles: {
        ChallengeButtonType.resend: ChallengeButtonStyle(
          textColor: Color(0xFFAA0000),
        ),
      },
    ),
  ),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // The native SDK is process-wide, so the steps run in order inside one test.
  testWidgets('initializes the real native Gateway SDK in MTF', (tester) async {
    final gateway = NbePaymentGateway();
    expect(gateway.isInitialized, isFalse);

    await gateway.initialize(_configuration);
    expect(gateway.isInitialized, isTrue);

    // Same configuration again: completes without error.
    await gateway.initialize(_configuration);

    // A different configuration is rejected.
    await expectLater(
      gateway.initialize(
        const GatewayConfiguration(
          merchantId: 'OTHERMERCHANT',
          merchantName: 'Other',
          merchantUrl: 'https://example.com',
          region: GatewayRegion.mtf,
        ),
      ),
      throwsA(
        isA<GatewayException>().having(
          (e) => e.code,
          'code',
          GatewayErrorCode.alreadyInitialized,
        ),
      ),
    );
  });

  // Requires network access to the MTF gateway. The session does not exist, so the gateway
  // must reject the request; the test proves the card update travels Flutter → native SDK →
  // gateway and that the rejection comes back as a typed error.
  //
  // Also used to check SDK logging: after running it, logcat must not contain card data
  // (see the Android notes in the README).
  testWidgets('card update reaches the gateway and maps its rejection', (
    tester,
  ) async {
    final gateway = NbePaymentGateway();
    if (!gateway.isInitialized) {
      await gateway.initialize(_configuration);
    }

    await expectLater(
      gateway.updateSessionWithCard(
        const PaymentSession(
          id: 'SESSION0000000000000000000000000',
          orderId: 'ORDER-INTEGRATION-TEST',
          amount: '1.00',
          currency: 'EGP',
          apiVersion: '100',
        ),
        const CardDetails(
          number: '5123450000000008',
          expiryMonth: '01',
          expiryYear: '39',
          securityCode: '100',
        ),
      ),
      throwsA(
        isA<GatewayException>()
            .having((e) => e.code, 'code', GatewayErrorCode.gatewayRejected)
            .having((e) => e.httpStatusCode, 'httpStatusCode', isNotNull),
      ),
    );
  });

  // Requires network access to the MTF gateway. The session does not exist, so the gateway
  // rejects authentication before any challenge screen. This proves the Activity is available
  // to the SDK and that the failure comes back typed instead of crashing. A real challenge
  // (OTP) needs a real session and is covered by the manual test in the example app.
  testWidgets(
    'payer authentication reaches the gateway and maps its rejection',
    (tester) async {
      final gateway = NbePaymentGateway();
      if (!gateway.isInitialized) {
        await gateway.initialize(_configuration);
      }

      await expectLater(
        gateway.authenticatePayer(
          const PaymentSession(
            id: 'SESSION0000000000000000000000000',
            orderId: 'ORDER-INTEGRATION-TEST',
            amount: '1.00',
            currency: 'EGP',
            apiVersion: '100',
          ),
        ),
        throwsA(
          isA<GatewayException>().having(
            (e) => e.code,
            'code',
            isNot(GatewayErrorCode.uiUnavailable),
          ),
        ),
      );
    },
  );
}
