import Foundation

/// Builds a channel error in the format the Dart mapper expects.
///
/// `nativeDetails` must never contain card data, wallet tokens or raw gateway response bodies.
func gatewayBridgeError(
  code: String,
  message: String,
  nativeDetails: String? = nil,
  httpStatusCode: Int? = nil,
  rejection: GatewayRejectionFields? = nil
) -> GatewayBridgeError {
  var details: [String: any Sendable] = [:]
  if let nativeDetails = nativeDetails {
    details[errorDetailsNative] = nativeDetails
  }
  if let httpStatusCode = httpStatusCode {
    details[errorDetailsHttpStatusCode] = httpStatusCode
  }
  if let cause = rejection?.cause {
    details[errorDetailsGatewayCause] = cause
  }
  if let field = rejection?.field {
    details[errorDetailsGatewayField] = field
  }
  if let validationType = rejection?.validationType {
    details[errorDetailsGatewayValidationType] = validationType
  }
  return GatewayBridgeError(code: code, message: message, details: details.isEmpty ? nil : details)
}

/// The gateway's machine-readable rejection fields, as they appear in the `error` object of its
/// response. They name what was wrong without repeating what was sent, so the app can tell the
/// payer which field to fix. `error.explanation` is never carried: it is free text that can
/// quote submitted values.
struct GatewayRejectionFields {
  let cause: String?
  let field: String?
  let validationType: String?

  var isEmpty: Bool { cause == nil && field == nil && validationType == nil }
}

/// Shortens free text coming from the SDK, the 3DS server or the issuer before it is sent to
/// Flutter as a diagnostic. Those messages are unbounded third-party text; only the beginning
/// is useful, and a long payload has no place in an error.
func sanitizedSdkDetail(_ detail: String?, maxLength: Int = 120) -> String? {
  guard
    let normalized = detail?
      .components(separatedBy: .whitespacesAndNewlines)
      .filter({ !$0.isEmpty })
      .joined(separator: " "),
    !normalized.isEmpty
  else {
    return nil
  }
  if normalized.count <= maxLength { return normalized }
  return String(normalized.prefix(maxLength)) + "…"
}
