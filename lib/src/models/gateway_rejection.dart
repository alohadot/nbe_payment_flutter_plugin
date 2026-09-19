// The gateway's own machine-readable rejection fields. They live in their own file because
// both the public failure model and the internal exception carry them.

/// Why the gateway rejected a request, from its `error.cause` field.
enum GatewayRejectionCause {
  /// The request was malformed: see `GatewayException.field` for the value to correct.
  invalidRequest,

  /// The request was well-formed but refused (for example the session cannot be used).
  requestRejected,

  /// The gateway is temporarily overloaded. Retrying later can succeed.
  serverBusy,

  /// The gateway failed while processing the request.
  serverFailed,

  /// A cause this plugin version does not recognize.
  unknown,
}

/// What is wrong with `GatewayException.field`, from the gateway's `error.validationType`.
enum GatewayValidationType {
  /// The field is required and was not sent.
  missing,

  /// The value sent has the wrong format.
  invalid,

  /// The field, or this value for it, is not supported by the merchant account.
  unsupported,

  /// A validation type this plugin version does not recognize.
  unknown,
}

/// Gateway field names that appear in `GatewayException.field` for card data.
///
/// Compare against these instead of writing the paths by hand.
abstract final class GatewayFieldNames {
  /// The card number.
  static const String cardNumber = 'sourceOfFunds.provided.card.number';

  /// The card expiry month.
  static const String expiryMonth = 'sourceOfFunds.provided.card.expiry.month';

  /// The card expiry year.
  static const String expiryYear = 'sourceOfFunds.provided.card.expiry.year';

  /// The card security code (CVV).
  static const String securityCode = 'sourceOfFunds.provided.card.securityCode';

  /// The cardholder name.
  static const String nameOnCard = 'sourceOfFunds.provided.card.nameOnCard';
}
