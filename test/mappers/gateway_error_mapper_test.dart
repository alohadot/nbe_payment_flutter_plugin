import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:nbe_payment_flutter_plugin/src/generated/payment_api.g.dart';
import 'package:nbe_payment_flutter_plugin/src/mappers/gateway_error_mapper.dart';
import 'package:nbe_payment_flutter_plugin/src/models/gateway_exception.dart';

import 'package:nbe_payment_flutter_plugin/src/models/gateway_rejection.dart';

void main() {
  _rejectionTests();

  test('every public error code has exactly one channel code', () {
    expect(
      gatewayErrorCodesByChannelCode.values,
      unorderedEquals(GatewayErrorCode.values),
    );
  });

  for (final entry in gatewayErrorCodesByChannelCode.entries) {
    test('channel code "${entry.key}" maps to ${entry.value.name}', () {
      final exception = toGatewayException(
        PlatformException(code: entry.key, message: 'message'),
      );

      expect(exception.code, entry.value);
      expect(exception.message, 'message');
    });
  }

  test('reads http status and native details from the details map', () {
    final exception = toGatewayException(
      PlatformException(
        code: errorCodeGatewayRejected,
        message: 'Gateway rejected the request.',
        details: <Object?, Object?>{
          errorDetailsHttpStatusCode: 400,
          errorDetailsNative: 'HttpException',
        },
      ),
    );

    expect(exception.code, GatewayErrorCode.gatewayRejected);
    expect(exception.httpStatusCode, 400);
    expect(exception.nativeDetails, 'HttpException');
  });

  test('ignores details that are not a map or have unexpected types', () {
    final fromString = toGatewayException(
      PlatformException(code: errorCodeNetwork, details: 'stack trace'),
    );
    final wrongTypes = toGatewayException(
      PlatformException(
        code: errorCodeNetwork,
        details: <Object?, Object?>{
          errorDetailsHttpStatusCode: '400',
          errorDetailsNative: 42,
        },
      ),
    );

    for (final exception in [fromString, wrongTypes]) {
      expect(exception.code, GatewayErrorCode.network);
      expect(exception.httpStatusCode, isNull);
      expect(exception.nativeDetails, isNull);
    }
  });

  test('falls back to the code name when the message is missing', () {
    final exception = toGatewayException(
      PlatformException(code: errorCodeNetwork),
    );

    expect(exception.message, 'network');
  });

  test(
    'unrecognized codes become unknown without exposing message or details',
    () {
      // For an exception that escaped the native bridge, Pigeon fills message and details with
      // the raw exception text and a stack trace, which may echo request values.
      final exception = toGatewayException(
        PlatformException(
          code: 'NumberFormatException',
          message: 'For input string: "5123450000000008"',
          details: 'Cause: ..., Stacktrace: ...',
        ),
      );

      expect(exception.code, GatewayErrorCode.unknown);
      expect(exception.message, 'Unrecognized platform error.');
      expect(
        exception.nativeDetails,
        'Unrecognized channel error code: NumberFormatException',
      );
      expect(exception.toString(), isNot(contains('5123450000000008')));
      expect(exception.toString(), isNot(contains('Stacktrace')));
    },
  );
}

// The gateway's own rejection fields: the app uses them to tell the payer which value to fix,
// so they must survive the channel as typed values.
void _rejectionTests() {
  test('reads the gateway rejection fields from the details map', () {
    final exception = toGatewayException(
      PlatformException(
        code: errorCodeGatewayRejected,
        message: 'The gateway rejected the request.',
        details: <Object?, Object?>{
          errorDetailsHttpStatusCode: 400,
          errorDetailsGatewayCause: 'INVALID_REQUEST',
          errorDetailsGatewayField: 'sourceOfFunds.provided.card.securityCode',
          errorDetailsGatewayValidationType: 'INVALID',
        },
      ),
    );

    expect(exception.cause, GatewayRejectionCause.invalidRequest);
    expect(exception.field, GatewayFieldNames.securityCode);
    expect(exception.validationType, GatewayValidationType.invalid);
  });

  test('an unknown cause or validation type is kept as unknown', () {
    final exception = toGatewayException(
      PlatformException(
        code: errorCodeGatewayRejected,
        details: <Object?, Object?>{
          errorDetailsGatewayCause: 'SOMETHING_NEW',
          errorDetailsGatewayValidationType: 'SOMETHING_NEW',
        },
      ),
    );

    expect(exception.cause, GatewayRejectionCause.unknown);
    expect(exception.validationType, GatewayValidationType.unknown);
  });

  test('rejection fields are null when the gateway sent none', () {
    final exception = toGatewayException(
      PlatformException(code: errorCodeNetwork),
    );

    expect(exception.cause, isNull);
    expect(exception.field, isNull);
    expect(exception.validationType, isNull);
  });

  for (final entry in {
    'INVALID_REQUEST': GatewayRejectionCause.invalidRequest,
    'REQUEST_REJECTED': GatewayRejectionCause.requestRejected,
    'SERVER_BUSY': GatewayRejectionCause.serverBusy,
    'SERVER_FAILED': GatewayRejectionCause.serverFailed,
  }.entries) {
    test('cause "${entry.key}" maps to ${entry.value.name}', () {
      expect(toGatewayRejectionCause(entry.key), entry.value);
    });
  }

  for (final entry in {
    'MISSING': GatewayValidationType.missing,
    'INVALID': GatewayValidationType.invalid,
    'UNSUPPORTED': GatewayValidationType.unsupported,
  }.entries) {
    test('validation type "${entry.key}" maps to ${entry.value.name}', () {
      expect(toGatewayValidationType(entry.key), entry.value);
    });
  }
}
