import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nbe_payment_flutter_plugin/nbe_payment_flutter_plugin.dart';
import 'package:nbe_payment_flutter_plugin/src/generated/payment_api.g.dart'
    show
        AuthenticationOutcomeMessage,
        errorCodeNetwork,
        errorCodeGatewayRejected,
        errorDetailsHttpStatusCode;

import 'fake_host_api.dart';

const _configuration = GatewayConfiguration(
  merchantId: 'TESTNBE000123',
  merchantName: 'My Store',
  merchantUrl: 'https://mystore.example',
  region: GatewayRegion.mtf,
  wallet: WalletConfiguration(googlePayMerchantId: 'BCR2DN'),
);

const _session = PaymentSession(
  id: 'SESSION0002',
  orderId: 'ORDER-1',
  amount: '150.00',
  currency: 'EGP',
  apiVersion: '72',
);

const _card = CardDetails(
  number: '5123450000000008',
  expiryMonth: '01',
  expiryYear: '39',
  securityCode: '100',
);

const _walletRequest = WalletPaymentRequest(
  merchantDisplayName: 'My Store',
  countryCode: 'EG',
);

Matcher _throwsGatewayError(GatewayErrorCode code) =>
    throwsA(isA<GatewayException>().having((e) => e.code, 'code', code));

void main() {
  late FakeHostApi hostApi;
  late NbePaymentGateway gateway;

  setUp(() {
    hostApi = FakeHostApi();
    gateway = NbePaymentGateway.withHostApi(
      hostApi,
      generateTransactionId: () => 'generated-id',
    );
  });

  Future<void> initialize() => gateway.initialize(_configuration);

  test('the public constructor always returns the same shared instance', () {
    expect(identical(NbePaymentGateway(), NbePaymentGateway()), isTrue);
  });

  group('initialize', () {
    test('sends the configuration and marks the gateway initialized', () async {
      expect(gateway.isInitialized, isFalse);

      await initialize();

      expect(gateway.isInitialized, isTrue);
      expect(hostApi.calls, ['initialize']);
      expect(hostApi.lastInitializeRequest!.merchantId, 'TESTNBE000123');
      expect(hostApi.lastInitializeRequest!.region, GatewayRegion.mtf);
    });

    test('invalid configuration fails without calling native code', () async {
      final invalid = GatewayConfiguration(
        merchantId: '',
        merchantName: 'My Store',
        merchantUrl: 'https://mystore.example',
        region: GatewayRegion.mtf,
      );

      await expectLater(
        gateway.initialize(invalid),
        _throwsGatewayError(GatewayErrorCode.invalidArgument),
      );
      expect(hostApi.calls, isEmpty);
    });

    test(
      'native failure is mapped and leaves the gateway uninitialized',
      () async {
        hostApi.nextError = PlatformException(
          code: 'initialization_failed',
          message: 'SDK failed',
        );

        await expectLater(
          initialize(),
          _throwsGatewayError(GatewayErrorCode.initializationFailed),
        );
        expect(gateway.isInitialized, isFalse);
      },
    );

    test(
      'repeating with an equal configuration does not call native again',
      () async {
        await initialize();
        await gateway.initialize(
          const GatewayConfiguration(
            merchantId: 'TESTNBE000123',
            merchantName: 'My Store',
            merchantUrl: 'https://mystore.example',
            region: GatewayRegion.mtf,
            wallet: WalletConfiguration(googlePayMerchantId: 'BCR2DN'),
          ),
        );

        expect(hostApi.calls, ['initialize']);
      },
    );

    test(
      'a concurrent call for the same merchant awaits the same initialization',
      () async {
        hostApi.pendingCompletion = Completer<void>();

        final first = gateway.initialize(_configuration);
        final second = gateway.initialize(_configuration);

        hostApi.pendingCompletion!.complete();
        await Future.wait([first, second]);

        expect(hostApi.calls, ['initialize']);
        expect(gateway.isInitialized, isTrue);
      },
    );

    test(
      'a concurrent call for a different merchant is rejected as alreadyInitialized',
      () async {
        hostApi.pendingCompletion = Completer<void>();
        final first = gateway.initialize(_configuration);

        await expectLater(
          gateway.initialize(
            const GatewayConfiguration(
              merchantId: 'OTHER',
              merchantName: 'My Store',
              merchantUrl: 'https://mystore.example',
              region: GatewayRegion.mtf,
            ),
          ),
          _throwsGatewayError(GatewayErrorCode.alreadyInitialized),
        );

        hostApi.pendingCompletion!.complete();
        await first;
      },
    );

    test('wallet settings can be added after initialization', () async {
      // They never reach the native SDK, so there is nothing to re-initialize.
      await gateway.initialize(
        const GatewayConfiguration(
          merchantId: 'TESTNBE000123',
          merchantName: 'My Store',
          merchantUrl: 'https://mystore.example',
          region: GatewayRegion.mtf,
        ),
      );

      await gateway.initialize(_configuration);

      expect(hostApi.calls, ['initialize']);
      // The new wallet settings are used by the next wallet request.
      await gateway.getAvailableWallet(_walletRequest);
      expect(hostApi.lastWalletRequest!.googlePayMerchantId, 'BCR2DN');
    });

    test(
      'a new challenge appearance after initialization is kept without a native call',
      () async {
        // The native SDKs apply the appearance once, at initialization.
        await initialize();

        await gateway.initialize(
          const GatewayConfiguration(
            merchantId: 'TESTNBE000123',
            merchantName: 'My Store',
            merchantUrl: 'https://mystore.example',
            region: GatewayRegion.mtf,
            wallet: WalletConfiguration(googlePayMerchantId: 'BCR2DN'),
            challengeUi: ChallengeUiCustomization(regularFontName: 'Cairo'),
          ),
        );

        expect(hostApi.calls, ['initialize']);
      },
    );

    test(
      'a different configuration after initialization is rejected',
      () async {
        await initialize();

        await expectLater(
          gateway.initialize(
            const GatewayConfiguration(
              merchantId: 'OTHER',
              merchantName: 'My Store',
              merchantUrl: 'https://mystore.example',
              region: GatewayRegion.mtf,
            ),
          ),
          _throwsGatewayError(GatewayErrorCode.alreadyInitialized),
        );
        expect(hostApi.calls, ['initialize']);
      },
    );
  });

  group('before initialization', () {
    test(
      'every operation fails with notInitialized without calling native code',
      () async {
        await expectLater(
          gateway.updateSessionWithCard(_session, _card),
          _throwsGatewayError(GatewayErrorCode.notInitialized),
        );
        await expectLater(
          gateway.updateSessionWithSecurityCode(_session, '100'),
          _throwsGatewayError(GatewayErrorCode.notInitialized),
        );
        await expectLater(
          gateway.authenticatePayer(_session),
          _throwsGatewayError(GatewayErrorCode.notInitialized),
        );
        await expectLater(
          gateway.getAvailableWallet(_walletRequest),
          _throwsGatewayError(GatewayErrorCode.notInitialized),
        );
        await expectLater(
          gateway.payWithDeviceWallet(_session, _walletRequest),
          _throwsGatewayError(GatewayErrorCode.notInitialized),
        );
        expect(hostApi.calls, isEmpty);
      },
    );
  });

  group('updateSessionWithCard', () {
    setUp(initialize);

    test('sends session, card and additional fields', () async {
      await gateway.updateSessionWithCard(
        _session,
        _card,
        additionalFields: GatewayFields()..setString('customer.email', 'a@b.c'),
      );

      expect(hostApi.lastSession!.id, 'SESSION0002');
      expect(hostApi.lastCard!.number, '5123450000000008');
      expect(hostApi.lastAdditionalFields!.single.key, 'customer.email');
    });

    test('invalid card fails without calling native code', () async {
      await expectLater(
        gateway.updateSessionWithCard(
          _session,
          const CardDetails(
            number: '123',
            expiryMonth: '01',
            expiryYear: '39',
            securityCode: '100',
          ),
        ),
        _throwsGatewayError(GatewayErrorCode.invalidArgument),
      );
      expect(hostApi.calls, ['initialize']);
    });

    test('native errors keep http status and code', () async {
      hostApi.nextError = PlatformException(
        code: errorCodeGatewayRejected,
        message: 'Rejected',
        details: <Object?, Object?>{errorDetailsHttpStatusCode: 400},
      );

      await expectLater(
        gateway.updateSessionWithCard(_session, _card),
        throwsA(
          isA<GatewayException>()
              .having((e) => e.code, 'code', GatewayErrorCode.gatewayRejected)
              .having((e) => e.httpStatusCode, 'httpStatusCode', 400),
        ),
      );
    });
  });

  group('updateSessionWithSecurityCode', () {
    setUp(initialize);

    test('sends session, security code and additional fields', () async {
      await gateway.updateSessionWithSecurityCode(
        _session,
        '100',
        additionalFields: GatewayFields()..setString('customer.email', 'a@b.c'),
      );

      expect(hostApi.calls, ['initialize', 'updateSessionWithSecurityCode']);
      expect(hostApi.lastSession!.id, 'SESSION0002');
      expect(hostApi.lastSecurityCode, '100');
      expect(hostApi.lastAdditionalFields!.single.key, 'customer.email');
    });

    test('never sends card details', () async {
      await gateway.updateSessionWithSecurityCode(_session, '100');

      expect(hostApi.lastCard, isNull);
    });

    test('an invalid security code fails without calling native code', () async {
      await expectLater(
        gateway.updateSessionWithSecurityCode(_session, '12'),
        _throwsGatewayError(GatewayErrorCode.invalidArgument),
      );
      expect(hostApi.calls, ['initialize']);
    });

    test('an invalid session fails without calling native code', () async {
      await expectLater(
        gateway.updateSessionWithSecurityCode(
          const PaymentSession(
            id: 'SESSION0002',
            orderId: 'ORDER-1',
            amount: '150.00',
            currency: 'EGP',
            apiVersion: '60',
          ),
          '100',
        ),
        _throwsGatewayError(GatewayErrorCode.invalidApiVersion),
      );
      expect(hostApi.calls, ['initialize']);
    });

    test('native errors keep http status and code', () async {
      hostApi.nextError = PlatformException(
        code: errorCodeGatewayRejected,
        message: 'Rejected',
        details: <Object?, Object?>{errorDetailsHttpStatusCode: 400},
      );

      await expectLater(
        gateway.updateSessionWithSecurityCode(_session, '100'),
        throwsA(
          isA<GatewayException>()
              .having((e) => e.code, 'code', GatewayErrorCode.gatewayRejected)
              .having((e) => e.httpStatusCode, 'httpStatusCode', 400),
        ),
      );
    });

    test('runs under the one-operation lock', () async {
      hostApi.pendingCompletion = Completer<void>();
      final first = gateway.updateSessionWithSecurityCode(_session, '100');

      await expectLater(
        gateway.authenticatePayer(_session),
        _throwsGatewayError(GatewayErrorCode.operationInProgress),
      );

      hostApi.pendingCompletion!.complete();
      await first;
    });
  });

  group('authenticatePayer', () {
    setUp(initialize);

    test(
      'generates a transaction id when none is given and returns it',
      () async {
        final result = await gateway.authenticatePayer(_session);

        expect(
          hostApi.lastAuthenticateRequest!.authenticationTransactionId,
          'generated-id',
        );
        expect(result, isA<AuthenticationProceed>());
        expect(result.authenticationTransactionId, 'generated-id');
      },
    );

    test('uses the transaction id provided by the app', () async {
      final result = await gateway.authenticatePayer(
        _session,
        authenticationTransactionId: 'AUTH-FROM-SERVER',
      );

      expect(
        hostApi.lastAuthenticateRequest!.authenticationTransactionId,
        'AUTH-FROM-SERVER',
      );
      expect(result.authenticationTransactionId, 'AUTH-FROM-SERVER');
    });

    test('a blank provided transaction id is rejected', () async {
      await expectLater(
        gateway.authenticatePayer(_session, authenticationTransactionId: ' '),
        _throwsGatewayError(GatewayErrorCode.invalidArgument),
      );
      expect(hostApi.calls, ['initialize']);
    });

    test('returns declines as results, not exceptions', () async {
      hostApi.authenticationResult.outcome =
          AuthenticationOutcomeMessage.cancelledByUser;

      final result = await gateway.authenticatePayer(_session);

      expect(
        result,
        isA<AuthenticationNotProceeded>().having(
          (r) => r.reason,
          'reason',
          AuthenticationDeclineReason.cancelledByUser,
        ),
      );
    });
  });

  group('device wallet', () {
    setUp(initialize);

    test(
      'availability uses the stored wallet configuration and no session',
      () async {
        final wallet = await gateway.getAvailableWallet(_walletRequest);

        expect(wallet, DeviceWallet.googlePay);
        expect(hostApi.lastWalletRequest!.session, isNull);
        expect(hostApi.lastWalletRequest!.googlePayMerchantId, 'BCR2DN');
        expect(hostApi.lastWalletRequest!.isTestEnvironment, isTrue);
      },
    );

    test('a zero amount is rejected before the sheet opens', () async {
      await expectLater(
        gateway.payWithDeviceWallet(
          const PaymentSession(
            id: 'SESSION0002',
            orderId: 'ORDER-1',
            amount: '0',
            currency: 'EGP',
            apiVersion: '72',
          ),
          _walletRequest,
        ),
        _throwsGatewayError(GatewayErrorCode.invalidArgument),
      );
      expect(hostApi.calls, ['initialize']);
    });

    test('payment sends the session and maps the result', () async {
      final result = await gateway.payWithDeviceWallet(
        _session,
        _walletRequest,
      );

      expect(hostApi.lastWalletRequest!.session!.id, 'SESSION0002');
      expect(result, isA<WalletPaymentCompleted>());
    });
  });

  group('one operation at a time', () {
    setUp(initialize);

    test(
      'a second operation while one is running fails with operationInProgress',
      () async {
        hostApi.pendingCompletion = Completer<void>();
        final first = gateway.updateSessionWithCard(_session, _card);

        await expectLater(
          gateway.authenticatePayer(_session),
          _throwsGatewayError(GatewayErrorCode.operationInProgress),
        );

        hostApi.pendingCompletion!.complete();
        await first;
        expect(hostApi.calls, ['initialize', 'updateSessionWithCard']);
      },
    );

    test(
      'the next operation is allowed once the running one completes',
      () async {
        await gateway.updateSessionWithCard(_session, _card);
        await gateway.authenticatePayer(_session);

        expect(hostApi.calls, [
          'initialize',
          'updateSessionWithCard',
          'authenticatePayer',
        ]);
      },
    );

    test('the lock is released when the running operation fails', () async {
      hostApi.nextError = PlatformException(code: errorCodeNetwork);
      await expectLater(
        gateway.updateSessionWithCard(_session, _card),
        _throwsGatewayError(GatewayErrorCode.network),
      );

      await gateway.updateSessionWithCard(_session, _card);

      expect(
        hostApi.calls.where((c) => c == 'updateSessionWithCard'),
        hasLength(2),
      );
    });

    test(
      'the wallet availability check is not blocked by a running operation',
      () async {
        hostApi.pendingCompletion = Completer<void>();
        final payment = gateway.updateSessionWithCard(_session, _card);

        final availability = gateway.getAvailableWallet(_walletRequest);
        hostApi.pendingCompletion!.complete();

        expect(await availability, DeviceWallet.googlePay);
        await payment;
      },
    );
  });
}
