package com.example.nbe_payment_flutter_plugin.sdk

import com.example.nbe_payment_flutter_plugin.generated.ButtonStyleMessage
import com.example.nbe_payment_flutter_plugin.generated.ChallengeButtonType
import com.example.nbe_payment_flutter_plugin.generated.ChallengeUiMessage
import org.emvco.threeds.core.ui.ButtonCustomization
import org.emvco.threeds.core.ui.ButtonType
import org.emvco.threeds.core.ui.LabelCustomization
import org.emvco.threeds.core.ui.TextBoxCustomization
import org.emvco.threeds.core.ui.ToolbarCustomization
import org.emvco.threeds.core.ui.UiCustomization
import kotlin.math.roundToInt

/**
 * Builds the EMVCo customization used by the Android 3DS SDK.
 *
 * iOS-only properties ([ChallengeUiMessage.ios]) have no Android equivalent and are ignored.
 * The SDK setters validate colors with `android.graphics.Color.parseColor` and throw
 * `InvalidInputException` for values they reject.
 */
internal fun toSdkUiCustomization(message: ChallengeUiMessage): UiCustomization {
    val customization = UiCustomization()
    val regularFont = message.regularFontName
    val headingFont = message.headingFontName

    message.toolbar?.let { style ->
        customization.setToolbarCustomization(
            ToolbarCustomization().apply {
                style.backgroundColor?.let { setBackgroundColor(toHexColor(it)) }
                style.textColor?.let { setTextColor(toHexColor(it)) }
                style.fontSize?.let { setTextFontSize(it.roundToInt()) }
                (headingFont ?: regularFont)?.let { setTextFontName(it) }
                style.title?.let { setHeaderText(it) }
                style.cancelText?.let { setButtonText(it) }
            },
        )
    }

    message.label?.let { style ->
        customization.setLabelCustomization(
            LabelCustomization().apply {
                style.textColor?.let { setTextColor(toHexColor(it)) }
                style.fontSize?.let { setTextFontSize(it.roundToInt()) }
                style.headingTextColor?.let { setHeadingTextColor(toHexColor(it)) }
                style.headingFontSize?.let { setHeadingTextFontSize(it.roundToInt()) }
                regularFont?.let { setTextFontName(it) }
                headingFont?.let { setHeadingTextFontName(it) }
            },
        )
    }

    message.textBox?.let { style ->
        customization.setTextBoxCustomization(
            TextBoxCustomization().apply {
                style.textColor?.let { setTextColor(toHexColor(it)) }
                style.fontSize?.let { setTextFontSize(it.roundToInt()) }
                style.borderColor?.let { setBorderColor(toHexColor(it)) }
                style.borderWidth?.let { setBorderWidth(it.roundToInt()) }
                style.cornerRadius?.let { setCornerRadius(it.roundToInt()) }
                regularFont?.let { setTextFontName(it) }
            },
        )
    }

    // The shared button style applies to every button; Android-only overrides replace
    // individual properties for specific buttons.
    val overrides = message.androidButtonStyles.orEmpty().associate { it.type to it.style }
    if (message.button != null || overrides.isNotEmpty()) {
        for (type in ChallengeButtonType.values()) {
            val style = mergeButtonStyles(message.button, overrides[type]) ?: continue
            customization.setButtonCustomization(
                ButtonCustomization().apply {
                    style.backgroundColor?.let { setBackgroundColor(toHexColor(it)) }
                    style.textColor?.let { setTextColor(toHexColor(it)) }
                    style.fontSize?.let { setTextFontSize(it.roundToInt()) }
                    style.cornerRadius?.let { setCornerRadius(it.roundToInt()) }
                    regularFont?.let { setTextFontName(it) }
                },
                toSdkButtonType(type),
            )
        }
    }

    return customization
}

/** Formats a 32-bit ARGB value as `#AARRGGBB`, a format `Color.parseColor` accepts. */
internal fun toHexColor(argb: Long): String = String.format("#%08X", argb and 0xFFFFFFFFL)

internal fun mergeButtonStyles(
    base: ButtonStyleMessage?,
    override: ButtonStyleMessage?,
): ButtonStyleMessage? {
    if (base == null) return override
    if (override == null) return base
    return ButtonStyleMessage(
        backgroundColor = override.backgroundColor ?: base.backgroundColor,
        textColor = override.textColor ?: base.textColor,
        fontSize = override.fontSize ?: base.fontSize,
        cornerRadius = override.cornerRadius ?: base.cornerRadius,
    )
}

internal fun toSdkButtonType(type: ChallengeButtonType): ButtonType = when (type) {
    ChallengeButtonType.SUBMIT -> ButtonType.SUBMIT
    ChallengeButtonType.CONTINUE_BUTTON -> ButtonType.CONTINUE
    ChallengeButtonType.NEXT -> ButtonType.NEXT
    ChallengeButtonType.CANCEL -> ButtonType.CANCEL
    ChallengeButtonType.RESEND -> ButtonType.RESEND
    ChallengeButtonType.OPEN_OUT_OF_BAND_APP -> ButtonType.OPEN_OOB_APP
    ChallengeButtonType.ADD_CHOICE -> ButtonType.ADD_CHOICE
}
