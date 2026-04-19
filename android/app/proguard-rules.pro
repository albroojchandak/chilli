# Resolved R8/Proguard rules for Chilli
-dontwarn com.google.firebase.iid.**
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.internal.mlkit_linkfirebase.**

# Prevent shrinking from breaking ML Kit
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }

-ignorewarnings
