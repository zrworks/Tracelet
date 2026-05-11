# AOSP Compatibility and GMS-free Operation

The Tracelet Android SDK is designed to be fully compatible with AOSP (Android Open Source Project) devices that do not have Google Play Services (GMS) installed.

## Provider-based Architecture

The SDK uses a provider-based architecture to abstract away platform-specific location and geolocation services. At runtime, the SDK automatically detects the presence of GMS and chooses the appropriate implementation.

### Automatic Detection

The `TraceletServices` object checks for the existence of `com.google.android.gms.location.LocationServices` using reflection.

- **GMS Available**: Uses `PlayServicesProvider`, which leverages `FusedLocationProviderClient`, `GeofencingClient`, and `ActivityRecognitionClient`.
- **GMS Not Available**: Falls back to `AospServicesProvider`, which uses the native Android `LocationManager`.

### Manual Override

Developers can manually override the service provider if they wish to provide a custom implementation or force a specific mode.

```kotlin
import com.ikolvi.tracelet.sdk.wrapper.TraceletServices
import com.ikolvi.tracelet.sdk.wrapper.AospServicesProvider

// Force AOSP fallback even if GMS is present
TraceletServices.setProvider(AospServicesProvider())
```

## Features and Limitations

| Feature | GMS Mode | AOSP Fallback |
|---------|----------|---------------|
| Location Tracking | Fused (GPS + Wi-Fi + Cell) | LocationManager (GPS / Network) |
| Geofencing | Google Geofencing API | Proximity Alerts (Native) |
| Activity Recognition | Google Activity Recognition | Disabled (Always "unknown") |
| Battery Efficiency | High (Google Play Services optimization) | Standard (Standard system intervals) |

## Dependency Configuration

To keep the SDK binary small and free of mandatory GMS dependencies, the GMS libraries are declared as `compileOnly`. 

If your application intends to use GMS features, you **must** add the following dependency to your application's `build.gradle`:

```gradle
dependencies {
    implementation "com.google.android.gms:play-services-location:21.3.0"
}
```

If this dependency is missing, the SDK will gracefully fall back to AOSP mode without crashing.
