# Tracelet Android Plugin — ProGuard/R8 Consumer Rules
# These rules are automatically applied to host apps using this plugin.

# Keep all Tracelet service, receiver, and plugin classes
-keep class com.tracelet.tracelet_android.** { *; }

# Keep the service and receiver classes that are referenced in AndroidManifest
-keep class com.tracelet.tracelet_android.service.LocationService { *; }
-keep class com.tracelet.tracelet_android.service.HeadlessTaskService { *; }
-keep class com.tracelet.tracelet_android.receiver.BootReceiver { *; }
-keep class com.tracelet.tracelet_android.receiver.GeofenceBroadcastReceiver { *; }

# Keep the plugin entry point
-keep class com.tracelet.tracelet_android.TraceletAndroidPlugin { *; }

# Keep BuildConfig (required for AGP 8.5+)
-keep class com.tracelet.tracelet_android.BuildConfig { *; }

# Room database — keep entities and DAOs
-keep class com.tracelet.tracelet_android.db.** { *; }

# Keep Kotlin metadata for reflection
-keepattributes *Annotation*
-keepattributes KotlinMetadata
