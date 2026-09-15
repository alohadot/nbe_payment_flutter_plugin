import Foundation

/// Builds a channel error in the format the Dart mapper expects.
///
/// `nativeDetails` must never contain card data, wallet tokens or raw gateway response bodies.
func gatewayBridgeError(
  code: String,
  message: String,
  nativeDetails: String? = nil,
  httpStatusCode: Int? = nil
) -> GatewayBridgeError {
  var details: [String: any Sendable] = [:]
  if let nativeDetails = nativeDetails {
    details[errorDetailsNative] = nativeDetails
  }
  if let httpStatusCode = httpStatusCode {
    details[errorDetailsHttpStatusCode] = httpStatusCode
  }
  return GatewayBridgeError(code: code, message: message, details: details.isEmpty ? nil : details)
}
