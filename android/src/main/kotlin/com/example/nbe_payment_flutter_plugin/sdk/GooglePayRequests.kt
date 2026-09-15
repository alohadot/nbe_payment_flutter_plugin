package com.example.nbe_payment_flutter_plugin.sdk

import com.example.nbe_payment_flutter_plugin.generated.CardNetwork
import com.example.nbe_payment_flutter_plugin.generated.SessionMessage
import com.example.nbe_payment_flutter_plugin.generated.WalletRequestMessage
import com.google.gson.JsonArray
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.mastercard.gateway.android.sdk.GatewayMap

// Google Pay API JSON builders. The tokenization specification ("PAYMENT_GATEWAY" with
// gateway "mpgs" and the gateway merchant ID) comes from the Gateway Android SDK integration
// guide; the rest of the request shape is the Google Pay API (version 2) format.
//
// Gson is used instead of org.json so these functions run in plain JVM unit tests.

private const val GOOGLE_PAY_API_VERSION = 2
private const val GOOGLE_PAY_API_VERSION_MINOR = 0

internal fun buildIsReadyToPayRequestJson(networks: List<CardNetwork>): String = JsonObject().apply {
    addProperty("apiVersion", GOOGLE_PAY_API_VERSION)
    addProperty("apiVersionMinor", GOOGLE_PAY_API_VERSION_MINOR)
    add("allowedPaymentMethods", JsonArray().apply { add(baseCardPaymentMethod(networks)) })
}.toString()

internal fun buildPaymentDataRequestJson(
    request: WalletRequestMessage,
    session: SessionMessage,
    gatewayMerchantId: String,
): String = JsonObject().apply {
    addProperty("apiVersion", GOOGLE_PAY_API_VERSION)
    addProperty("apiVersionMinor", GOOGLE_PAY_API_VERSION_MINOR)
    add(
        "allowedPaymentMethods",
        JsonArray().apply {
            add(
                baseCardPaymentMethod(request.supportedNetworks).apply {
                    add(
                        "tokenizationSpecification",
                        JsonObject().apply {
                            addProperty("type", "PAYMENT_GATEWAY")
                            add(
                                "parameters",
                                JsonObject().apply {
                                    addProperty("gateway", "mpgs")
                                    addProperty("gatewayMerchantId", gatewayMerchantId)
                                },
                            )
                        },
                    )
                },
            )
        },
    )
    add(
        "transactionInfo",
        JsonObject().apply {
            addProperty("totalPriceStatus", "FINAL")
            // Taken from the gateway session so the sheet shows exactly what will be charged.
            addProperty("totalPrice", session.amount)
            addProperty("currencyCode", session.currency)
            addProperty("countryCode", request.countryCode)
        },
    )
    add(
        "merchantInfo",
        JsonObject().apply {
            addProperty("merchantName", request.merchantDisplayName)
            request.googlePayMerchantId?.let { addProperty("merchantId", it) }
        },
    )
}.toString()

private fun baseCardPaymentMethod(networks: List<CardNetwork>) = JsonObject().apply {
    addProperty("type", "CARD")
    add(
        "parameters",
        JsonObject().apply {
            add(
                "allowedAuthMethods",
                JsonArray().apply {
                    add("PAN_ONLY")
                    add("CRYPTOGRAM_3DS")
                },
            )
            add(
                "allowedCardNetworks",
                JsonArray().apply { networks.forEach { add(toGooglePayNetwork(it)) } },
            )
        },
    )
}

internal fun toGooglePayNetwork(network: CardNetwork): String = when (network) {
    CardNetwork.VISA -> "VISA"
    CardNetwork.MASTERCARD -> "MASTERCARD"
    CardNetwork.AMEX -> "AMEX"
    CardNetwork.DISCOVER -> "DISCOVER"
    CardNetwork.JCB -> "JCB"
}

/** What the plugin needs from a Google Pay `PaymentData` response. */
internal class GooglePayPaymentData(
    /** Encrypted payment token for the gateway. Never log it. */
    val token: String,
    /** Display-only description such as "Visa •••• 1234". */
    val description: String?,
) {
    override fun toString() = "GooglePayPaymentData(token=•••, description=$description)"
}

/** @throws IllegalArgumentException if the response has no tokenization data. */
internal fun parseGooglePayPaymentData(paymentDataJson: String): GooglePayPaymentData {
    val paymentMethodData = runCatching {
        JsonParser.parseString(paymentDataJson).asJsonObject.getAsJsonObject("paymentMethodData")
    }.getOrNull() ?: throw IllegalArgumentException("Google Pay response has no payment method data.")

    val token = paymentMethodData.getAsJsonObject("tokenizationData")
        ?.get("token")
        ?.takeIf { it.isJsonPrimitive }
        ?.asString
        ?: throw IllegalArgumentException("Google Pay response has no payment token.")

    val description = paymentMethodData.get("description")
        ?.takeIf { it.isJsonPrimitive }
        ?.asString

    return GooglePayPaymentData(token, description)
}

/**
 * Update-session payload for a Google Pay token. The token field follows the Gateway Android
 * SDK integration guide; `order.walletProvider` mirrors what the iOS guide sets for Apple Pay.
 */
internal fun buildGooglePayTokenPayload(token: String): GatewayMap = GatewayMap()
    .set("sourceOfFunds.provided.card.devicePayment.paymentToken", token)
    .set("order.walletProvider", "GOOGLE_PAY")
