package com.example.nbe_payment_flutter_plugin.sdk

import com.example.nbe_payment_flutter_plugin.generated.CardMessage
import com.example.nbe_payment_flutter_plugin.generated.GatewayFieldMessage
import com.example.nbe_payment_flutter_plugin.generated.SessionMessage
import com.mastercard.gateway.android.sdk.GatewayMap
import com.mastercard.gateway.android.sdk.Session

internal fun toSdkSession(session: SessionMessage): Session = Session(
    id = session.id,
    amount = session.amount,
    currency = session.currency,
    apiVersion = session.apiVersion,
    orderId = session.orderId,
)

/**
 * Builds the update-session payload. Field names follow the "Manual Card Entry" section of
 * the Gateway Android SDK integration guide.
 *
 * Additional fields are written first and card fields last, so card values can never be
 * replaced by a free-form field (the Dart layer already rejects `sourceOfFunds.*` keys).
 *
 * @throws IllegalArgumentException if an additional field carries no value.
 */
internal fun buildUpdateSessionWithCardPayload(
    card: CardMessage,
    additionalFields: List<GatewayFieldMessage>?,
): GatewayMap {
    val payload = GatewayMap()
    additionalFields.orEmpty().forEach { field -> payload.set(field.key, valueOf(field)) }

    payload.set("sourceOfFunds.provided.card.number", card.number)
    payload.set("sourceOfFunds.provided.card.expiry.month", card.expiryMonth)
    payload.set("sourceOfFunds.provided.card.expiry.year", card.expiryYear)
    card.securityCode?.let { payload.set("sourceOfFunds.provided.card.securityCode", it) }
    card.nameOnCard?.let { payload.set("sourceOfFunds.provided.card.nameOnCard", it) }
    return payload
}

private fun valueOf(field: GatewayFieldMessage): Any =
    field.stringValue
        ?: field.intValue
        ?: field.doubleValue
        ?: field.boolValue
        // Only the key is reported: values may contain personal data.
        ?: throw IllegalArgumentException("Gateway field \"${field.key}\" has no value.")
