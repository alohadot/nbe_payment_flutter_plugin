import Foundation

/// Implements the Pigeon host API on iOS.
///
/// Responsibilities kept here, and nothing SDK-specific:
/// - allow one gateway operation at a time;
/// - answer Flutter exactly once per call, always on the main thread (the iOS Gateway SDK
///   completes on background queues).
///
/// Pigeon invokes these methods on the main thread and every reply is delivered on the main
/// thread, so the state below needs no locking.
final class GatewayHostApiImpl: NbeGatewayHostApi {
  private let sdkAdapter: GatewaySdkAdapter
  private var isOperationInProgress = false

  init(sdkAdapter: GatewaySdkAdapter) {
    self.sdkAdapter = sdkAdapter
  }

  func initialize(
    request: InitializeRequestMessage,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    runExclusively(completion) { complete in
      self.sdkAdapter.initialize(request: request, completion: complete)
    }
  }

  func updateSessionWithCard(
    session: SessionMessage,
    card: CardMessage,
    additionalFields: [GatewayFieldMessage]?,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    runExclusively(completion) { complete in
      self.sdkAdapter.updateSessionWithCard(
        session: session, card: card, additionalFields: additionalFields, completion: complete)
    }
  }

  func authenticatePayer(
    request: AuthenticateRequestMessage,
    completion: @escaping (Result<AuthenticationResultMessage, Error>) -> Void
  ) {
    runExclusively(completion) { complete in
      self.sdkAdapter.authenticatePayer(request: request, completion: complete)
    }
  }

  // Availability presents no UI and changes no session, so it may run alongside another
  // operation (same rule as the Dart layer and Android).
  func getAvailableWallet(
    request: WalletRequestMessage,
    completion: @escaping (Result<DeviceWallet, Error>) -> Void
  ) {
    runOnce(completion) { complete in
      self.sdkAdapter.getAvailableWallet(request: request, completion: complete)
    }
  }

  func payWithDeviceWallet(
    request: WalletRequestMessage,
    completion: @escaping (Result<WalletResultMessage, Error>) -> Void
  ) {
    runExclusively(completion) { complete in
      self.sdkAdapter.payWithDeviceWallet(request: request, completion: complete)
    }
  }

  private func runExclusively<T>(
    _ completion: @escaping (Result<T, Error>) -> Void,
    _ operation: (@escaping (Result<T, Error>) -> Void) -> Void
  ) {
    if isOperationInProgress {
      completion(
        .failure(
          gatewayBridgeError(
            code: errorCodeOperationInProgress,
            message: "Another gateway operation is still running.")))
      return
    }

    isOperationInProgress = true
    runOnce(
      { [weak self] result in
        self?.isOperationInProgress = false
        completion(result)
      }, operation)
  }

  /// Replies exactly once, on the main thread.
  private func runOnce<T>(
    _ completion: @escaping (Result<T, Error>) -> Void,
    _ operation: (@escaping (Result<T, Error>) -> Void) -> Void
  ) {
    var isCompleted = false
    operation { result in
      let deliver = {
        // An SDK that reports twice must not produce a second reply to Flutter.
        guard !isCompleted else { return }
        isCompleted = true
        completion(result)
      }
      if Thread.isMainThread {
        deliver()
      } else {
        DispatchQueue.main.async(execute: deliver)
      }
    }
  }
}
