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

  /// Whoever started the running operation; one host API per Flutter engine.
  private static weak var runningOperationOwner: AnyObject?

  static var isBusy: Bool { failRunningOperation != nil }

  static func acquire(owner: AnyObject, failOperation: @escaping (GatewayBridgeError) -> Void) {
    runningOperationOwner = owner
    failRunningOperation = failOperation
  }

  static func release() {
    runningOperationOwner = nil
    failRunningOperation = nil
  }

  /// Fails the running operation and releases the lock, if `owner` started it.
  ///
  /// Used when the operation can no longer finish, for example when the engine goes away while
  /// a wallet sheet is open: without this the lock would stay held for the lifetime of the
  /// process and every later call would report "operation in progress".
  ///
  /// An operation started by another owner is left alone: apps commonly attach and detach a
  /// background engine (push messages, background work) while the main engine is paying.
  static func abortRunningOperation(owner: AnyObject, _ error: GatewayBridgeError) {
    guard runningOperationOwner === owner, let failOperation = failRunningOperation else { return }
    release()
    failOperation(error)
  }

  static func resetForTesting() {
    release()
  }
}
