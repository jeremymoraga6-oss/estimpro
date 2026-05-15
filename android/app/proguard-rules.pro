# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }

# Google ML Kit — text recognition
-keep class com.google.mlkit.** { *; }
-keep class com.google_mlkit_** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_latin.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google_mlkit_**
