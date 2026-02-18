# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Google Play Core (Deferred Components / Split Install)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# Google Maps Flutter Plugin
-keep class io.flutter.plugins.googlemaps.** { *; }
-dontwarn io.flutter.plugins.googlemaps.**

# Google Play Services (Maps)
-keep class com.google.android.gms.maps.** { *; }
-keep class com.google.android.gms.location.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.dynamic.** { *; }
-keep class com.google.maps.android.** { *; }

# Geocoding plugin (reverse geocoding on map tap)
-keep class com.baseflow.geocoding.** { *; }
-dontwarn com.baseflow.geocoding.**

# Geolocator plugin (current location)
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Keep Hive models
-keep class * extends com.google.protobuf.GeneratedMessageLite { *; }

# Gson (if used)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }

# OkHttp / Retrofit
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase

# General Android
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
