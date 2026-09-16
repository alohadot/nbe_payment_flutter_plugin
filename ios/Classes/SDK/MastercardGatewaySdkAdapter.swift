import Foundation
import Gateway
import UIKit

/// `GatewaySdkAdapter` backed by the Mastercard Gateway iOS SDK.
final class MastercardGatewaySdkAdapter: GatewaySdkAdapter {
  // Mirrors the SDK's process-wide lifetime: `GatewaySDK.shared` stays initialized across a
  // Flutter hot restart or a second engine, and the SDK offers no way to ask whether it is.
  private static var lastSuccessfulInitializeRequest: InitializeRequestMessage?

  private let challengeHost = ChallengePresentationHost()
  private let applePay = ApplePayController()

  private var isInitialized: Bool { Self.lastSuccessfulInitializeRequest != nil }

  func initialize(
    request: InitializeRequestMessage,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    // Only the merchant identity is compared: challenge appearance and locale are applied by
    // the SDK at initialization and cannot be changed afterwards, so a new value for them must
    // not turn a repeated initialize into a hard failure.
    if let previousRequest = Self.lastSuccessfulInitializeRequest {
      completion(
        previousRequest.describesSameMerchant(as: request)
          ? .success(())
          : .failure(
            gatewayBridgeError(
              code: errorCodeAlreadyInitialized,
              message: "The Gateway SDK is already initialized with a different configuration.")))
      return
    }

    // The SDK can print HTTP traffic; it must stay off so card data never reaches the console.
    // Both switches are process-wide and writable by anything in the app, so they are set
    // again before every call below.
    Gateway.loggingEnabled = false
    Gateway.logRecorder = nil

    // The iOS SDK initializes synchronously and reports no failure; problems surface later as
    // `AuthenticationError.notInitialized` or gateway errors.
    GatewaySDK.shared.initialize(
      merchantId: request.merchantId,
      region: toSdkRegion(request.region),
      locale: request.challengeLocale ?? Locale.current.identifier,
      challengeTheme: request.challengeUi.map(toChallengeTheme) ?? ChallengeTheme())

    Self.lastSuccessfulInitializeRequest = request
    completion(.success(()))
  }

  func updateSessionWithCard(
    session: SessionMessage,
    card: CardMessage,
    additionalFields: [GatewayFieldMessage]?,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    guard isInitialized else {
      completion(.failure(notInitializedError()))
      return
    }

    let payload: GatewayMap
    do {
      payload = try buildUpdateSessionWithCardPayload(card: card, additionalFields: additionalFields)
    } catch {
      completion(.failure(invalidFieldError(error)))
      return
    }

    Gateway.loggingEnabled = false
    Gateway.logRecorder = nil
    // The payload holds card data: it is only handed to the SDK, never logged or stored.
    GatewayAPI.shared.updateSession(session.id, apiVersion: session.apiVersion, payload: payload) {
      result in
      switch result {
      case .success:
        completion(.success(()))
      case .failure(let error):
        completion(.failure(gatewayRequestBridgeError(error)))
      }
    }
  }

  func authenticatePayer(
    request: AuthenticateRequestMessage,
    completion: @escaping (Result<AuthenticationResultMessage, Error>) -> Void
  ) {
    guard isInitialized else {
      completion(.failure(notInitializedError()))
      return
    }

    let payerFields: GatewayMap?
    let initiateFields: GatewayMap?
    do {
      payerFields = try buildGatewayFieldsPayload(request.authenticatePayerFields)
      initiateFields = try buildGatewayFieldsPayload(request.ios?.initiateAuthenticationFields)
    } catch {
      completion(.failure(invalidFieldError(error)))
      return
    }

    let session = request.session
    let transactionId = request.authenticationTransactionId

    // Captured strongly on purpose: the adapter lives as long as the plugin, and every path
    // below must reach `completion`, otherwise the bridge would stay locked.
    challengeHost.present { navigationController in
      guard let navigationController = navigationController else {
        completion(
          .failure(
            gatewayBridgeError(
              code: errorCodeUiUnavailable,
              message: "No visible view controller is available to present 3-D Secure authentication.")))
        return
      }

      var authenticationRequest = AuthenticationRequest(
        navController: navigationController,
        apiVersion: session.apiVersion,
        sessionId: session.id,
        orderId: session.orderId,
        transactionId: transactionId,
        theme: request.ios?.challengeUi.map(toChallengeTheme))
      authenticationRequest.additionalAuthenticatePayerParameters = payerFields
      authenticationRequest.additionalInitiateAuthenticationParameters = initiateFields
      if let locale = request.ios?.challengeLocale {
        authenticationRequest.locale = locale
      }

      Gateway.loggingEnabled = false
      Gateway.logRecorder = nil
      AuthenticationHandler.shared.authenticate(authenticationRequest) { response in
        // The SDK may complete on a background queue; UI work and the reply need the main one.
        DispatchQueue.main.async {
          self.challengeHost.dismiss {
            completion(toAuthenticationResult(response, authenticationTransactionId: transactionId))
          }
        }
      }
    }
  }

  func getAvailableWallet(
    request: WalletRequestMessage,
    completion: @escaping (Result<DeviceWallet, Error>) -> Void
  ) {
    completion(applePay.availableWallet(request: request))
  }

  func payWithDeviceWallet(
    request: WalletRequestMessage,
    completion: @escaping (Result<WalletResultMessage, Error>) -> Void
  ) {
    guard isInitialized else {
      completion(.failure(notInitializedError()))
      return
    }
    applePay.pay(request: request, completion: completion)
  }

  func abortPendingOperations() {
    challengeHost.dismissWithoutWaiting()
    applePay.abortPendingPayment()
  }

  private func notInitializedError() -> GatewayBridgeError {
    return gatewayBridgeError(code: errorCodeNotInitialized, message: "The Gateway SDK is not initialized.")
  }

  private func invalidFieldError(_ error: Error) -> GatewayBridgeError {
    if let fieldError = error as? GatewayFieldWithoutValueError {
      return gatewayBridgeError(
        code: errorCodeInvalidArgument,
        message: "Gateway field \"\(fieldError.key)\" has no value.")
    }
    return gatewayBridgeError(
      code: errorCodeInvalidArgument,
      message: "Invalid gateway field.",
      nativeDetails: String(describing: type(of: error)))
  }
}

extension InitializeRequestMessage {
  /// Whether both requests initialize the SDK for the same merchant. Challenge appearance and
  /// locale are ignored: the SDK applies them once, at initialization.
  func describesSameMerchant(as other: InitializeRequestMessage) -> Bool {
    return merchantId == other.merchantId && merchantName == other.merchantName
      && merchantUrl == other.merchantUrl && region == other.region
  }
}
