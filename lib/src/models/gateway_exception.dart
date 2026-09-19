import 'gateway_rejection.dart';

/// Technical failure codes reported by [GatewayException].
///
/// Payment outcomes such as a cancelled challenge or an issuer decline are not errors;
/// they are returned as results. Branch on these codes, never on [GatewayException.message].
enum GatewayErrorCode {
  /// An operation was called before `initialize` completed.
  notInitialized,

  /// `initialize` was called again with a different configuration.
  alreadyInitialized,

  /// The native SDK reported a failure while initializing.
  initializationFailed,

  /// Another gateway operation is still running. Only one runs at a time.
  operationInProgress,

  /// An argument failed validation before anything was sent to the gateway.
  invalidArgument,

  /// The session API version is below the minimum supported by the native SDKs (61).
  invalidApiVersion,

  /// The session is missing fields required for authentication
  /// (e.g. order amount or 3DS settings not loaded by the merchant server).
  missingSessionParameter,

  /// The gateway could not be reached.
  network,

  /// The gateway answered with an HTTP error. See [GatewayException.httpStatusCode].
  gatewayRejected,

  /// The gateway answered with a response the SDK could not interpret.
  invalidGatewayResponse,

  /// The 3DS challenge completion URL was invalid.
  invalidChallengeCompletionUrl,

  /// No visible screen was available to present the 3DS challenge or the wallet sheet.
  uiUnavailable,

  /// The device wallet cannot be used on this device, although it is configured.
  ///
  /// Reported when a wallet payment is started on a device that cannot pay. Use
  /// `getAvailableWallet` beforehand to avoid it.
  walletUnavailable,

  /// The wallet configuration was rejected (e.g. an invalid merchant identifier).
  walletConfigurationInvalid,

  /// The device wallet reported a failure.
  walletFailed,

  /// A failure that does not match any other code.
  unknown,
}

/// A technical failure while talking to the payment gateway.
///
/// Public failure returned through the error channel of a gateway method's `Future`.
///
/// Catch this at the UI boundary and branch on [code]. [message] and [nativeDetails] are
/// developer diagnostics and must not be shown directly to the payer.
class GatewayException implements Exception {
  /// Creates a failure with a stable [code] and a human-readable [message].
  const GatewayException({
    required this.code,
    required this.message,
    this.httpStatusCode,
    this.cause,
    this.field,
    this.validationType,
    this.nativeDetails,
  });

  /// What went wrong. Branch on this, never on [message].
  final GatewayErrorCode code;

  /// Human-readable description for logs and developers. Never contains card data.
  final String message;

  /// HTTP status of the gateway response, when the failure carried one. Set for
  /// [GatewayErrorCode.gatewayRejected]; `null` for every other code today.
  final int? httpStatusCode;

  /// Why the gateway rejected the request, from its own `error.cause`.
  final GatewayRejectionCause? cause;

  /// The gateway field the rejection is about, from its own `error.field`.
  final String? field;

  /// What is wrong with [field], from the gateway's own `error.validationType`.
  final GatewayValidationType? validationType;

  /// Sanitized native diagnostic information, for debugging only.
  final String? nativeDetails;

  @override
  String toString() {
    final status =
        httpStatusCode == null ? '' : ', httpStatusCode: $httpStatusCode';
    final details =
        nativeDetails == null ? '' : ', nativeDetails: $nativeDetails';
    return 'GatewayException(${code.name}: $message$status$details)';
  }
}
