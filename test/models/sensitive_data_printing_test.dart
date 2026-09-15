import 'package:flutter_test/flutter_test.dart';
import 'package:nbe_payment_flutter_plugin/src/models/card_details.dart';
import 'package:nbe_payment_flutter_plugin/src/models/gateway_fields.dart';
import 'package:nbe_payment_flutter_plugin/src/models/payment_session.dart';
import 'package:nbe_payment_flutter_plugin/src/models/sensitive_text_masking.dart';

void main() {
  group('CardDetails.toString', () {
    const card = CardDetails(
      number: '5123450000000008',
      expiryMonth: '01',
      expiryYear: '39',
      securityCode: '100',
      nameOnCard: 'Test User',
    );

    test('shows only the last four digits of the card number', () {
      final printed = card.toString();

      expect(printed, contains('0008'));
      expect(printed, isNot(contains('512345')));
    });

    test('never prints expiry, security code or name', () {
      final printed = card.toString();

      expect(printed, isNot(contains('01/39')));
      expect(printed, isNot(contains('100')));
      expect(printed, isNot(contains('Test User')));
    });
  });

  test('PaymentSession.toString masks the session id', () {
    const session = PaymentSession(
      id: 'SESSION0002123456789',
      orderId: 'ORDER-1',
      amount: '150.00',
      currency: 'EGP',
      apiVersion: '72',
    );

    final printed = session.toString();

    expect(printed, contains('6789'));
    expect(printed, isNot(contains('SESSION0002')));
  });

  test('GatewayFields.toString prints keys but not values', () {
    final fields = GatewayFields()
      ..setString('customer.email', 'user@example.com');

    final printed = fields.toString();

    expect(printed, contains('customer.email'));
    expect(printed, isNot(contains('user@example.com')));
  });

  group('maskAllButLast', () {
    test('keeps the requested number of trailing characters', () {
      expect(maskAllButLast('123456', 2), '••••56');
    });

    test(
      'masks everything when the value is not longer than the visible count',
      () {
        expect(maskAllButLast('123', 4), '•••');
      },
    );
  });
}
