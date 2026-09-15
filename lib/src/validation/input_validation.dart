import '../models/card_details.dart';
import '../models/device_wallet.dart';
import '../models/gateway_configuration.dart';
import '../models/gateway_exception.dart';
import '../models/payment_session.dart';

/// Oldest gateway API version the native SDKs accept for authentication.
const int minimumGatewayApiVersion = 61;

// Validation runs in Dart before anything crosses the platform channel, so both platforms
// reject the same inputs with the same error. Messages never echo card values.

void validateConfiguration(GatewayConfiguration configuration) {
  _requireNotBlank(configuration.merchantId, 'merchantId');
  _requireNotBlank(configuration.merchantName, 'merchantName');

  final url = Uri.tryParse(configuration.merchantUrl);
  final isWebUrl =
      url != null &&
      (url.scheme == 'https' || url.scheme == 'http') &&
      url.host.isNotEmpty;
  if (!isWebUrl) {
    throw _invalidArgument('merchantUrl must be an absolute http(s) URL.');
  }
}

void validateSession(PaymentSession session) {
  _requireNotBlank(session.id, 'session.id');
  _requireNotBlank(session.orderId, 'session.orderId');

  if (!RegExp(r'^\d+(\.\d{1,3})?$').hasMatch(session.amount)) {
    throw _invalidArgument(
      'session.amount must be a positive decimal such as "150.00".',
    );
  }
  if (!RegExp(r'^[A-Z]{3}$').hasMatch(session.currency)) {
    throw _invalidArgument(
      'session.currency must be an ISO 4217 code such as "EGP".',
    );
  }

  final apiVersion = int.tryParse(session.apiVersion);
  if (apiVersion == null) {
    throw _invalidArgument(
      'session.apiVersion must be a whole number such as "72".',
    );
  }
  if (apiVersion < minimumGatewayApiVersion) {
    throw GatewayException(
      code: GatewayErrorCode.invalidApiVersion,
      message:
          'session.apiVersion must be $minimumGatewayApiVersion or higher.',
    );
  }
}

void validateCard(CardDetails card) {
  if (!RegExp(r'^\d{12,19}$').hasMatch(card.number)) {
    throw _invalidArgument('Card number must contain 12 to 19 digits only.');
  }
  if (!RegExp(r'^(0[1-9]|1[0-2])$').hasMatch(card.expiryMonth)) {
    throw _invalidArgument(
      'Card expiry month must be two digits from 01 to 12.',
    );
  }
  if (!RegExp(r'^\d{2}$').hasMatch(card.expiryYear)) {
    throw _invalidArgument('Card expiry year must be two digits.');
  }
  final securityCode = card.securityCode;
  if (securityCode != null && !RegExp(r'^\d{3,4}$').hasMatch(securityCode)) {
    throw _invalidArgument('Card security code must be 3 or 4 digits.');
  }
}

void validateAuthenticationTransactionId(String authenticationTransactionId) {
  _requireNotBlank(authenticationTransactionId, 'authenticationTransactionId');
}

void validateWalletRequest(WalletPaymentRequest request) {
  _requireNotBlank(request.merchantDisplayName, 'merchantDisplayName');
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(request.countryCode)) {
    throw _invalidArgument(
      'countryCode must be an ISO 3166-1 alpha-2 code such as "EG".',
    );
  }
  if (request.supportedNetworks.isEmpty) {
    throw _invalidArgument(
      'supportedNetworks must contain at least one network.',
    );
  }
}

void _requireNotBlank(String value, String name) {
  if (value.trim().isEmpty) {
    throw _invalidArgument('$name must not be empty.');
  }
}

GatewayException _invalidArgument(String message) =>
    GatewayException(code: GatewayErrorCode.invalidArgument, message: message);
