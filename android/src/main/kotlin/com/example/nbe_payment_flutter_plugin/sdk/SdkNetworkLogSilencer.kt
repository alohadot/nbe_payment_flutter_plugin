package com.example.nbe_payment_flutter_plugin.sdk

import okhttp3.OkHttpClient
import java.util.logging.Level
import java.util.logging.Logger

/**
 * Stops the Gateway SDK from writing HTTP traffic to logcat.
 *
 * Why this exists: Gateway Android SDK 2.0.17 installs OkHttp's `HttpLoggingInterceptor` at
 * level BODY in every build, so each request is logged with its headers and body. For
 * update-session that includes the card number, the security code and the `Authorization`
 * header (merchant ID + session ID). Verified on a device.
 *
 * How: on Android, OkHttp 4 writes its logs through the `java.util.logging` logger named after
 * the `OkHttpClient` class and forwards them to logcat (tag `okhttp.OkHttpClient`). OkHttp
 * configures that logger's level when its Android platform is first created, which happens
 * when the SDK builds its HTTP client during initialization. Setting the level to OFF after
 * that point suppresses every message; setting it earlier would be overwritten, so it is
 * applied again before each gateway call.
 *
 * The logger name is taken from the class, not written as a string: R8 renames OkHttpClient
 * in release builds, and OkHttp uses the renamed class name at runtime.
 *
 * Revisit whenever the Gateway SDK or its OkHttp version changes (see README, "Updating the
 * Android Native SDK").
 */
internal object SdkNetworkLogSilencer {

    // java.util.logging only keeps weak references to loggers; holding it here guarantees
    // the OFF level is not lost to garbage collection.
    private val okHttpClientLogger: Logger = Logger.getLogger(OkHttpClient::class.java.name)

    fun silence() {
        okHttpClientLogger.level = Level.OFF
    }
}
