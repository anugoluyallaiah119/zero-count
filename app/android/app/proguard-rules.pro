# Flutter / Dart keep rules.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Unity Ads SDK.
-keep class com.unity3d.** { *; }
-dontwarn com.unity3d.**

# Firebase / FCM.
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# in_app_purchase / Google Play Billing.
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# Dio / OkHttp (keep response model names for JSON parsing).
-keepattributes Signature
-keepattributes *Annotation*
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**
