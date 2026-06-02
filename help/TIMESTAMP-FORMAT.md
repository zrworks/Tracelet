# Timestamp Format & Developer Experience (DX)

Tracelet places a strong emphasis on providing a frictionless developer experience (DX) when dealing with dates, times, and timestamps across the Dart, Kotlin, Swift, and Rust layers.

## The Challenge

Historically, bridging dates between a frontend framework (Flutter/Dart) and native/Rust layers required developers to manually convert their timestamps into strict strings (like `ISO-8601` or `RFC-3339`), dealing with timezone offsets, UTC conversions, and string formatting nuances like replacing `.000Z` with `+00:00`.

## Our Solution (Auto-Normalization)

Tracelet implements **smart timestamp auto-normalization** natively at the Dart boundary. You do not need to manually format timestamp strings before passing them to the SDK.

When passing a custom timestamp to `Tracelet.insertLocation()`, the SDK accepts three different data types for maximum flexibility:

### 1. Dart `DateTime` Object (Recommended)

You can pass a standard Dart `DateTime` object directly. The SDK will automatically convert it to UTC, extract the correct temporal data, and format it exactly as the native SQLite layer expects.

```dart
await Tracelet.insertLocation({
  'timestamp': DateTime.now(), // Auto-normalized internally
  'coords': {
    'latitude': 48.8566,
    'longitude': 2.3522,
    'accuracy': 5.0,
  }
});
```

### 2. Unix Epoch Milliseconds (`int`)

If your data comes from a server or a legacy database as epoch milliseconds, you can pass the integer directly.

```dart
await Tracelet.insertLocation({
  'timestamp': 1704106800000, // Unix epoch milliseconds
  // ...
});
```

### 3. ISO-8601 Strings (`String`)

If you already have a formatted string (e.g., from an API response), you can pass the string directly. Tracelet uses Dart's `DateTime.tryParse()` internally to understand it, gracefully handles local times, and re-formats it into the canonical UTC RFC-3339 string required by the Rust core.

```dart
await Tracelet.insertLocation({
  'timestamp': '2024-01-01T10:00:00.123Z', 
  // ...
});
```

## Canonical Database Format (Under the Hood)

Regardless of which of the three methods you use above, Tracelet's Dart layer intercepts the parameter and normalizes it into a strict **UTC RFC-3339** string format before sending it over the MethodChannels.

- **Example Output**: `2024-01-01T10:00:00.123+00:00`
- **Why this format?** The Rust core and SQLite database rely on exact string comparisons for querying data (e.g., `timestamp >= ? AND timestamp <= ?`). By ensuring the Dart layer generates the exact same string format that Rust generates internally via `chrono::Utc::now().to_rfc3339()`, we guarantee that database queries and time-window filtering work flawlessly.

## Querying Data

When querying data using `SQLQuery`, you also provide Dart `DateTime` objects, and Tracelet handles the epoch conversion for you under the hood.

```dart
final locations = await Tracelet.getLocations(
  SQLQuery(
    start: DateTime.now().subtract(Duration(hours: 2)),
    end: DateTime.now(),
  )
);
```

By abstracting away the complexity of cross-platform date formatting, Tracelet ensures that your code remains clean, readable, and free of boilerplate string manipulation.
