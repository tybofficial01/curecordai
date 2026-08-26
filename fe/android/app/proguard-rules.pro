# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Google Sign In
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Flutter's engine references Play Core's deferred-components (dynamic
# feature delivery) APIs, but this app doesn't use them - R8 can't find
# those classes at the current Play Core/AGP version mismatch, so tell it
# not to fail the build over references that are never actually reached.
-dontwarn com.google.android.play.core.**
