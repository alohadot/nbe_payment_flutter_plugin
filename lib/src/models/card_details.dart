import 'package:flutter/foundation.dart' show immutable;

import 'sensitive_text_masking.dart';

/// Card data entered by the payer.
///
/// Sent once to the gateway session and not retained by the plugin. Keep instances
/// short-lived in the app as well.
@immutable
class CardDetails {
  /// Creates card details from what the payer typed.
  const CardDetails({
    required this.number,
    required this.expiryMonth,
    required this.expiryYear,
    required this.securityCode,
    this.nameOnCard,
  });

  /// Digits only, no spaces.
  final String number;

  /// Two digits, `01`–`12`.
  final String expiryMonth;

  /// Two digits, e.g. `39` for 2039.
  final String expiryYear;

  /// CVV / CVC, 3 or 4 digits.
  ///
  /// Required: the gateway refuses a card payment without it, and a card the payer typed
  /// always comes with one. For a card already stored in the session by the merchant server,
  /// use `NbePaymentGateway.updateSessionWithSecurityCode` instead.
  final String securityCode;

  /// Cardholder name as printed on the card.
  final String? nameOnCard;

  // Every field is masked: this object must be safe to print by accident.
  @override
  String toString() =>
      'CardDetails(number: ${maskAllButLast(number, 4)}, '
      'expiry: ••/••, '
      'securityCode: •••, '
      'nameOnCard: ${nameOnCard == null ? 'none' : '•••'})';
}
