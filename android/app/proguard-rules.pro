# Flutter Obfuscation & Shrinking Rules for PassKeep

# Flutter Engine & Plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter Secure Storage Keep Rules
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class androidx.security.crypto.** { *; }

# Local Auth & Biometric Keep Rules
-keep class io.flutter.plugins.localauth.** { *; }
-keep class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**

# Hive Local Database
-keep class io.hive.** { *; }
-keepattributes *Annotation*
-keepclassmembers class * {
    @io.hive.** *;
}

# PassKeep Model Serialization & Keep Rules
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keep class com.passkeep.passkeep.features.vault.data.models.** { *; }
-keep class com.passkeep.passkeep.** { *; }

# Android KeyStore & Cryptography
-keepclassmembers class * extends java.security.KeyStore { *; }
-keep class javax.crypto.** { *; }
-keep class java.security.** { *; }

# Keep line numbers and source attributes for crash symbolication
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable

# Ignore missing optional Play Core / Deferred Components references in Flutter Engine
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-dontwarn io.flutter.embedding.android.FlutterPlayStoreSplitApplication
