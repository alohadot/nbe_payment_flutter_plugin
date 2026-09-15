# Consumer R8/ProGuard rules shipped with nbe_payment_flutter_plugin.
# Applied automatically to every app that depends on the plugin.

# The Gateway Android SDK 2.0.17 declares its REST calls as Retrofit 2.9 `suspend` functions.
# In R8 full mode (the default since Android Gradle Plugin 8), the generic signatures Retrofit
# reads at runtime are removed, and every gateway request fails with a ClassCastException in
# release builds only. Retrofit 2.10+ ships these rules itself; the SDK's version does not.
-keep,allowobfuscation,allowshrinking class kotlin.coroutines.Continuation
-keep,allowobfuscation,allowshrinking interface retrofit2.Call
-keep,allowobfuscation,allowshrinking class retrofit2.Response
