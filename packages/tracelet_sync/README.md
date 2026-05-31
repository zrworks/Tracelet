# tracelet_sync

Offline SQLite persistence and automatic HTTP synchronization engine for Tracelet.

## Getting Started

To add offline storage and HTTP synchronization to Tracelet, simply add this package to your `pubspec.yaml`:

```yaml
dependencies:
  tracelet: ^3.2.0
  tracelet_sync: ^3.2.0
```

Once added, Tracelet will automatically detect the sync engine and securely persist locations offline during network outages, syncing them when connectivity is restored.
