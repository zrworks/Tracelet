# tracelet_sync

Offline SQLite persistence and automatic HTTP synchronization engine for Tracelet.

This package automatically handles saving location data to a local SQLite database and securely synchronizing it with your backend server, ensuring no location data is lost during network outages or app terminations.

## Features

- **Offline Persistence**: Automatically persists GPS coordinates, motion state, and battery metrics to a local SQLite database.
- **Automatic HTTP Synchronization**: Syncs locations to your backend automatically when network connectivity is available.
- **Batch Synchronization**: Group multiple location records into a single HTTP request to minimize network overhead and battery drain.
- **Delta Compression (`enableDeltaCompression`)**: Drops redundant JSON headers and applies delta encoding to coordinates, yielding up to an 80% reduction in payload size.
- **Enterprise Security (SSL Pinning)**: Secure your HTTP payloads against Man-In-The-Middle (MITM) attacks by pinning SHA-256 fingerprints or full Base64 SSL certificates.
- **Cellular Data Awareness**: Option to disable auto-syncing over cellular networks (`disableAutoSyncOnCellular`) to save user data plans, falling back to Wi-Fi only.
- **Exponential Backoff & Retry**: Built-in resilience against transient network failures (5xx, 429 timeouts) with configurable maximum retries and exponential backoff caps.

## Getting Started

To add offline storage and HTTP synchronization to Tracelet, simply add this package to your `pubspec.yaml`:

```yaml
dependencies:
  tracelet: ^3.2.0
  tracelet_sync: ^3.2.0
```

Once added, Tracelet will automatically detect the sync engine and securely persist locations offline during network outages, syncing them when connectivity is restored.

## Configuration Example

The sync engine uses the `http` configuration provided to the core `Tracelet` plugin.

```dart
import 'package:tracelet/tracelet.dart';

void startTracking() async {
  await Tracelet.setConfig(Config(
    http: HttpConfig(
      url: 'https://your-backend.com/api/locations',
      method: HttpMethod.post,
      headers: {'Authorization': 'Bearer YOUR_TOKEN'},
      batchSync: true,
      maxBatchSize: 250,
      autoSyncThreshold: 10,
      enableDeltaCompression: true,
      disableAutoSyncOnCellular: false,
      maxRetries: 3,
      retryBackoffBase: 1000,
      retryBackoffCap: 60000,
      sslPinningFingerprints: [
        'sha256/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX='
      ],
    ),
  ));

  await Tracelet.start();
}
```
