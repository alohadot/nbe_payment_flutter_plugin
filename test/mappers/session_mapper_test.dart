import 'package:flutter_test/flutter_test.dart';
import 'package:nbe_payment_flutter_plugin/src/mappers/session_mapper.dart';
import 'package:nbe_payment_flutter_plugin/src/models/card_details.dart';
import 'package:nbe_payment_flutter_plugin/src/models/gateway_fields.dart';
import 'package:nbe_payment_flutter_plugin/src/models/payment_session.dart';

void main() {
  test('toSessionMessage copies every field', () {
    const session = PaymentSession(
      id: 'SESSION0002',
      orderId: 'ORDER-1',
      amount: '150.00',
      currency: 'EGP',
      apiVersion: '72',
    );

    final message = toSessionMessage(session);

    expect(message.id, 'SESSION0002');
    expect(message.orderId, 'ORDER-1');
    expect(message.amount, '150.00');
    expect(message.currency, 'EGP');
    expect(message.apiVersion, '72');
  });

  test('toCardMessage copies every field, including optional ones', () {
    const card = CardDetails(
      number: '5123450000000008',
      expiryMonth: '01',
      expiryYear: '39',
      securityCode: '100',
      nameOnCard: 'Test User',
    );

    final message = toCardMessage(card);

    expect(message.number, '5123450000000008');
    expect(message.expiryMonth, '01');
    expect(message.expiryYear, '39');
    expect(message.securityCode, '100');
    expect(message.nameOnCard, 'Test User');
  });

  test('toCardMessage keeps absent optional fields null', () {
    const card = CardDetails(
      number: '5123450000000008',
      expiryMonth: '01',
      expiryYear: '39',
    );

    final message = toCardMessage(card);

    expect(message.securityCode, isNull);
    expect(message.nameOnCard, isNull);
  });

  group('toGatewayFieldMessages', () {
    test('returns null for absent or empty fields', () {
      expect(toGatewayFieldMessages(null), isNull);
      expect(toGatewayFieldMessages(GatewayFields()), isNull);
    });

    test('sets exactly one value slot matching each value type', () {
      final fields = GatewayFields()
        ..setString('billing.address.city', 'Cairo')
        ..setInt('order.itemCount', 2)
        ..setDouble('order.taxAmount', 1.5)
        ..setBool('customer.isReturning', true);

      final messages = toGatewayFieldMessages(fields)!;

      expect(messages.map((m) => m.key), [
        'billing.address.city',
        'order.itemCount',
        'order.taxAmount',
        'customer.isReturning',
      ]);

      expect(messages[0].stringValue, 'Cairo');
      expect([
        messages[0].intValue,
        messages[0].doubleValue,
        messages[0].boolValue,
      ], everyElement(isNull));

      expect(messages[1].intValue, 2);
      expect([
        messages[1].stringValue,
        messages[1].doubleValue,
        messages[1].boolValue,
      ], everyElement(isNull));

      expect(messages[2].doubleValue, 1.5);
      expect([
        messages[2].stringValue,
        messages[2].intValue,
        messages[2].boolValue,
      ], everyElement(isNull));

      expect(messages[3].boolValue, isTrue);
      expect([
        messages[3].stringValue,
        messages[3].intValue,
        messages[3].doubleValue,
      ], everyElement(isNull));
    });
  });
}
