# Keep Flutter engine + plugins functional while allowing R8 shrinking.
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep app classes with JSON reflection patterns when needed.
-keepattributes Signature,RuntimeVisibleAnnotations,RuntimeVisibleParameterAnnotations,AnnotationDefault

# Local auth / notification plugins may use reflection on Android internals.
-keep class androidx.biometric.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn org.jetbrains.annotations.**

# flutter_local_notifications stores scheduled notifications with Gson. R8
# strips the generic type information it needs, which silently breaks
# scheduled (but not immediate) notifications in release builds.
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
