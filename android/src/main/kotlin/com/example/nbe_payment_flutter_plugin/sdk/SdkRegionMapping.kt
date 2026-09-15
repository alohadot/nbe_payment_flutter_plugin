package com.example.nbe_payment_flutter_plugin.sdk

import com.example.nbe_payment_flutter_plugin.generated.GatewayRegion
import com.mastercard.gateway.android.sdk.GatewayRegion as SdkGatewayRegion

internal fun toSdkRegion(region: GatewayRegion): SdkGatewayRegion = when (region) {
    GatewayRegion.MTF -> SdkGatewayRegion.MTF
    GatewayRegion.EUROPE -> SdkGatewayRegion.EUROPE
    GatewayRegion.NORTH_AMERICA -> SdkGatewayRegion.NORTH_AMERICA
    GatewayRegion.ASIA_PACIFIC -> SdkGatewayRegion.ASIA_PACIFIC
    GatewayRegion.INDIA -> SdkGatewayRegion.INDIA
    GatewayRegion.CHINA -> SdkGatewayRegion.CHINA
    GatewayRegion.SAUDI_ARABIA -> SdkGatewayRegion.SAUDI_ARABIA
}
