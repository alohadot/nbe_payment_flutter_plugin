// Runs inside the example app on a real device or emulator, against the real native SDK.
// Nothing here is faked.
//
// Run with:
//   cd example
//   flutter test integration_test/plugin_integration_test.dart -d <device-id>
//
// These tests use a non-existent session: they prove the path from Dart to the gateway and the
// error mapping, not a successful payment. Successful payments and OTP challenges need a real
// MTF session and are covered by the manual tests in example/README.md.

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
  // Apple Pay availability requires a merchant identifier; this placeholder is never used to
  // present the sheet in these tests.
  wallet: WalletConfiguration(
    applePayMerchantIdentifier: 'merchant.com.example.integrationtest',
  ),
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

  // The saved-card path: the payload carries only the security code, with no card number.
  // The session does not exist, so the gateway must reject it; the test proves the path and
  // the error mapping, not a payment.
  //
  // Also used to check SDK logging: after running it, logcat must contain no `securityCode`.
  testWidgets(
    'security code update reaches the gateway and maps its rejection',
    (tester) async {
      final gateway = NbePaymentGateway();
      if (!gateway.isInitialized) {
        await gateway.initialize(_configuration);
      }

      await expectLater(
        gateway.updateSessionWithSecurityCode(_unknownSession, '100'),
        throwsA(
          isA<GatewayException>()
              .having((e) => e.code, 'code', GatewayErrorCode.gatewayRejected)
              .having((e) => e.httpStatusCode, 'httpStatusCode', isNotNull),
        ),
      );
    },
  );

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

  // Availability depends on the device (Google Play services, signed-in account), so only a
  // well-formed answer is checked, not which wallet is reported.
  testWidgets('wallet availability returns an answer without UI', (
    tester,
  ) async {
    final gateway = NbePaymentGateway();
    if (!gateway.isInitialized) {
      await gateway.initialize(_configuration);
    }

    final wallet = await gateway.getAvailableWallet(
      const WalletPaymentRequest(
        merchantDisplayName: 'Integration Test',
        countryCode: 'EG',
      ),
    );

    expect(
      wallet,
      isIn([DeviceWallet.googlePay, DeviceWallet.applePay, DeviceWallet.none]),
    );
    debugPrint('Available wallet on this device: ${wallet.name}');
  });

  // Simulates a double tap: two operations started without waiting. One must reach the
  // gateway, the other must be rejected by the plugin, and the plugin must accept a new call
  // afterwards.
  testWidgets(
    'concurrent operations are rejected, then the gateway is usable again',
    (tester) async {
      final gateway = NbePaymentGateway();
      if (!gateway.isInitialized) {
        await gateway.initialize(_configuration);
      }

      Future<GatewayErrorCode?> attempt() async {
        try {
          await gateway.updateSessionWithCard(_unknownSession, _testCard);
          return null;
        } on GatewayException catch (error) {
          return error.code;
        }
      }

      final codes = await Future.wait([attempt(), attempt()]);
      expect(
        codes,
        unorderedEquals([
          GatewayErrorCode.gatewayRejected,
          GatewayErrorCode.operationInProgress,
        ]),
      );

      expect(await attempt(), GatewayErrorCode.gatewayRejected);
    },
  );
}

const _unknownSession = PaymentSession(
  id: 'SESSION0000000000000000000000000',
  orderId: 'ORDER-INTEGRATION-TEST',
  amount: '1.00',
  currency: 'EGP',
  apiVersion: '100',
);

const _testCard = CardDetails(
  number: '5123450000000008',
  expiryMonth: '01',
  expiryYear: '39',
  securityCode: '100',
);
