import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:nbe_payment_flutter_plugin/src/generated/payment_api.g.dart';
import 'package:nbe_payment_flutter_plugin/src/mappers/gateway_error_mapper.dart';
import 'package:nbe_payment_flutter_plugin/src/models/gateway_exception.dart';

void main() {
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

  test('unrecognized codes become unknown without exposing their details', () {
    final exception = toGatewayException(
      PlatformException(
        code: 'channel-error',
        message: 'Unable to establish connection on channel.',
        details: 'Cause: ..., Stacktrace: ...',
      ),
    );

    expect(exception.code, GatewayErrorCode.unknown);
    expect(exception.message, 'Unable to establish connection on channel.');
    expect(
      exception.nativeDetails,
      'Unrecognized channel error code: channel-error',
    );
    expect(exception.toString(), isNot(contains('Stacktrace')));
  });
}
