package com.example.nbe_payment_flutter_plugin

import com.example.nbe_payment_flutter_plugin.bridge.GatewayHostApiImpl
import com.example.nbe_payment_flutter_plugin.generated.NbeGatewayHostApi
import com.example.nbe_payment_flutter_plugin.sdk.MastercardGatewaySdkAdapter
import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Android entry point of the plugin. Only wires the engine to the host API; all behavior
 * lives in [GatewayHostApiImpl] and the SDK adapter.
 *
 * The class name and package are referenced from pubspec.yaml.
 */
class NbePaymentFlutterPlugin : FlutterPlugin {

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val hostApi = GatewayHostApiImpl(MastercardGatewaySdkAdapter(binding.applicationContext))
        NbeGatewayHostApi.setUp(binding.binaryMessenger, hostApi)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Unregisters every channel handler so no call reaches a detached engine.
        NbeGatewayHostApi.setUp(binding.binaryMessenger, null)
    }
}
