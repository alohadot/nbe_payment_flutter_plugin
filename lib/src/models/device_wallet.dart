import 'package:flutter/foundation.dart' show immutable;

import '../generated/payment_api.g.dart' show CardNetwork, DeviceWallet;

/// Parameters for showing the device wallet payment sheet.
///
/// The amount and currency are taken from the `PaymentSession`, so the sheet always shows
/// what the gateway session will charge.
@immutable
class WalletPaymentRequest {
  const WalletPaymentRequest({
    required this.merchantDisplayName,
    required this.countryCode,
    this.supportedNetworks = defaultSupportedNetworks,
  });

  static const Set<CardNetwork> defaultSupportedNetworks = {
    CardNetwork.visa,
    CardNetwork.mastercard,
  };

  /// Name shown to the payer on the wallet sheet.
  final String merchantDisplayName;

  /// ISO 3166-1 alpha-2 country of the merchant, e.g. `"EG"`.
  final String countryCode;

  /// Card networks the payer may choose from. Must match what the merchant account accepts.
  final Set<CardNetwork> supportedNetworks;
}

/// Outcome of a device wallet payment. Technical failures are thrown as `GatewayException`.
@immutable
sealed class WalletPaymentResult {
  const WalletPaymentResult({required this.wallet});

  final DeviceWallet wallet;
}

/// The payer authorized the wallet payment and the gateway session now holds the wallet
/// token. The merchant server can complete the payment.
final class WalletPaymentCompleted extends WalletPaymentResult {
  const WalletPaymentCompleted({required super.wallet, this.cardDescription});

  /// Display-only card description from the wallet, e.g. `"Visa ••••1234"`.
  final String? cardDescription;
}

/// The payer closed the wallet sheet without paying.
final class WalletPaymentCancelled extends WalletPaymentResult {
  const WalletPaymentCancelled({required super.wallet});
}
