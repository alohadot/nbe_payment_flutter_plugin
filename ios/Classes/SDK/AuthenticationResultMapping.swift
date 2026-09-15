import Foundation
import Gateway

/// Converts the iOS SDK authentication response into the contract.
///
/// Payment outcomes (declines, cancellation) become result messages; integration and technical
/// failures become channel errors. Authentication requests carry no card data, so SDK error
/// texts are kept as native details to help diagnose gateway configuration problems.
func toAuthenticationResult(
  _ response: AuthenticationResponse,
  authenticationTransactionId: String
) -> Result<AuthenticationResultMessage, Error> {
  func outcome(_ outcome: AuthenticationOutcomeMessage) -> Result<AuthenticationResultMessage, Error> {
    return .success(
      AuthenticationResultMessage(
        outcome: outcome,
        authenticationPerformed: response.authenticationPerformed,
        challengePerformed: response.challengePerformed,
        authenticationTransactionId: authenticationTransactionId,
        sdkTransactionId: response.sdkTransactionId,
        threeDS2TransactionStatus: response.threeDS2TransactionStatus))
  }

  if response.recommendation == .proceed {
    return outcome(.proceed)
  }

  guard let error = response.error else {
    return outcome(.doNotProceed)
  }

  guard let authenticationError = error as? AuthenticationError else {
    // Network and gateway failures from the authentication requests.
    return .failure(gatewayRequestBridgeError(error))
  }

  switch authenticationError {
  case .challengeCancelledByUser:
    return outcome(.cancelledByUser)
  case .challengeTimedOut:
    return outcome(.challengeTimedOut)
  case .recommendation_ResubmitWithAlternativePaymentDetails:
    return outcome(.resubmitWithAlternativePaymentDetails)
  case .recommendation_AbandonOrder:
    return outcome(.abandonOrder)
  case .recommendation_DoNotProceed:
    return outcome(.doNotProceed)
  case .recommendation_Unknown:
    return outcome(.unknownRecommendation)
  case .notInitialized:
    return .failure(
      gatewayBridgeError(
        code: errorCodeNotInitialized,
        message: "The Gateway SDK is not initialized."))
  case .missingParameter(let parameter):
    return .failure(
      gatewayBridgeError(
        code: errorCodeMissingSessionParameter,
        message: "The session is missing fields required for authentication.",
        nativeDetails: parameter))
  case .invalidChallengeCompletionURL(let detail):
    return .failure(
      gatewayBridgeError(
        code: errorCodeInvalidChallengeCompletionUrl,
        message: "The 3DS challenge completion URL is invalid.",
        nativeDetails: detail))
  case .other(let detail):
    return .failure(
      gatewayBridgeError(
        code: errorCodeUnknown,
        message: "Payer authentication failed.",
        nativeDetails: "AuthenticationError.other: \(detail)"))
  @unknown default:
    // A case added by a newer SDK version.
    return .failure(
      gatewayBridgeError(
        code: errorCodeUnknown,
        message: "Payer authentication failed.",
        nativeDetails: "AuthenticationError: \(authenticationError)"))
  }
}
