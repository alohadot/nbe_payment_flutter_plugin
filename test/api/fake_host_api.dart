// The generated host API names these members `pigeonVar_*`; implementing it requires them.
// ignore_for_file: non_constant_identifier_names

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:nbe_payment_flutter_plugin/src/generated/payment_api.g.dart';

/// Test double for the generated host API. It records calls and lets each test decide how
/// the "native side" answers. Lives under test/ only; it is never shipped.
class FakeHostApi implements NbeGatewayHostApi {
  final List<String> calls = [];

  InitializeRequestMessage? lastInitializeRequest;
  SessionMessage? lastSession;
  CardMessage? lastCard;
  String? lastSecurityCode;
  List<GatewayFieldMessage>? lastAdditionalFields;
  AuthenticateRequestMessage? lastAuthenticateRequest;
  WalletRequestMessage? lastWalletRequest;

  /// When set, the next native call throws this error.
  PlatformException? nextError;

  /// When set, native calls wait for this completer before answering.
  Completer<void>? pendingCompletion;

  AuthenticationResultMessage authenticationResult =
      AuthenticationResultMessage(
        outcome: AuthenticationOutcomeMessage.proceed,
        authenticationPerformed: true,
        challengePerformed: false,
        authenticationTransactionId: 'set-by-request',
      );

  DeviceWallet availableWallet = DeviceWallet.googlePay;

  WalletResultMessage walletResult = WalletResultMessage(
    outcome: WalletOutcomeMessage.completed,
    wallet: DeviceWallet.googlePay,
  );

  @override
  BinaryMessenger? get pigeonVar_binaryMessenger => null;

  @override
  String get pigeonVar_messageChannelSuffix => '';

  @override
  Future<void> initialize(InitializeRequestMessage request) async {
    calls.add('initialize');
    lastInitializeRequest = request;
    await _answer();
  }

  @override
  Future<void> updateSessionWithCard(
    SessionMessage session,
    CardMessage card,
    List<GatewayFieldMessage>? additionalFields,
  ) async {
    calls.add('updateSessionWithCard');
    lastSession = session;
    lastCard = card;
    lastAdditionalFields = additionalFields;
    await _answer();
  }

  @override
  Future<void> updateSessionWithSecurityCode(
    SessionMessage session,
    String securityCode,
    List<GatewayFieldMessage>? additionalFields,
  ) async {
    calls.add('updateSessionWithSecurityCode');
    lastSession = session;
    lastSecurityCode = securityCode;
    lastAdditionalFields = additionalFields;
    await _answer();
  }

  @override
  Future<AuthenticationResultMessage> authenticatePayer(
    AuthenticateRequestMessage request,
  ) async {
    calls.add('authenticatePayer');
    lastAuthenticateRequest = request;
    await _answer();
    // Native implementations echo the identifier they received.
    authenticationResult.authenticationTransactionId =
        request.authenticationTransactionId;
    return authenticationResult;
  }

  @override
  Future<DeviceWallet> getAvailableWallet(WalletRequestMessage request) async {
    calls.add('getAvailableWallet');
    lastWalletRequest = request;
    await _answer();
    return availableWallet;
  }

  @override
  Future<WalletResultMessage> payWithDeviceWallet(
    WalletRequestMessage request,
  ) async {
    calls.add('payWithDeviceWallet');
    lastWalletRequest = request;
    await _answer();
    return walletResult;
  }

  Future<void> _answer() async {
    final completion = pendingCompletion;
    if (completion != null) {
      await completion.future;
    }
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
  }
}
