# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }

# Google ML Kit — text recognition
-keep class com.google.mlkit.** { *; }
-keep class com.google_mlkit_** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google_mlkit_**

# Play Core (dépendance transitive ML Kit — non présente dans l'APK)
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.**

# Évite que R8 bloque sur des classes optionnelles absentes
-ignorewarnings
