# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }

# Agora
-keep class io.agora.** { *; }

# Gson / JSON
-keepattributes Signature
-keepattributes *Annotation*

# Prevent stripping of crypto classes
-keep class javax.crypto.** { *; }
