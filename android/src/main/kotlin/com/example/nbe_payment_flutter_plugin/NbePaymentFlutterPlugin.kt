package com.example.nbe_payment_flutter_plugin

import android.app.Activity
import com.example.nbe_payment_flutter_plugin.bridge.GatewayHostApiImpl
import com.example.nbe_payment_flutter_plugin.generated.NbeGatewayHostApi
import com.example.nbe_payment_flutter_plugin.sdk.GatewaySdkAdapter
import com.example.nbe_payment_flutter_plugin.sdk.MastercardGatewaySdkAdapter
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry

/**
 * Android entry point of the plugin. Wires the engine to the host API, tracks the Activity
 * that 3-D Secure and Google Pay screens are presented from, and forwards Activity results;
 * all behavior lives in [GatewayHostApiImpl] and the SDK adapter.
 *
 * The class name and package are referenced from pubspec.yaml.
 */
class NbePaymentFlutterPlugin : FlutterPlugin, ActivityAware {

    // Main-thread only. Cleared whenever the Activity goes away so no stale Activity is used.
    private var activityBinding: ActivityPluginBinding? = null
    private var sdkAdapter: GatewaySdkAdapter? = null

    private val activityResultListener = PluginRegistry.ActivityResultListener { requestCode, resultCode, data ->
        sdkAdapter?.handleActivityResult(requestCode, resultCode, data) ?: false
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val adapter = MastercardGatewaySdkAdapter(
            context = binding.applicationContext,
            activityProvider = { activityBinding?.activity },
        )
        sdkAdapter = adapter
        NbeGatewayHostApi.setUp(binding.binaryMessenger, GatewayHostApiImpl(adapter))
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Unregisters every channel handler so no call reaches a detached engine.
        NbeGatewayHostApi.setUp(binding.binaryMessenger, null)
        sdkAdapter = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) = attachActivity(binding)

    override fun onDetachedFromActivityForConfigChanges() = detachActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = attachActivity(binding)

    override fun onDetachedFromActivity() = detachActivity()

    private fun attachActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addActivityResultListener(activityResultListener)
    }

    private fun detachActivity() {
        activityBinding?.removeActivityResultListener(activityResultListener)
        activityBinding = null
    }
}
