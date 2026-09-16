import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show PlatformException;

import '../generated/payment_api.g.dart';
import '../mappers/authentication_mapper.dart';
import '../mappers/configuration_mapper.dart';
import '../mappers/gateway_error_mapper.dart';
import '../mappers/session_mapper.dart';
import '../mappers/wallet_mapper.dart';
import '../models/authentication.dart';
import '../models/card_details.dart';
import '../models/device_wallet.dart';
import '../models/gateway_configuration.dart';
import '../models/gateway_exception.dart';
import '../models/gateway_fields.dart';
import '../models/payment_session.dart';
import '../validation/input_validation.dart';
import 'authentication_transaction_id.dart';

/// Entry point to the NBE payment gateway on Android and iOS.
///
/// Typical flow:
/// 1. [initialize] once with the merchant configuration.
/// 2. Get a [PaymentSession] from your merchant server.
/// 3. Add the payment method: [updateSessionWithCard] or [payWithDeviceWallet].
/// 4. [authenticatePayer] (3-D Secure) and send the result to your server.
/// 5. The merchant server completes the payment with the gateway.
///
/// Only one operation runs at a time; a call made while another is running fails with
/// [GatewayErrorCode.operationInProgress]. Technical failures are thrown as
/// [GatewayException]; payment outcomes are returned as results.
class NbePaymentGateway {
  /// Returns the shared gateway. The native SDKs are process-wide singletons, so every
  /// call returns the same instance.
  factory NbePaymentGateway() => _shared;

  /// Creates an isolated gateway backed by [hostApi], for tests only.
  @visibleForTesting
  NbePaymentGateway.withHostApi(
    NbeGatewayHostApi hostApi, {
    String Function()? generateTransactionId,
  }) : this._(
         hostApi,
         generateTransactionId ?? generateAuthenticationTransactionId,
       );

  NbePaymentGateway._(this._hostApi, this._generateTransactionId);

  static final NbePaymentGateway _shared = NbePaymentGateway._(
    NbeGatewayHostApi(),
    generateAuthenticationTransactionId,
  );

  final NbeGatewayHostApi _hostApi;
  final String Function() _generateTransactionId;

  GatewayConfiguration? _configuration;

  /// Set while an `initialize` call is running, so concurrent callers can await the same one.
  Future<void>? _initialization;
  InitializeRequestMessage? _initializingRequest;

  bool _isOperationInProgress = false;

  /// Whether [initialize] completed in this Dart isolate.
  ///
  /// The native SDKs stay initialized for the lifetime of the app process, so this can be
  /// `false` while the native side is still initialized (for example after a hot restart).
  bool get isInitialized => _configuration != null;

  /// Initializes the native SDK.
  ///
  /// Only the merchant identity (merchant, region) can be set once per app process. Calling
  /// this again for the same merchant keeps the new configuration and completes without
  /// another native call, so an app can initialize early and add wallet identifiers later.
  /// Calling it while the same initialization is still running awaits that one. Calling it for
  /// a different merchant or region throws [GatewayErrorCode.alreadyInitialized].
  ///
  /// The challenge appearance and language are applied by the native SDKs at initialization
  /// and cannot be changed afterwards: a new value is kept for later calls but the running SDK
  /// keeps the first one. On iOS, `AuthenticationOptions.ios` can override them per call.
  Future<void> initialize(GatewayConfiguration configuration) async {
    validateConfiguration(configuration);
    final request = toInitializeRequestMessage(configuration);

    final currentConfiguration = _configuration;
    if (currentConfiguration != null) {
      if (_describesSameMerchant(currentConfiguration, configuration)) {
        _configuration = configuration;
        return;
      }
      throw const GatewayException(
        code: GatewayErrorCode.alreadyInitialized,
        message:
            'The gateway is already initialized with a different configuration.',
      );
    }

    final runningInitialization = _initialization;
    if (runningInitialization != null) {
      final initializingRequest = _initializingRequest;
      if (initializingRequest != null &&
          _describesSameMerchantRequest(initializingRequest, request)) {
        return runningInitialization;
      }
      throw const GatewayException(
        code: GatewayErrorCode.alreadyInitialized,
        message:
            'The gateway is being initialized with a different configuration.',
      );
    }

    final initialization = _initializeNative(request, configuration);
    _initialization = initialization;
    _initializingRequest = request;
    try {
      await initialization;
    } finally {
      _initialization = null;
      _initializingRequest = null;
    }
  }

  // Challenge appearance, locale and wallet settings are deliberately not compared: the native
  // SDKs apply the first two once at initialization, and never see the third.
  static bool _describesSameMerchant(
    GatewayConfiguration a,
    GatewayConfiguration b,
  ) =>
      a.merchantId == b.merchantId &&
      a.merchantName == b.merchantName &&
      a.merchantUrl == b.merchantUrl &&
      a.region == b.region;

  static bool _describesSameMerchantRequest(
    InitializeRequestMessage a,
    InitializeRequestMessage b,
  ) =>
      a.merchantId == b.merchantId &&
      a.merchantName == b.merchantName &&
      a.merchantUrl == b.merchantUrl &&
      a.region == b.region;

  Future<void> _initializeNative(
    InitializeRequestMessage request,
    GatewayConfiguration configuration,
  ) async {
    await _runExclusively(() => _hostApi.initialize(request));
    _configuration = configuration;
  }

  /// Stores the payer's card in the gateway [session].
  ///
  /// [additionalFields] can carry extra session fields such as billing address or
  /// customer details.
  Future<void> updateSessionWithCard(
    PaymentSession session,
    CardDetails card, {
    GatewayFields? additionalFields,
  }) async {
    _requireInitialized();
    validateSession(session);
    validateCard(card);

    await _runExclusively(
      () => _hostApi.updateSessionWithCard(
        toSessionMessage(session),
        toCardMessage(card),
        toGatewayFieldMessages(additionalFields),
      ),
    );
  }

  /// Authenticates the payer with 3-D Secure. May present the issuer's challenge screen.
  ///
  /// A new [authenticationTransactionId] is generated when none is given. Either way, the
  /// identifier used is returned in the result and must be sent to the merchant server
  /// for the payment request.
  Future<AuthenticationResult> authenticatePayer(
    PaymentSession session, {
    String? authenticationTransactionId,
    AuthenticationOptions? options,
  }) async {
    _requireInitialized();
    validateSession(session);
    final transactionId =
        authenticationTransactionId ?? _generateTransactionId();
    validateAuthenticationTransactionId(transactionId);

    final message = await _runExclusively(
      () => _hostApi.authenticatePayer(
        toAuthenticateRequestMessage(
          session,
          authenticationTransactionId: transactionId,
          options: options,
        ),
      ),
    );
    return toAuthenticationResult(message);
  }

  /// Reports which device wallet can be used for [request] on this device.
  ///
  /// This check does not present any UI, so it may run while another operation is in
  /// progress.
  Future<DeviceWallet> getAvailableWallet(WalletPaymentRequest request) async {
    final configuration = _requireInitialized();
    validateWalletRequest(request);

    return _callNative(
      () => _hostApi.getAvailableWallet(
        toWalletRequestMessage(request, configuration: configuration),
      ),
    );
  }

  /// Shows the device wallet sheet (Google Pay on Android, Apple Pay on iOS) and stores the
  /// authorized wallet payment in the gateway [session].
  Future<WalletPaymentResult> payWithDeviceWallet(
    PaymentSession session,
    WalletPaymentRequest request,
  ) async {
    final configuration = _requireInitialized();
    validateSession(session);
    validateWalletRequest(request);
    validateWalletChargeableSession(session);

    final message = await _runExclusively(
      () => _hostApi.payWithDeviceWallet(
        toWalletRequestMessage(
          request,
          configuration: configuration,
          session: session,
        ),
      ),
    );
    return toWalletPaymentResult(message);
  }

  GatewayConfiguration _requireInitialized() {
    final configuration = _configuration;
    if (configuration == null) {
      throw const GatewayException(
        code: GatewayErrorCode.notInitialized,
        message: 'Call initialize before using the gateway.',
      );
    }
    return configuration;
  }

  // The native side enforces the same rule; checking here as well gives a consistent error
  // without a round trip. The check-and-set is synchronous, so it cannot race in Dart.
  Future<T> _runExclusively<T>(Future<T> Function() operation) async {
    if (_isOperationInProgress) {
      throw const GatewayException(
        code: GatewayErrorCode.operationInProgress,
        message: 'Another gateway operation is still running.',
      );
    }
    _isOperationInProgress = true;
    try {
      return await _callNative(operation);
    } finally {
      _isOperationInProgress = false;
    }
  }

  Future<T> _callNative<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on PlatformException catch (error) {
      throw toGatewayException(error);
    }
  }
}
