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
/**
 * Shortens free text coming from the SDK, the 3DS server or the issuer before it is sent to
 * Flutter as a diagnostic. Those messages are unbounded third-party text; only the beginning
 * is useful, and a long payload has no place in an error.
 */
internal fun sanitizedSdkDetail(detail: String?, maxLength: Int = 120): String? {
    val trimmed = detail?.trim()?.replace(Regex("\\s+"), " ") ?: return null
    if (trimmed.isEmpty()) return null
    return if (trimmed.length <= maxLength) trimmed else "${trimmed.take(maxLength)}…"
}

internal fun unexpectedBridgeError(throwable: Throwable): GatewayBridgeError =
    gatewayBridgeError(
        code = errorCodeUnknown,
        message = "Unexpected native error.",
        nativeDetails = throwable.javaClass.simpleName,
    )
