-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
# Keep your actual data models and classes
-keep class com.rasty.shiftchart.** { *; }

# 1. Protect your application models, enums, and data mappings
-keep class com.rasty.shiftchart.** { *; }

-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(***);
}
# 3. Retain core metadata signatures required by Hive and JSON serialization
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# 4. Protect your underlying plugins and binary storage mechanisms
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.pravera.flutter_foreground_task.** { *; }
-keep class io.isar.** { *; }
-dontwarn io.isar.**
# Android lifecycle & platform keeping
-keep class androidx.lifecycle.** { *; }
-dontwarn androidx.lifecycle.**
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
# JNI & Dart FFI - Required for your jni_flutter plugins
-keep class com.sun.jna.** { *; }
-keep class * extends com.sun.jna.** { *; }

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Flutter Foreground Task
-keep class com.pravera.flutter_foreground_task.** { *; }
