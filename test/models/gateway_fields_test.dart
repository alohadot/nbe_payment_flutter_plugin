import 'package:flutter_test/flutter_test.dart';
import 'package:nbe_payment_flutter_plugin/src/models/gateway_exception.dart';
import 'package:nbe_payment_flutter_plugin/src/models/gateway_fields.dart';

Matcher _throwsInvalidArgument() => throwsA(
  isA<GatewayException>().having(
    (e) => e.code,
    'code',
    GatewayErrorCode.invalidArgument,
  ),
);

void main() {
  test('stores typed values in insertion order', () {
    final fields = GatewayFields()
      ..setString('billing.address.city', 'Cairo')
      ..setInt('order.itemCount', 2)
      ..setDouble('order.taxAmount', 1.5)
      ..setBool('customer.isReturning', true);

    expect(fields.values, {
      'billing.address.city': 'Cairo',
      'order.itemCount': 2,
      'order.taxAmount': 1.5,
      'customer.isReturning': true,
    });
  });

  test('setting an existing key replaces its value', () {
    final fields = GatewayFields()
      ..setString('customer.email', 'old@example.com')
      ..setString('customer.email', 'new@example.com');

    expect(fields.values, {'customer.email': 'new@example.com'});
  });

  test('exposed values cannot be modified from outside', () {
    final fields = GatewayFields()
      ..setString('customer.email', 'user@example.com');

    expect(() => fields.values['customer.email'] = 'x', throwsUnsupportedError);
  });

  group('rejects', () {
    for (final key in [
      '',
      '.city',
      'billing.',
      'billing..city',
      'billing.address city',
      '1billing',
    ]) {
      test('malformed key "$key"', () {
        expect(
          () => GatewayFields().setString(key, 'value'),
          _throwsInvalidArgument(),
        );
      });
    }

    for (final key in [
      'sourceOfFunds',
      'sourceOfFunds.provided.card.number',
      'sourceOfFunds.provided.card.devicePayment.paymentToken',
    ]) {
      test('reserved card or wallet key "$key"', () {
        expect(
          () => GatewayFields().setString(key, 'value'),
          _throwsInvalidArgument(),
        );
      });
    }
  });

  test(
    'allows keys that only start with the same letters as the reserved key',
    () {
      final fields = GatewayFields()..setString('sourceOfFundsNote', 'value');

      expect(fields.values, {'sourceOfFundsNote': 'value'});
    },
  );
}
