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
    case .failedRequest(let statusCode, let body):
      // The SDK hands the response body over as text; only the machine-readable fields are
      // read out of it, never the body itself.
      let rejection = readGatewayRejection(body)
      return gatewayBridgeError(
        code: errorCodeGatewayRejected,
        message: "The gateway rejected the request.",
        nativeDetails: describeGatewayRejection(httpStatusCode: statusCode, rejection: rejection),
        httpStatusCode: statusCode,
        rejection: rejection)
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

/// Reads `error.cause`, `error.field` and `error.validationType` out of a gateway error body.
///
/// Returns `nil` when the body is missing, is not the expected JSON, or carries none of the
/// three fields. `error.explanation` is deliberately dropped: it is free text that may quote
/// submitted values.
func readGatewayRejection(_ body: String?) -> GatewayRejectionFields? {
  guard
    let data = body?.data(using: .utf8),
    let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
    let error = root["error"] as? [String: Any]
  else {
    return nil
  }

  let rejection = GatewayRejectionFields(
    cause: error["cause"] as? String,
    field: error["field"] as? String,
    validationType: error["validationType"] as? String)
  return rejection.isEmpty ? nil : rejection
}

/// The same fields as one diagnostic line, for logs.
func describeGatewayRejection(httpStatusCode: Int, rejection: GatewayRejectionFields?) -> String {
  var summary = ["HTTP \(httpStatusCode)"]
  if let cause = rejection?.cause { summary.append("cause=\(cause)") }
  if let field = rejection?.field { summary.append("field=\(field)") }
  if let validationType = rejection?.validationType {
    summary.append("validationType=\(validationType)")
  }
  return summary.joined(separator: "; ")
}
