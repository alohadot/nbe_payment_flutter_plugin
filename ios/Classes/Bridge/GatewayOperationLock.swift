import Foundation

/// Allows one gateway operation at a time, for the whole process.
///
/// The lock is process-wide, not per Flutter engine, because the state it protects is: the
/// Gateway SDK objects (`GatewaySDK.shared`, `GatewayAPI.shared`, `AuthenticationHandler.shared`)
/// are singletons, so two engines in one app must not authenticate at the same time.
///
/// Main-thread only; no locking needed.
enum GatewayOperationLock {
  /// Fails the running operation, if any. Set while an operation holds the lock.
  private static var failRunningOperation: ((GatewayBridgeError) -> Void)?

  static var isBusy: Bool { failRunningOperation != nil }

  static func acquire(failOperation: @escaping (GatewayBridgeError) -> Void) {
    failRunningOperation = failOperation
  }

  static func release() {
    failRunningOperation = nil
  }

  /// Fails the running operation and releases the lock.
  ///
  /// Used when the operation can no longer finish, for example when the engine goes away while
  /// a wallet sheet is open: without this the lock would stay held for the lifetime of the
  /// process and every later call would report "operation in progress".
  static func abortRunningOperation(_ error: GatewayBridgeError) {
    guard let failOperation = failRunningOperation else { return }
    failRunningOperation = nil
    failOperation(error)
  }

  static func resetForTesting() {
    failRunningOperation = nil
  }
}
