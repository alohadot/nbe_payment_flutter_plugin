import Foundation

/// Boundary between the Pigeon bridge and the Mastercard Gateway iOS SDK.
///
/// Implementations own every SDK-specific concern: SDK types, completion queues, UI
/// presentation and the translation of SDK failures into channel errors. Failures are
/// delivered as `GatewayBridgeError`.
///
/// Methods are called on the main thread. Completions may be called on any thread; the bridge
/// moves them to the main thread.
protocol GatewaySdkAdapter: AnyObject {
  func initialize(
    request: InitializeRequestMessage,
    completion: @escaping (Result<Void, Error>) -> Void)

  /// Stores the card in the gateway session. Must not log or retain the card.
  func updateSessionWithCard(
    session: SessionMessage,
    card: CardMessage,
    additionalFields: [GatewayFieldMessage]?,
    completion: @escaping (Result<Void, Error>) -> Void)

  /// Stores only the security code in a session that already holds a card. No other
  /// `sourceOfFunds` field is sent, so the stored card is left untouched. Must not log or
  /// retain the security code.
  func updateSessionWithSecurityCode(
    session: SessionMessage,
    securityCode: String,
    additionalFields: [GatewayFieldMessage]?,
    completion: @escaping (Result<Void, Error>) -> Void)

  /// Runs 3-D Secure payer authentication. May present the issuer challenge screen.
  func authenticatePayer(
    request: AuthenticateRequestMessage,
    completion: @escaping (Result<AuthenticationResultMessage, Error>) -> Void)

  /// Reports whether Apple Pay can be used. Presents no UI.
  func getAvailableWallet(
    request: WalletRequestMessage,
    completion: @escaping (Result<DeviceWallet, Error>) -> Void)

  /// Shows the Apple Pay sheet and stores the resulting token in the session.
  func payWithDeviceWallet(
    request: WalletRequestMessage,
    completion: @escaping (Result<WalletResultMessage, Error>) -> Void)

  /// Takes down any native screen this adapter presented and fails what waits for it, because
  /// the engine is going away and the result can no longer be delivered.
  func abortPendingOperations()
}
