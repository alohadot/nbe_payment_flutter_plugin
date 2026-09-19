package com.example.nbe_payment_flutter_plugin.sdk

import com.example.nbe_payment_flutter_plugin.bridge.GatewayRejectionFields
import com.example.nbe_payment_flutter_plugin.bridge.gatewayBridgeError
import com.example.nbe_payment_flutter_plugin.generated.GatewayBridgeError
import com.example.nbe_payment_flutter_plugin.generated.errorCodeGatewayRejected
import com.example.nbe_payment_flutter_plugin.generated.errorCodeInvalidGatewayResponse
import com.example.nbe_payment_flutter_plugin.generated.errorCodeNetwork
import com.example.nbe_payment_flutter_plugin.generated.errorCodeNotInitialized
import com.example.nbe_payment_flutter_plugin.generated.errorCodeUnknown
import com.google.gson.JsonObject
import com.google.gson.JsonParseException
import com.google.gson.JsonParser
import retrofit2.HttpException
import java.io.IOException

/**
 * Maps failures of SDK calls that go straight to the gateway REST API (such as
 * `GatewayAPI.updateSession`).
 *
 * The Android SDK does not wrap these failures: it surfaces Retrofit/OkHttp/Gson exceptions
 * as they are. Exception messages and response bodies are never copied, because they may echo
 * request values; only exception types, the HTTP status and the gateway's error *codes* are
 * kept.
 */
internal fun gatewayRequestBridgeError(throwable: Throwable): GatewayBridgeError = when (throwable) {
    is HttpException -> {
        val rejection = readGatewayRejection(throwable)
        gatewayBridgeError(
            code = errorCodeGatewayRejected,
            message = "The gateway rejected the request.",
            nativeDetails = describeGatewayErrorBody(throwable.code(), rejection),
            httpStatusCode = throwable.code(),
            rejection = rejection,
        )
    }

    // Includes SSLPeerUnverifiedException raised by the SDK's certificate pinning.
    is IOException -> gatewayBridgeError(
        code = errorCodeNetwork,
        message = "The gateway could not be reached.",
        nativeDetails = throwable.javaClass.simpleName,
    )

    is JsonParseException -> gatewayBridgeError(
        code = errorCodeInvalidGatewayResponse,
        message = "The gateway response could not be read.",
        nativeDetails = throwable.javaClass.simpleName,
    )

    // Thrown by the SDK when GatewayAPI is used before GatewaySDK.initialize completed.
    is UninitializedPropertyAccessException -> gatewayBridgeError(
        code = errorCodeNotInitialized,
        message = "The Gateway SDK is not initialized.",
    )

    else -> gatewayBridgeError(
        code = errorCodeUnknown,
        message = "The gateway request failed.",
        nativeDetails = throwable.javaClass.simpleName,
    )
}

/**
 * Reads the gateway's machine-readable error fields (`error.cause`, `error.field`,
 * `error.validationType`), which name what failed without repeating submitted values.
 * `error.explanation` is deliberately dropped: it is free text that may quote input.
 *
 * Returns `null` when the body is missing, unreadable or carries none of the three fields.
 */
internal fun readGatewayRejection(error: HttpException): GatewayRejectionFields? {
    val gatewayError = try {
        error.response()?.errorBody()?.string()
            ?.let { JsonParser.parseString(it) }
            ?.takeIf { it.isJsonObject }
            ?.asJsonObject
            ?.getAsJsonObject("error")
    } catch (_: Exception) {
        null
    } ?: return null

    val rejection = GatewayRejectionFields(
        cause = gatewayError.stringOrNull("cause"),
        field = gatewayError.stringOrNull("field"),
        validationType = gatewayError.stringOrNull("validationType"),
    )
    return rejection.takeIf { !it.isEmpty }
}

/** The same fields as one diagnostic line, for logs. */
private fun describeGatewayErrorBody(
    httpStatusCode: Int,
    rejection: GatewayRejectionFields?,
): String {
    val summary = mutableListOf("HTTP $httpStatusCode")
    rejection?.cause?.let { summary += "cause=$it" }
    rejection?.field?.let { summary += "field=$it" }
    rejection?.validationType?.let { summary += "validationType=$it" }
    return summary.joinToString("; ")
}

private fun JsonObject.stringOrNull(name: String): String? =
    get(name)?.takeIf { it.isJsonPrimitive }?.asString
