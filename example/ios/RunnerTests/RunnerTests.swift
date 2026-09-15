import Flutter
import Gateway
import UIKit
import XCTest

@testable import nbe_payment_flutter_plugin

// Unit tests for the iOS side of the plugin that do not need the gateway, a session or UI.
// Run from Xcode (example/ios/Runner.xcworkspace, scheme Runner, Product > Test).
//
// SDK response types such as AuthenticationResponse have no public initializer, so
// authentication mapping is verified on a device through the example app instead.

final class GatewayHostApiImplTests: XCTestCase {
  private final class ControllableSdkAdapter: GatewaySdkAdapter {
    var calls: [String] = []
    var pendingVoidCompletions: [(Result<Void, Error>) -> Void] = []
    var pendingAvailabilityCompletions: [(Result<DeviceWallet, Error>) -> Void] = []

    func initialize(request: InitializeRequestMessage, completion: @escaping (Result<Void, Error>) -> Void) {
      calls.append("initialize")
      pendingVoidCompletions.append(completion)
    }

    func updateSessionWithCard(
      session: SessionMessage, card: CardMessage, additionalFields: [GatewayFieldMessage]?,
      completion: @escaping (Result<Void, Error>) -> Void
    ) {
      calls.append("updateSessionWithCard")
      pendingVoidCompletions.append(completion)
    }

    func authenticatePayer(
      request: AuthenticateRequestMessage,
      completion: @escaping (Result<AuthenticationResultMessage, Error>) -> Void
    ) {
      calls.append("authenticatePayer")
    }

    func getAvailableWallet(
      request: WalletRequestMessage, completion: @escaping (Result<DeviceWallet, Error>) -> Void
    ) {
      calls.append("getAvailableWallet")
      pendingAvailabilityCompletions.append(completion)
    }

    func payWithDeviceWallet(
      request: WalletRequestMessage, completion: @escaping (Result<WalletResultMessage, Error>) -> Void
    ) {
      calls.append("payWithDeviceWallet")
    }
  }

  private let request = InitializeRequestMessage(
    merchantId: "TESTNBE000123", merchantName: "My Store", merchantUrl: "https://mystore.example",
    region: .mtf)
  private let session = SessionMessage(
    id: "SESSION0002", orderId: "ORDER-1", amount: "150.00", currency: "EGP", apiVersion: "100")
  private let card = CardMessage(number: "5123450000000008", expiryMonth: "01", expiryYear: "39")

  func testSecondOperationWhileFirstIsRunningFailsWithOperationInProgress() {
    let adapter = ControllableSdkAdapter()
    let hostApi = GatewayHostApiImpl(sdkAdapter: adapter)
    var secondResult: Result<Void, Error>?

    hostApi.initialize(request: request) { _ in }
    hostApi.updateSessionWithCard(session: session, card: card, additionalFields: nil) { secondResult = $0 }

    XCTAssertEqual(adapter.calls, ["initialize"])
    guard case .failure(let error as GatewayBridgeError)? = secondResult else {
      return XCTFail("expected a bridge error")
    }
    XCTAssertEqual(error.code, errorCodeOperationInProgress)
  }

  func testNextOperationIsAllowedAfterCompletionAndRepliesOnlyOnce() {
    let adapter = ControllableSdkAdapter()
    let hostApi = GatewayHostApiImpl(sdkAdapter: adapter)
    var replies = 0

    hostApi.initialize(request: request) { _ in replies += 1 }
    adapter.pendingVoidCompletions[0](.success(()))
    adapter.pendingVoidCompletions[0](.success(()))
    hostApi.updateSessionWithCard(session: session, card: card, additionalFields: nil) { _ in }

    XCTAssertEqual(replies, 1)
    XCTAssertEqual(adapter.calls, ["initialize", "updateSessionWithCard"])
  }

  func testWalletAvailabilityIsNotBlockedByARunningOperation() {
    let adapter = ControllableSdkAdapter()
    let hostApi = GatewayHostApiImpl(sdkAdapter: adapter)
    var wallet: DeviceWallet?
    let walletRequest = WalletRequestMessage(
      merchantDisplayName: "My Store", countryCode: "EG", supportedNetworks: [.visa],
      isTestEnvironment: true)

    hostApi.initialize(request: request) { _ in }
    hostApi.getAvailableWallet(request: walletRequest) { result in wallet = try? result.get() }
    adapter.pendingAvailabilityCompletions[0](.success(.applePay))

    XCTAssertEqual(adapter.calls, ["initialize", "getAvailableWallet"])
    XCTAssertEqual(wallet, .applePay)
  }

  func testRepliesFromBackgroundQueuesArriveOnTheMainThread() {
    let adapter = ControllableSdkAdapter()
    let hostApi = GatewayHostApiImpl(sdkAdapter: adapter)
    let replied = expectation(description: "reply")

    hostApi.initialize(request: request) { _ in
      XCTAssertTrue(Thread.isMainThread)
      replied.fulfill()
    }
    let completion = adapter.pendingVoidCompletions[0]
    DispatchQueue.global().async { completion(.success(())) }

    waitForExpectations(timeout: 2)
  }
}

final class SdkMappingTests: XCTestCase {
  func testEveryRegionMapsToTheSdkRegion() {
    XCTAssertEqual(toSdkRegion(.mtf), Gateway.GatewayRegion.mtf)
    XCTAssertEqual(toSdkRegion(.europe), Gateway.GatewayRegion.europe)
    XCTAssertEqual(toSdkRegion(.northAmerica), Gateway.GatewayRegion.northAmerica)
    XCTAssertEqual(toSdkRegion(.asiaPacific), Gateway.GatewayRegion.asiaPacific)
    XCTAssertEqual(toSdkRegion(.india), Gateway.GatewayRegion.india)
    XCTAssertEqual(toSdkRegion(.china), Gateway.GatewayRegion.china)
    XCTAssertEqual(toSdkRegion(.saudiArabia), Gateway.GatewayRegion.saudiArabia)
  }

  func testArgbColorsConvertToUIColor() {
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
    uiColor(0x8000_6A4E)!.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

    XCTAssertEqual(red, 0, accuracy: 0.001)
    XCTAssertEqual(green, CGFloat(0x6A) / 255, accuracy: 0.001)
    XCTAssertEqual(blue, CGFloat(0x4E) / 255, accuracy: 0.001)
    XCTAssertEqual(alpha, CGFloat(0x80) / 255, accuracy: 0.001)
    XCTAssertNil(uiColor(nil))
  }

  func testEveryCardNetworkHasAPassKitNetwork() {
    XCTAssertEqual(toPaymentNetwork(.visa), .visa)
    XCTAssertEqual(toPaymentNetwork(.mastercard), .masterCard)
    XCTAssertEqual(toPaymentNetwork(.amex), .amex)
    XCTAssertEqual(toPaymentNetwork(.discover), .discover)
    XCTAssertEqual(toPaymentNetwork(.jcb), .JCB)
  }

  func testCardPayloadUsesTheIntegrationGuideKeysAndWinsOverAdditionalFields() throws {
    let payload = try buildUpdateSessionWithCardPayload(
      card: CardMessage(
        number: "5123450000000008", securityCode: "100", expiryMonth: "01", expiryYear: "39",
        nameOnCard: "Test User"),
      additionalFields: [
        GatewayFieldMessage(key: "billing.address.city", stringValue: "Cairo"),
        GatewayFieldMessage(key: "sourceOfFunds.provided.card.number", stringValue: "4111111111111111"),
      ])

    XCTAssertEqual(payload.get("sourceOfFunds.provided.card.number").stringValue, "5123450000000008")
    XCTAssertEqual(payload.get("sourceOfFunds.provided.card.securityCode").stringValue, "100")
    XCTAssertEqual(payload.get("sourceOfFunds.provided.card.expiry.month").stringValue, "01")
    XCTAssertEqual(payload.get("sourceOfFunds.provided.card.expiry.year").stringValue, "39")
    XCTAssertEqual(payload.get("sourceOfFunds.provided.card.nameOnCard").stringValue, "Test User")
    XCTAssertEqual(payload.get("billing.address.city").stringValue, "Cairo")
  }

  func testFieldWithoutValueIsRejectedByKey() {
    XCTAssertThrowsError(
      try buildGatewayFieldsPayload([GatewayFieldMessage(key: "customer.email")])
    ) { error in
      XCTAssertEqual((error as? GatewayFieldWithoutValueError)?.key, "customer.email")
    }
  }

  func testApplePayPayloadSetsTokenAndWalletProvider() {
    let payload = buildApplePayTokenPayload(token: "token")

    XCTAssertEqual(payload.get("sourceOfFunds.provided.card.devicePayment.paymentToken").stringValue, "token")
    XCTAssertEqual(payload.get("order.walletProvider").stringValue, "APPLE_PAY")
  }

  func testGatewayErrorsMapToContractCodes() {
    let rejected = gatewayRequestBridgeError(GatewayError.failedRequest(401, "Unauthorized"))
    XCTAssertEqual(rejected.code, errorCodeGatewayRejected)
    XCTAssertEqual((rejected.details as? [String: any Sendable])?[errorDetailsHttpStatusCode] as? Int, 401)

    XCTAssertEqual(gatewayRequestBridgeError(URLError(.notConnectedToInternet)).code, errorCodeNetwork)
    XCTAssertEqual(gatewayRequestBridgeError(GatewayError.missingResponse).code, errorCodeInvalidGatewayResponse)
    XCTAssertEqual(gatewayRequestBridgeError(GatewayError.invalidAPIVersion("60")).code, errorCodeInvalidApiVersion)
  }
}
