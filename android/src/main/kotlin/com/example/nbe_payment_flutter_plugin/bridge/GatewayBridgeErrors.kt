package com.example.nbe_payment_flutter_plugin.bridge

import com.example.nbe_payment_flutter_plugin.generated.GatewayBridgeError
import com.example.nbe_payment_flutter_plugin.generated.errorCodeUnknown
import com.example.nbe_payment_flutter_plugin.generated.errorDetailsHttpStatusCode
import com.example.nbe_payment_flutter_plugin.generated.errorDetailsNative

/**
 * Builds a channel error in the format the Dart mapper expects.
 *
 * [nativeDetails] must never contain card data, tokens or raw gateway response bodies.
 */
internal fun gatewayBridgeError(
    code: String,
    message: String,
    nativeDetails: String? = null,
    httpStatusCode: Int? = null,
): GatewayBridgeError {
    val details = buildMap<String, Any> {
        nativeDetails?.let { put(errorDetailsNative, it) }
        httpStatusCode?.let { put(errorDetailsHttpStatusCode, it) }
    }
    return GatewayBridgeError(code, message, details.ifEmpty { null })
}

/**
 * Converts an exception nobody anticipated. Only the exception type is kept: its message
 * may echo request data.
 */
internal fun unexpectedBridgeError(throwable: Throwable): GatewayBridgeError =
    gatewayBridgeError(
        code = errorCodeUnknown,
        message = "Unexpected native error.",
        nativeDetails = throwable.javaClass.simpleName,
    )
