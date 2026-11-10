package com.example.nbe_payment_flutter_plugin.sdk

import android.app.Activity
import android.os.Build
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher
import androidx.annotation.RequiresApi

/**
 * Routes the back gesture of a screen to its legacy `Activity.onBackPressed`, for screens that
 * implement only that method; see [ChallengeScreenGuard] for why the challenge screen needs it.
 *
 * Kept in a class of its own because `android.window` does not exist below API 33: any code
 * that touches those types — even a cast the compiler adds when reading a generic map — crashes
 * there with `NoClassDefFoundError` (seen on Android 11 after a challenge). Callers create this
 * class only on API 33 and later, so older devices never load it, and lint checks the rule
 * through [RequiresApi].
 *
 * Main-thread only.
 */
@RequiresApi(Build.VERSION_CODES.TIRAMISU)
internal class BackInvokedBridge {

    /** Callbacks registered here, so each is removed with its screen. */
    private val callbacks = mutableMapOf<Activity, OnBackInvokedCallback>()

    fun add(activity: Activity) {
        if (callbacks.containsKey(activity)) return

        // Calls the screen's own handler. Deprecated for apps, but it is the entry point the
        // 3DS SDK has: it sends the issuer a cardholder cancellation and then closes the screen.
        val callback = OnBackInvokedCallback {
            @Suppress("DEPRECATION")
            activity.onBackPressed()
        }
        activity.onBackInvokedDispatcher.registerOnBackInvokedCallback(
            OnBackInvokedDispatcher.PRIORITY_DEFAULT,
            callback,
        )
        callbacks[activity] = callback
    }

    fun remove(activity: Activity) {
        val callback = callbacks.remove(activity) ?: return
        activity.onBackInvokedDispatcher.unregisterOnBackInvokedCallback(callback)
    }

    fun removeAll() {
        callbacks.keys.toList().forEach(::remove)
    }
}
