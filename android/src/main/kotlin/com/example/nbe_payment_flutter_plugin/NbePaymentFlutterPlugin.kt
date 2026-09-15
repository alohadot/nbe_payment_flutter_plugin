package com.example.nbe_payment_flutter_plugin

import android.app.Activity
import com.example.nbe_payment_flutter_plugin.bridge.GatewayHostApiImpl
import com.example.nbe_payment_flutter_plugin.generated.NbeGatewayHostApi
import com.example.nbe_payment_flutter_plugin.sdk.MastercardGatewaySdkAdapter
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

/**
 * Android entry point of the plugin. Wires the engine to the host API and tracks the Activity
 * that 3-D Secure screens are presented from; all behavior lives in [GatewayHostApiImpl] and
 * the SDK adapter.
 *
 * The class name and package are referenced from pubspec.yaml.
 */
class NbePaymentFlutterPlugin : FlutterPlugin, ActivityAware {

    // Main-thread only. Cleared whenever the Activity goes away so no stale Activity is used.
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val sdkAdapter = MastercardGatewaySdkAdapter(
            context = binding.applicationContext,
            activityProvider = { activity },
        )
        NbeGatewayHostApi.setUp(binding.binaryMessenger, GatewayHostApiImpl(sdkAdapter))
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Unregisters every channel handler so no call reaches a detached engine.
        NbeGatewayHostApi.setUp(binding.binaryMessenger, null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}
