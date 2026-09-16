import '../generated/payment_api.g.dart';
import '../models/device_wallet.dart';
import '../models/gateway_configuration.dart';
import '../models/payment_session.dart';
import 'session_mapper.dart';

/// [session] is `null` when the request is only used to check wallet availability.
WalletRequestMessage toWalletRequestMessage(
  WalletPaymentRequest request, {
  required GatewayConfiguration configuration,
  PaymentSession? session,
}) => WalletRequestMessage(
  session: session == null ? null : toSessionMessage(session),
  merchantDisplayName: request.merchantDisplayName,
  countryCode: request.countryCode,
  supportedNetworks: request.supportedNetworks.toList(),
  isTestEnvironment: configuration.isTestEnvironment,
  googlePayMerchantId: configuration.wallet?.googlePayMerchantId,
  applePayMerchantIdentifier: configuration.wallet?.applePayMerchantIdentifier,
);

/// Converts the native wallet result message to the public sealed result.
WalletPaymentResult toWalletPaymentResult(WalletResultMessage message) =>
    switch (message.outcome) {
      WalletOutcomeMessage.completed => WalletPaymentCompleted(
        wallet: message.wallet,
        cardDescription: message.cardDescription,
      ),
      WalletOutcomeMessage.cancelled => WalletPaymentCancelled(
        wallet: message.wallet,
      ),
    };
