# Flutter / Play release R8 rules — keep engine + plugins used via reflection.

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Google Play / GMS (Sign-In, Firebase Analytics)
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Flutter secure storage / crypto plugins often need these
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keep class kotlin.Metadata { *; }

# Gson / TypeToken style (some plugins)
-keep class * extends com.google.gson.TypeToken { *; }
-dontwarn com.google.gson.**
