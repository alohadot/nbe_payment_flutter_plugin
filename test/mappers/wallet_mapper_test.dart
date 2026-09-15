import 'package:flutter_test/flutter_test.dart';
import 'package:nbe_payment_flutter_plugin/src/generated/payment_api.g.dart';
import 'package:nbe_payment_flutter_plugin/src/mappers/wallet_mapper.dart';
import 'package:nbe_payment_flutter_plugin/src/models/device_wallet.dart';
import 'package:nbe_payment_flutter_plugin/src/models/gateway_configuration.dart';
import 'package:nbe_payment_flutter_plugin/src/models/payment_session.dart';

GatewayConfiguration _configuration(
  GatewayRegion region, {
  WalletConfiguration? wallet,
}) => GatewayConfiguration(
  merchantId: 'id',
  merchantName: 'name',
  merchantUrl: 'https://example.com',
  region: region,
  wallet: wallet,
);

void main() {
  const request = WalletPaymentRequest(
    merchantDisplayName: 'My Store',
    countryCode: 'EG',
    supportedNetworks: {CardNetwork.visa, CardNetwork.amex},
  );

  group('toWalletRequestMessage', () {
    test('combines the request, session and wallet configuration', () {
      const session = PaymentSession(
        id: 'SESSION0002',
        orderId: 'ORDER-1',
        amount: '150.00',
        currency: 'EGP',
        apiVersion: '72',
      );

      final message = toWalletRequestMessage(
        request,
        session: session,
        configuration: _configuration(
          GatewayRegion.mtf,
          wallet: const WalletConfiguration(
            googlePayMerchantId: 'BCR2DN',
            applePayMerchantIdentifier: 'merchant.com.example',
          ),
        ),
      );

      expect(message.session!.id, 'SESSION0002');
      expect(message.merchantDisplayName, 'My Store');
      expect(message.countryCode, 'EG');
      expect(
        message.supportedNetworks,
        unorderedEquals([CardNetwork.visa, CardNetwork.amex]),
      );
      expect(message.isTestEnvironment, isTrue);
      expect(message.googlePayMerchantId, 'BCR2DN');
      expect(message.applePayMerchantIdentifier, 'merchant.com.example');
    });

    test(
      'availability checks have no session, and non-MTF regions are production',
      () {
        final message = toWalletRequestMessage(
          request,
          configuration: _configuration(GatewayRegion.europe),
        );

        expect(message.session, isNull);
        expect(message.isTestEnvironment, isFalse);
        expect(message.googlePayMerchantId, isNull);
        expect(message.applePayMerchantIdentifier, isNull);
      },
    );
  });

  group('toWalletPaymentResult', () {
    test('completed keeps wallet and card description', () {
      final result = toWalletPaymentResult(
        WalletResultMessage(
          outcome: WalletOutcomeMessage.completed,
          wallet: DeviceWallet.applePay,
          cardDescription: 'Visa ••••1234',
        ),
      );

      expect(result, isA<WalletPaymentCompleted>());
      expect(result.wallet, DeviceWallet.applePay);
      expect(
        (result as WalletPaymentCompleted).cardDescription,
        'Visa ••••1234',
      );
    });

    test('cancelled keeps wallet', () {
      final result = toWalletPaymentResult(
        WalletResultMessage(
          outcome: WalletOutcomeMessage.cancelled,
          wallet: DeviceWallet.googlePay,
        ),
      );

      expect(result, isA<WalletPaymentCancelled>());
      expect(result.wallet, DeviceWallet.googlePay);
    });
  });
}
