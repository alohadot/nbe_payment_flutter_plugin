import 'package:flutter/services.dart' show PlatformException;

import '../generated/payment_api.g.dart';
import '../models/gateway_exception.dart';

/// Channel error codes (shared with native code through the Pigeon contract) and the public
/// code each one maps to. Every [GatewayErrorCode] must appear exactly once.
const Map<String, GatewayErrorCode> gatewayErrorCodesByChannelCode = {
  errorCodeNotInitialized: GatewayErrorCode.notInitialized,
  errorCodeAlreadyInitialized: GatewayErrorCode.alreadyInitialized,
  errorCodeInitializationFailed: GatewayErrorCode.initializationFailed,
  errorCodeOperationInProgress: GatewayErrorCode.operationInProgress,
  errorCodeInvalidArgument: GatewayErrorCode.invalidArgument,
  errorCodeInvalidApiVersion: GatewayErrorCode.invalidApiVersion,
  errorCodeMissingSessionParameter: GatewayErrorCode.missingSessionParameter,
  errorCodeNetwork: GatewayErrorCode.network,
  errorCodeGatewayRejected: GatewayErrorCode.gatewayRejected,
  errorCodeInvalidGatewayResponse: GatewayErrorCode.invalidGatewayResponse,
  errorCodeInvalidChallengeCompletionUrl:
      GatewayErrorCode.invalidChallengeCompletionUrl,
  errorCodeUiUnavailable: GatewayErrorCode.uiUnavailable,
  errorCodeWalletUnavailable: GatewayErrorCode.walletUnavailable,
  errorCodeWalletConfigurationInvalid:
      GatewayErrorCode.walletConfigurationInvalid,
  errorCodeWalletFailed: GatewayErrorCode.walletFailed,
  errorCodeUnknown: GatewayErrorCode.unknown,
};

/// Converts a channel error into the public exception, dropping details of codes this
/// version does not know.
GatewayException toGatewayException(PlatformException error) {
  final code = gatewayErrorCodesByChannelCode[error.code];
  final details = error.details;
  final detailsMap = details is Map ? details : const <Object?, Object?>{};
  final httpStatusCode = detailsMap[errorDetailsHttpStatusCode];
  final nativeDetails = detailsMap[errorDetailsNative];

  if (code == null) {
    // Not produced by our native adapters, e.g. Pigeon's "channel-error" when the native side
    // is not registered, or a code added by a newer native implementation. Neither the message
    // nor the details can be trusted here: for an exception that escaped the native bridge,
    // Pigeon fills them with the raw exception text and a stack trace, which may echo request
    // values. Only the code name is kept.
    return GatewayException(
      code: GatewayErrorCode.unknown,
      message: 'Unrecognized platform error.',
      httpStatusCode: httpStatusCode is int ? httpStatusCode : null,
      nativeDetails: 'Unrecognized channel error code: ${error.code}',
    );
  }

  return GatewayException(
    code: code,
    message: error.message ?? code.name,
    httpStatusCode: httpStatusCode is int ? httpStatusCode : null,
    nativeDetails: nativeDetails is String ? nativeDetails : null,
  );
}
