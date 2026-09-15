import '../generated/payment_api.g.dart';
import '../models/card_details.dart';
import '../models/gateway_fields.dart';
import '../models/payment_session.dart';

SessionMessage toSessionMessage(PaymentSession session) => SessionMessage(
  id: session.id,
  orderId: session.orderId,
  amount: session.amount,
  currency: session.currency,
  apiVersion: session.apiVersion,
);

CardMessage toCardMessage(CardDetails card) => CardMessage(
  number: card.number,
  securityCode: card.securityCode,
  expiryMonth: card.expiryMonth,
  expiryYear: card.expiryYear,
  nameOnCard: card.nameOnCard,
);

/// Returns `null` for absent or empty fields so native code has a single "nothing to add"
/// case.
List<GatewayFieldMessage>? toGatewayFieldMessages(GatewayFields? fields) {
  if (fields == null || fields.isEmpty) {
    return null;
  }
  return fields.values.entries.map(_toGatewayFieldMessage).toList();
}

GatewayFieldMessage _toGatewayFieldMessage(MapEntry<String, Object> field) {
  final value = field.value;
  return switch (value) {
    String() => GatewayFieldMessage(key: field.key, stringValue: value),
    int() => GatewayFieldMessage(key: field.key, intValue: value),
    double() => GatewayFieldMessage(key: field.key, doubleValue: value),
    bool() => GatewayFieldMessage(key: field.key, boolValue: value),
    // GatewayFields only accepts the four types above.
    _ => throw StateError(
      'Unsupported gateway field type ${value.runtimeType}',
    ),
  };
}
