import Flutter
import UIKit

/// iOS entry point of the plugin. Only wires the engine to the host API; all behavior lives in
/// `GatewayHostApiImpl` and the SDK adapter.
///
/// The class name is referenced from pubspec.yaml.
public final class NbePaymentFlutterPlugin: NSObject, FlutterPlugin {
  private var hostApi: GatewayHostApiImpl?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = NbePaymentFlutterPlugin()
    let hostApi = GatewayHostApiImpl(sdkAdapter: MastercardGatewaySdkAdapter())
    plugin.hostApi = hostApi
    NbeGatewayHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: hostApi)
    // Publishing keeps the plugin alive so it receives `detachFromEngine(for:)`.
    registrar.publish(plugin)
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    // Unregisters every channel handler so no call reaches a detached engine, then takes down
    // native screens and fails anything still waiting: its reply could no longer be delivered,
    // and a held operation lock would block every later call in this process.
    NbeGatewayHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: nil)
    hostApi?.dispose()
    hostApi = nil
  }
}
