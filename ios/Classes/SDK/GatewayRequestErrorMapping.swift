import Foundation
import Gateway

/// Maps failures of SDK calls that go straight to the gateway REST API (such as
/// `GatewayAPI.updateSession`).
///
/// Error descriptions and response bodies are never copied, because they may echo request
/// values; only error types, the HTTP status and URL error codes are kept.
func gatewayRequestBridgeError(_ error: Error) -> GatewayBridgeError {
  if let gatewayError = error as? GatewayError {
    switch gatewayError {
    case .failedRequest(let statusCode, _):
      return gatewayBridgeError(
        code: errorCodeGatewayRejected,
        message: "The gateway rejected the request.",
        nativeDetails: "GatewayError.failedRequest HTTP \(statusCode)",
        httpStatusCode: statusCode)
    case .invalidAPIVersion:
      return gatewayBridgeError(
        code: errorCodeInvalidApiVersion,
        message: "The gateway API version is not supported.",
        nativeDetails: "GatewayError.invalidAPIVersion")
    case .missingResponse, .unexpectedResponseType:
      return gatewayBridgeError(
        code: errorCodeInvalidGatewayResponse,
        message: "The gateway response could not be read.",
        nativeDetails: "GatewayError.\(gatewayError)")
    @unknown default:
      // A case added by a newer SDK version.
      return gatewayBridgeError(
        code: errorCodeUnknown,
        message: "The gateway request failed.",
        nativeDetails: "GatewayError (unrecognized case)")
    }
  }

  // Includes certificate pinning rejections, which URLSession reports as URLError.cancelled.
  if let urlError = error as? URLError {
    return gatewayBridgeError(
      code: errorCodeNetwork,
      message: "The gateway could not be reached.",
      nativeDetails: "URLError \(urlError.code.rawValue)")
  }

  if error is DecodingError || error is GatewayMap.DecodingError {
    return gatewayBridgeError(
      code: errorCodeInvalidGatewayResponse,
      message: "The gateway response could not be read.",
      nativeDetails: String(describing: type(of: error)))
  }

  return gatewayBridgeError(
    code: errorCodeUnknown,
    message: "The gateway request failed.",
    nativeDetails: String(describing: type(of: error)))
}
