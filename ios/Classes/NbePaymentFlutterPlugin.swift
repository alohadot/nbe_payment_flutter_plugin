import Flutter
import UIKit

/// iOS entry point of the plugin. Only wires the engine to the host API; all behavior lives in
/// `GatewayHostApiImpl` and the SDK adapter.
///
/// The class name is referenced from pubspec.yaml.
public final class NbePaymentFlutterPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let hostApi = GatewayHostApiImpl(sdkAdapter: MastercardGatewaySdkAdapter())
    NbeGatewayHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: hostApi)
    // Publishing keeps the plugin alive so it receives `detachFromEngine(for:)`.
    registrar.publish(NbePaymentFlutterPlugin())
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    // Unregisters every channel handler so no call reaches a detached engine.
    NbeGatewayHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: nil)
  }
}
