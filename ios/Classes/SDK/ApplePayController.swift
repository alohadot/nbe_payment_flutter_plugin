import Gateway
import PassKit

/// Apple Pay flow on iOS: availability check, payment sheet, and storing the resulting token in
/// the gateway session.
///
/// The Gateway iOS SDK has no Apple Pay helper; its integration guide leaves the PassKit flow to
/// the app and only requires the token to be sent with `updateSession`. The session is updated
/// while the sheet is still open, so the sheet can show success or failure, as Apple requires.
///
/// All methods and PassKit delegate callbacks run on the main thread.
final class ApplePayController: NSObject, PKPaymentAuthorizationControllerDelegate {
  private final class ActivePayment {
    let session: SessionMessage
    let completion: (Result<WalletResultMessage, Error>) -> Void
    /// Set once the payer authorized and the session update finished.
    var result: Result<WalletResultMessage, Error>?

    init(session: SessionMessage, completion: @escaping (Result<WalletResultMessage, Error>) -> Void) {
      self.session = session
      self.completion = completion
    }
  }

  /// Apple expects the authorization handler to be called within about 30 seconds, and the
  /// session update has no timeout of its own, so the sheet is failed before Apple's own
  /// deadline instead of freezing on the spinner.
  private static let sessionUpdateTimeout: TimeInterval = 20

  private var activeController: PKPaymentAuthorizationController?
  private var activePayment: ActivePayment?

  func availableWallet(request: WalletRequestMessage) -> Result<DeviceWallet, Error> {
    guard hasMerchantIdentifier(request) else {
      return .failure(missingMerchantIdentifierError())
    }
    guard PKPaymentAuthorizationController.canMakePayments() else {
      return .success(.none)
    }
    let networks = request.supportedNetworks.map(toPaymentNetwork)
    // The same capability the payment request asks for, so availability cannot report a wallet
    // that the sheet would then refuse.
    return .success(
      PKPaymentAuthorizationController.canMakePayments(
        usingNetworks: networks, capabilities: .capability3DS) ? .applePay : .none)
  }

  func pay(
    request: WalletRequestMessage,
    completion: @escaping (Result<WalletResultMessage, Error>) -> Void
  ) {
    guard let session = request.session else {
      completion(
        .failure(
          gatewayBridgeError(
            code: errorCodeInvalidArgument,
            message: "A session is required for a wallet payment.")))
      return
    }
    guard let merchantIdentifier = request.applePayMerchantIdentifier, hasMerchantIdentifier(request)
    else {
      completion(.failure(missingMerchantIdentifierError()))
      return
    }
    guard activeController == nil else {
      completion(
        .failure(
          gatewayBridgeError(
            code: errorCodeOperationInProgress,
            message: "An Apple Pay payment is already in progress.")))
      return
    }
    guard PKPaymentAuthorizationController.canMakePayments() else {
      completion(
        .failure(
          gatewayBridgeError(
            code: errorCodeWalletUnavailable,
            message: "Apple Pay is not available on this device.")))
      return
    }

    let paymentRequest = PKPaymentRequest()
    paymentRequest.merchantIdentifier = merchantIdentifier
    paymentRequest.countryCode = request.countryCode
    // Taken from the gateway session so the sheet shows exactly what will be charged.
    paymentRequest.currencyCode = session.currency
    paymentRequest.supportedNetworks = request.supportedNetworks.map(toPaymentNetwork)
    paymentRequest.merchantCapabilities = .capability3DS
    paymentRequest.paymentSummaryItems = [
      PKPaymentSummaryItem(
        label: request.merchantDisplayName,
        amount: NSDecimalNumber(string: session.amount),
        type: .final)
    ]

    let controller = PKPaymentAuthorizationController(paymentRequest: paymentRequest)
    controller.delegate = self
    activeController = controller
    activePayment = ActivePayment(session: session, completion: completion)

    controller.present { [weak self] presented in
      guard !presented else { return }
      DispatchQueue.main.async {
        self?.finish(
          with: .failure(
            gatewayBridgeError(
              code: errorCodeWalletConfigurationInvalid,
              message:
                "The Apple Pay sheet could not be presented. Check the merchant identifier and the Apple Pay capability of the app."
            )))
      }
    }
  }

  // MARK: PKPaymentAuthorizationControllerDelegate

  // PassKit does not document a delivery queue for these callbacks, and everything they touch
  // (the active payment, UIKit) belongs to the main thread.
  func paymentAuthorizationController(
    _ controller: PKPaymentAuthorizationController,
    didAuthorizePayment payment: PKPayment,
    handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
  ) {
    onMainThread {
      self.authorize(payment: payment, handler: completion)
    }
  }

  private func authorize(
    payment: PKPayment,
    handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
  ) {
    guard let active = activePayment else {
      completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
      return
    }
    // Empty payment data decodes to an empty string rather than nil, which the gateway would
    // reject with a confusing error.
    guard let token = String(data: payment.token.paymentData, encoding: .utf8), !token.isEmpty
    else {
      active.result = .failure(
        gatewayBridgeError(
          code: errorCodeWalletFailed,
          message: "The Apple Pay token could not be read."))
      completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
      return
    }
    let cardDescription = payment.token.paymentMethod.displayName

    var hasAnswered = false
    let answer: (Result<WalletResultMessage, Error>, PKPaymentAuthorizationStatus) -> Void = {
      result, status in
      guard !hasAnswered else { return }
      hasAnswered = true
      active.result = result
      completion(PKPaymentAuthorizationResult(status: status, errors: nil))
    }

    Gateway.loggingEnabled = false
    Gateway.logRecorder = nil
    // The token is only handed to the SDK; it is never logged or returned to Flutter.
    GatewayAPI.shared.updateSession(
      active.session.id,
      apiVersion: active.session.apiVersion,
      payload: buildApplePayTokenPayload(token: token)
    ) { result in
      self.onMainThread {
        switch result {
        case .success:
          answer(
            .success(
              WalletResultMessage(
                outcome: .completed, wallet: .applePay, cardDescription: cardDescription)),
            .success)
        case .failure(let error):
          answer(.failure(gatewayRequestBridgeError(error)), .failure)
        }
      }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + Self.sessionUpdateTimeout) {
      answer(
        .failure(
          gatewayBridgeError(
            code: errorCodeNetwork,
            message: "Storing the Apple Pay token in the session timed out.")),
        .failure)
    }
  }

  func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
    onMainThread {
      controller.dismiss {
        self.onMainThread {
          // No result means the payer closed the sheet without a successful authorization.
          let result =
            self.activePayment?.result
            ?? .success(WalletResultMessage(outcome: .cancelled, wallet: .applePay))
          self.finish(with: result)
        }
      }
    }
  }

  /// Dismisses the sheet and fails the payment, for when the engine goes away.
  func abortPendingPayment() {
    guard activePayment != nil else { return }
    let controller = activeController
    finish(
      with: .failure(
        gatewayBridgeError(
          code: errorCodeUiUnavailable,
          message: "The Flutter engine was detached before Apple Pay finished.")))
    controller?.dismiss(completion: nil)
  }

  private func onMainThread(_ action: @escaping () -> Void) {
    if Thread.isMainThread {
      action()
    } else {
      DispatchQueue.main.async(execute: action)
    }
  }

  // MARK: Helpers

  private func finish(with result: Result<WalletResultMessage, Error>) {
    let active = activePayment
    activePayment = nil
    activeController = nil
    active?.completion(result)
  }

  private func hasMerchantIdentifier(_ request: WalletRequestMessage) -> Bool {
    guard let identifier = request.applePayMerchantIdentifier else { return false }
    return !identifier.trimmingCharacters(in: .whitespaces).isEmpty
  }

  private func missingMerchantIdentifierError() -> GatewayBridgeError {
    return gatewayBridgeError(
      code: errorCodeWalletConfigurationInvalid,
      message: "An Apple Pay merchant identifier is required. Set WalletConfiguration.applePayMerchantIdentifier."
    )
  }
}

func toPaymentNetwork(_ network: CardNetwork) -> PKPaymentNetwork {
  switch network {
  case .visa: return .visa
  case .mastercard: return .masterCard
  case .amex: return .amex
  case .discover: return .discover
  case .jcb: return .JCB
  }
}
