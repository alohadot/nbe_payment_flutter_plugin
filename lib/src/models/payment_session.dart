import 'package:flutter/foundation.dart' show immutable;

import 'sensitive_text_masking.dart';

/// A gateway session created by the merchant server.
///
/// The server creates the session and loads the order and 3DS fields into it using its
/// private API credentials; the app only receives these identifiers.
@immutable
class PaymentSession {
  const PaymentSession({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.currency,
    required this.apiVersion,
  });

  final String id;

  /// Must match the order ID the server used when updating the session.
  final String orderId;

  /// Decimal amount as text, e.g. `"150.00"`. Text avoids floating-point rounding.
  final String amount;

  /// ISO 4217 code, e.g. `"EGP"`.
  final String currency;

  /// Gateway API version used to create the session, e.g. `"72"`. Must stay the same for
  /// the whole transaction, from session creation to the final payment. Minimum 61.
  final String apiVersion;

  @override
  String toString() =>
      'PaymentSession(id: ${maskAllButLast(id, 4)}, orderId: $orderId, '
      'amount: $amount $currency, apiVersion: $apiVersion)';
}
