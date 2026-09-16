import Foundation

/// Implements the Pigeon host API on iOS.
///
/// Responsibilities kept here, and nothing SDK-specific:
/// - allow one gateway operation at a time (through the process-wide `GatewayOperationLock`);
/// - answer Flutter exactly once per call, always on the main thread (the iOS Gateway SDK
///   completes on background queues).
///
/// Pigeon invokes these methods on the main thread and every reply is delivered on the main
/// thread, so the state below needs no locking.
final class GatewayHostApiImpl: NbeGatewayHostApi {
  private let sdkAdapter: GatewaySdkAdapter

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

  /// Called when the Flutter engine detaches: takes down native screens and fails a running
  /// operation, so the lock is not held by a call whose reply can no longer be delivered.
  func dispose() {
    sdkAdapter.abortPendingOperations()
    GatewayOperationLock.abortRunningOperation(
      gatewayBridgeError(
        code: errorCodeUnknown,
        message: "The Flutter engine was detached before the operation finished."))
  }

  private func runExclusively<T>(
    _ completion: @escaping (Result<T, Error>) -> Void,
    _ operation: ((Result<T, Error>) -> Void) -> Void
  ) {
    if GatewayOperationLock.isBusy {
      completion(
        .failure(
          gatewayBridgeError(
            code: errorCodeOperationInProgress,
            message: "Another gateway operation is still running.")))
      return
    }

    let complete = singleReply { (result: Result<T, Error>) in
      GatewayOperationLock.release()
      completion(result)
    }
    GatewayOperationLock.acquire { error in complete(.failure(error)) }
    operation(complete)
  }

  /// Replies exactly once, on the main thread.
  private func runOnce<T>(
    _ completion: @escaping (Result<T, Error>) -> Void,
    _ operation: ((Result<T, Error>) -> Void) -> Void
  ) {
    operation(singleReply(completion))
  }

  private func singleReply<T>(
    _ completion: @escaping (Result<T, Error>) -> Void
  ) -> (Result<T, Error>) -> Void {
    var isCompleted = false
    return { result in
      let deliver = {
        // An SDK that reports twice, or an abort racing the SDK's own answer, must not produce
        // a second reply to Flutter.
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
