# Consumer R8/ProGuard rules shipped with nbe_payment_flutter_plugin.
# Applied automatically to every app that depends on the plugin.

# The Gateway Android SDK 2.0.17 declares its REST calls as Retrofit 2.9 `suspend` functions.
# Its own bundled rules keep its classes and Retrofit's annotated interfaces, but not the
# generic signatures Retrofit reads for suspend functions. In R8 full mode (the default since
# Android Gradle Plugin 8) every gateway request then fails with a ClassCastException in
# release builds only. Retrofit 2.10+ ships these rules itself; the SDK's version does not.
#
# Verified: without these three rules, the integration tests inside a release APK fail on the
# first card update; with them, they pass (see doc/RELEASE_CHECKLIST.md).
-keep,allowobfuscation,allowshrinking class kotlin.coroutines.Continuation
-keep,allowobfuscation,allowshrinking interface retrofit2.Call
-keep,allowobfuscation,allowshrinking class retrofit2.Response
