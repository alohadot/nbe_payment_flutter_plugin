import 'package:flutter_test/flutter_test.dart';
import 'package:nbe_payment_flutter_plugin/src/generated/payment_api.g.dart'
    show CardNetwork, GatewayRegion;
import 'package:nbe_payment_flutter_plugin/src/models/card_details.dart';
import 'package:nbe_payment_flutter_plugin/src/models/device_wallet.dart';
import 'package:nbe_payment_flutter_plugin/src/models/gateway_configuration.dart';
import 'package:nbe_payment_flutter_plugin/src/models/gateway_exception.dart';
import 'package:nbe_payment_flutter_plugin/src/models/payment_session.dart';
import 'package:nbe_payment_flutter_plugin/src/validation/input_validation.dart';

Matcher _throwsGatewayError(GatewayErrorCode code) =>
    throwsA(isA<GatewayException>().having((e) => e.code, 'code', code));

PaymentSession _session({
  String id = 'SESSION0002',
  String orderId = 'ORDER-1',
  String amount = '150.00',
  String currency = 'EGP',
  String apiVersion = '72',
}) => PaymentSession(
  id: id,
  orderId: orderId,
  amount: amount,
  currency: currency,
  apiVersion: apiVersion,
);

CardDetails _card({
  String number = '5123450000000008',
  String expiryMonth = '01',
  String expiryYear = '39',
  String? securityCode = '100',
}) => CardDetails(
  number: number,
  expiryMonth: expiryMonth,
  expiryYear: expiryYear,
  securityCode: securityCode,
);

GatewayConfiguration _configuration({
  String merchantId = 'TESTNBE000123',
  String merchantName = 'My Store',
  String merchantUrl = 'https://mystore.example',
}) => GatewayConfiguration(
  merchantId: merchantId,
  merchantName: merchantName,
  merchantUrl: merchantUrl,
  region: GatewayRegion.mtf,
);

void main() {
  group('validateConfiguration', () {
    test('accepts a complete configuration', () {
      expect(() => validateConfiguration(_configuration()), returnsNormally);
    });

    test('rejects a blank merchant id', () {
      expect(
        () => validateConfiguration(_configuration(merchantId: '  ')),
        _throwsGatewayError(GatewayErrorCode.invalidArgument),
      );
    });

    for (final url in [
      '',
      'mystore.example',
      'ftp://mystore.example',
      'https://',
    ]) {
      test('rejects merchant url "$url"', () {
        expect(
          () => validateConfiguration(_configuration(merchantUrl: url)),
          _throwsGatewayError(GatewayErrorCode.invalidArgument),
        );
      });
    }
  });

  test('isTestEnvironment is true only for the MTF region', () {
    for (final region in GatewayRegion.values) {
      final configuration = GatewayConfiguration(
        merchantId: 'id',
        merchantName: 'name',
        merchantUrl: 'https://example.com',
        region: region,
      );
      expect(
        configuration.isTestEnvironment,
        region == GatewayRegion.mtf,
        reason: region.name,
      );
    }
  });

  group('validateSession', () {
    test('accepts a valid session', () {
      expect(() => validateSession(_session()), returnsNormally);
    });

    for (final amount in ['150', '150.5', '0.123']) {
      test('accepts amount "$amount"', () {
        expect(
          () => validateSession(_session(amount: amount)),
          returnsNormally,
        );
      });
    }

    for (final amount in ['', '-1', '1,50', '1.2345', 'abc']) {
      test('rejects amount "$amount"', () {
        expect(
          () => validateSession(_session(amount: amount)),
          _throwsGatewayError(GatewayErrorCode.invalidArgument),
        );
      });
    }

    for (final currency in ['egp', 'EG', 'EGPP']) {
      test('rejects currency "$currency"', () {
        expect(
          () => validateSession(_session(currency: currency)),
          _throwsGatewayError(GatewayErrorCode.invalidArgument),
        );
      });
    }

    test('rejects a non-numeric api version as an invalid argument', () {
      expect(
        () => validateSession(_session(apiVersion: 'v72')),
        _throwsGatewayError(GatewayErrorCode.invalidArgument),
      );
    });

    test('rejects api versions below 61 with invalidApiVersion', () {
      expect(
        () => validateSession(_session(apiVersion: '60')),
        _throwsGatewayError(GatewayErrorCode.invalidApiVersion),
      );
    });

    test('accepts api version 61', () {
      expect(
        () => validateSession(_session(apiVersion: '61')),
        returnsNormally,
      );
    });
  });

  group('validateCard', () {
    test('accepts a valid card', () {
      expect(() => validateCard(_card()), returnsNormally);
    });

    test('accepts a card without security code', () {
      expect(() => validateCard(_card(securityCode: null)), returnsNormally);
    });

    for (final number in [
      '',
      '5123 4500 0000 0008',
      '12345678901',
      '12345678901234567890',
    ]) {
      test('rejects card number with length ${number.length}', () {
        expect(
          () => validateCard(_card(number: number)),
          _throwsGatewayError(GatewayErrorCode.invalidArgument),
        );
      });
    }

    for (final month in ['00', '13', '1']) {
      test('rejects expiry month "$month"', () {
        expect(
          () => validateCard(_card(expiryMonth: month)),
          _throwsGatewayError(GatewayErrorCode.invalidArgument),
        );
      });
    }

    for (final year in ['2039', '9']) {
      test('rejects expiry year "$year"', () {
        expect(
          () => validateCard(_card(expiryYear: year)),
          _throwsGatewayError(GatewayErrorCode.invalidArgument),
        );
      });
    }

    for (final securityCode in ['12', '12345', 'abc']) {
      test('rejects security code with length ${securityCode.length}', () {
        expect(
          () => validateCard(_card(securityCode: securityCode)),
          _throwsGatewayError(GatewayErrorCode.invalidArgument),
        );
      });
    }

    test('error messages never contain the card number', () {
      try {
        validateCard(_card(expiryMonth: '13'));
        fail('expected validation to fail');
      } on GatewayException catch (e) {
        expect(e.toString(), isNot(contains('5123450000000008')));
      }
    });
  });

  group('validateWalletRequest', () {
    test('accepts a valid request with the default networks', () {
      const request = WalletPaymentRequest(
        merchantDisplayName: 'My Store',
        countryCode: 'EG',
      );

      expect(() => validateWalletRequest(request), returnsNormally);
      expect(request.supportedNetworks, {
        CardNetwork.visa,
        CardNetwork.mastercard,
      });
    });

    test('rejects a lowercase country code', () {
      const request = WalletPaymentRequest(
        merchantDisplayName: 'My Store',
        countryCode: 'eg',
      );

      expect(
        () => validateWalletRequest(request),
        _throwsGatewayError(GatewayErrorCode.invalidArgument),
      );
    });

    test('rejects an empty network set', () {
      const request = WalletPaymentRequest(
        merchantDisplayName: 'My Store',
        countryCode: 'EG',
        supportedNetworks: {},
      );

      expect(
        () => validateWalletRequest(request),
        _throwsGatewayError(GatewayErrorCode.invalidArgument),
      );
    });
  });

  group('validateWalletChargeableSession', () {
    test('accepts a positive amount', () {
      expect(
        () => validateWalletChargeableSession(_session(amount: '0.01')),
        returnsNormally,
      );
    });

    for (final amount in ['0', '0.0', '0.00']) {
      test('rejects zero amount "$amount"', () {
        expect(
          () => validateWalletChargeableSession(_session(amount: amount)),
          _throwsGatewayError(GatewayErrorCode.invalidArgument),
        );
      });
    }

    test('a zero amount is still allowed for a card session', () {
      // Card verification sessions can legitimately carry a zero amount.
      expect(() => validateSession(_session(amount: '0')), returnsNormally);
    });
  });

  test('validateAuthenticationTransactionId rejects blank ids', () {
    expect(
      () => validateAuthenticationTransactionId(' '),
      _throwsGatewayError(GatewayErrorCode.invalidArgument),
    );
  });
}
