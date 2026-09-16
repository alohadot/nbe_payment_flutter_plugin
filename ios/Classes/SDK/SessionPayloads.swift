import Foundation
import Gateway

/// Update-session payload for manual card entry. Field names follow the "Manual Card Entry"
/// section of the Gateway iOS SDK integration guide.
///
/// Additional fields are written first and card fields last, so card values can never be
/// replaced by a free-form field (the Dart layer already rejects `sourceOfFunds.*` keys).
func buildUpdateSessionWithCardPayload(
  card: CardMessage,
  additionalFields: [GatewayFieldMessage]?
) throws -> GatewayMap {
  var payload = try buildGatewayFieldsPayload(additionalFields) ?? GatewayMap()
  payload.set(.string(card.number), at: "sourceOfFunds.provided.card.number")
  payload.set(.string(card.expiryMonth), at: "sourceOfFunds.provided.card.expiry.month")
  payload.set(.string(card.expiryYear), at: "sourceOfFunds.provided.card.expiry.year")
  payload.set(.string(card.securityCode), at: "sourceOfFunds.provided.card.securityCode")
  if let nameOnCard = card.nameOnCard {
    payload.set(.string(nameOnCard), at: "sourceOfFunds.provided.card.nameOnCard")
  }
  return payload
}

/// Update-session payload for a card the session already holds (a card saved by the merchant
/// server): the security code and nothing else, so the stored card is left untouched.
///
/// Additional fields are written first and the security code last, so it can never be replaced
/// by a free-form field (the Dart layer already rejects `sourceOfFunds.*` keys).
func buildUpdateSessionWithSecurityCodePayload(
  securityCode: String,
  additionalFields: [GatewayFieldMessage]?
) throws -> GatewayMap {
  var payload = try buildGatewayFieldsPayload(additionalFields) ?? GatewayMap()
  payload.set(.string(securityCode), at: "sourceOfFunds.provided.card.securityCode")
  return payload
}

/// Payload for an Apple Pay token, as shown in the "Updating a Session with a PKPaymentToken"
/// section of the iOS integration guide.
func buildApplePayTokenPayload(token: String) -> GatewayMap {
  var payload = GatewayMap()
  payload.set(.string(token), at: "sourceOfFunds.provided.card.devicePayment.paymentToken")
  payload.set(.string("APPLE_PAY"), at: "order.walletProvider")
  return payload
}

struct GatewayFieldWithoutValueError: Error {
  /// Only the key is kept: values may contain personal data.
  let key: String
}

/// Returns `nil` when there are no fields.
func buildGatewayFieldsPayload(_ fields: [GatewayFieldMessage]?) throws -> GatewayMap? {
  guard let fields = fields, !fields.isEmpty else { return nil }
  var payload = GatewayMap()
  for field in fields {
    payload.set(try gatewayValue(of: field), at: field.key)
  }
  return payload
}

private func gatewayValue(of field: GatewayFieldMessage) throws -> GatewayMap {
  if let value = field.stringValue { return .string(value) }
  if let value = field.intValue { return .int(Int(value)) }
  if let value = field.doubleValue { return .double(value) }
  if let value = field.boolValue { return .bool(value) }
  throw GatewayFieldWithoutValueError(key: field.key)
}
