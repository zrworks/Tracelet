# `syncInterval` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `syncInterval` property to `HttpConfig` that flushes pending locations to the server on a fixed timer (in seconds) instead of on every location insert, enabling fleet/logistics use cases that need business-aligned sync cadence.

**Architecture:** When `syncInterval > 0`, auto-sync switches from "fire on every insert" to "fire on a repeating timer". The timer is managed inside `HttpSyncManager` on both Android (via `ScheduledExecutorService`) and iOS (via `DispatchSourceTimer`). The existing `autoSync` flag still acts as the master switch — `syncInterval` only takes effect when `autoSync` is also `true`. When the timer fires, it calls the existing `performSync()` / `sync(completion:)` — no new sync logic is needed.

**Tech Stack:** Dart (config model), Kotlin (`ScheduledExecutorService`), Swift (`DispatchSourceTimer`)

**Closes:** https://github.com/Ikolvi/Tracelet/issues/50

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Modify | `packages/tracelet/lib/src/models/config.dart` | Add `syncInterval` field to `HttpConfig` |
| Modify | `packages/tracelet/test/models_test.dart` | Tests for `syncInterval` in `HttpConfig` |
| Modify | `sdk/android/tracelet-sdk/src/main/kotlin/com/ikolvi/tracelet/sdk/ConfigManager.kt` | Add `getSyncInterval()` accessor + default constant |
| Modify | `sdk/android/tracelet-sdk/src/main/kotlin/com/ikolvi/tracelet/sdk/http/HttpSyncManager.kt` | Timer-based sync logic |
| Modify | `sdk/ios/Sources/TraceletSDK/ConfigManager.swift` | Add `getSyncInterval()` accessor |
| Modify | `sdk/ios/Sources/TraceletSDK/http/HttpSyncManager.swift` | Timer-based sync logic |
| Modify | `help/HTTP-SYNC.md` | Document `syncInterval` |
| Modify | `help/CONFIGURATION.md` | Add `syncInterval` to config reference |

---

### Task 1: Add `syncInterval` to Dart `HttpConfig`

**Files:**
- Modify: `packages/tracelet/lib/src/models/config.dart:1262-1530`

- [ ] **Step 1: Add the constructor parameter and field**

In `HttpConfig`'s constructor (line ~1264), add `syncInterval` after `autoSyncThreshold`:

```dart
const HttpConfig({
    this.url,
    this.method = HttpMethod.post,
    this.headers = const <String, String>{},
    this.httpRootProperty = 'location',
    this.batchSync = false,
    this.maxBatchSize = 250,
    this.autoSync = true,
    this.autoSyncThreshold = 0,
    this.syncInterval = 0,           // <-- NEW
    this.httpTimeout = 60000,
    // ... rest unchanged
});
```

Add the field doc + declaration after `autoSyncThreshold`:

```dart
  /// Fixed interval in seconds between automatic HTTP sync flushes.
  ///
  /// When greater than `0` and [autoSync] is `true`, locations are **not**
  /// synced on every insert. Instead, a repeating timer fires every
  /// [syncInterval] seconds and flushes all pending locations in one batch.
  ///
  /// Useful for fleet/logistics apps that need business-aligned sync cadence
  /// (e.g., send driver position every 30–60 seconds).
  ///
  /// Set to `0` (default) to sync immediately on each insert (original
  /// behavior).
  ///
  /// Range: `0`–`3600`. Values above `3600` are clamped to `3600`.
  final int syncInterval;
```

- [ ] **Step 2: Update `fromMap`**

In `HttpConfig.fromMap` (line ~1407), add after `autoSyncThreshold`:

```dart
syncInterval: ensureInt(map['syncInterval'], fallback: 0),
```

- [ ] **Step 3: Update `toMap`**

In `HttpConfig.toMap()` (line ~1455), add after `'autoSyncThreshold'`:

```dart
'syncInterval': syncInterval,
```

- [ ] **Step 4: Update `==` operator**

In the `operator ==` body (line ~1477), add after `autoSyncThreshold == other.autoSyncThreshold`:

```dart
syncInterval == other.syncInterval &&
```

- [ ] **Step 5: Update `hashCode`**

In `Object.hash(...)` (line ~1495), add `syncInterval` after `autoSyncThreshold`:

```dart
Object.hash(
    url,
    method,
    httpRootProperty,
    batchSync,
    maxBatchSize,
    autoSync,
    autoSyncThreshold,
    syncInterval,        // <-- NEW
    httpTimeout,
    // ...rest
);
```

- [ ] **Step 6: Commit**

```bash
git add packages/tracelet/lib/src/models/config.dart
git commit -m "feat(dart): add syncInterval field to HttpConfig"
```

---

### Task 2: Add Dart unit tests for `syncInterval`

**Files:**
- Modify: `packages/tracelet/test/models_test.dart`

- [ ] **Step 1: Write tests**

Add after the existing `HttpConfig round-trip preserves retry fields` test (~line 250):

```dart
    test('HttpConfig syncInterval defaults to 0', () {
      const c = HttpConfig();
      expect(c.syncInterval, 0);
    });

    test('HttpConfig equality includes syncInterval', () {
      const a = HttpConfig(url: 'https://a.com', syncInterval: 30);
      const b = HttpConfig(url: 'https://a.com', syncInterval: 60);
      expect(a, isNot(equals(b)));

      const c = HttpConfig(url: 'https://a.com', syncInterval: 30);
      const d = HttpConfig(url: 'https://a.com', syncInterval: 30);
      expect(c, equals(d));
    });

    test('HttpConfig fromMap parses syncInterval', () {
      final c = HttpConfig.fromMap(const {
        'url': 'https://example.com',
        'syncInterval': 45,
      });
      expect(c.syncInterval, 45);
    });

    test('HttpConfig fromMap defaults syncInterval to 0', () {
      final c = HttpConfig.fromMap(const {'url': 'https://example.com'});
      expect(c.syncInterval, 0);
    });

    test('HttpConfig toMap includes syncInterval', () {
      const c = HttpConfig(
        url: 'https://example.com',
        syncInterval: 45,
      );
      final map = c.toMap();
      expect(map['syncInterval'], 45);
    });

    test('HttpConfig round-trip preserves syncInterval', () {
      const original = HttpConfig(
        url: 'https://example.com',
        syncInterval: 90,
      );
      final restored = HttpConfig.fromMap(original.toMap());
      expect(restored.syncInterval, 90);
    });
```

- [ ] **Step 2: Run tests**

```bash
cd packages/tracelet && dart test test/models_test.dart -v
```

Expected: ALL PASS

- [ ] **Step 3: Commit**

```bash
git add packages/tracelet/test/models_test.dart
git commit -m "test(dart): add syncInterval HttpConfig tests"
```

---

### Task 3: Add `getSyncInterval()` to Android `ConfigManager`

**Files:**
- Modify: `sdk/android/tracelet-sdk/src/main/kotlin/com/ikolvi/tracelet/sdk/ConfigManager.kt`

- [ ] **Step 1: Add default constant**

In the companion object defaults section (line ~66), add after `DEFAULT_AUTO_SYNC_THRESHOLD`:

```kotlin
const val DEFAULT_SYNC_INTERVAL = 0
```

- [ ] **Step 2: Add accessor**

After the `getAutoSyncThreshold()` function (line ~446), add:

```kotlin
    fun getSyncInterval(): Int =
        getInt("syncInterval", DEFAULT_SYNC_INTERVAL)
```

- [ ] **Step 3: Commit**

```bash
git add sdk/android/tracelet-sdk/src/main/kotlin/com/ikolvi/tracelet/sdk/ConfigManager.kt
git commit -m "feat(android): add getSyncInterval() to ConfigManager"
```

---

### Task 4: Add timer-based sync to Android `HttpSyncManager`

**Files:**
- Modify: `sdk/android/tracelet-sdk/src/main/kotlin/com/ikolvi/tracelet/sdk/http/HttpSyncManager.kt`

- [ ] **Step 1: Add timer field**

After the `pendingSyncOnConnect` declaration (line ~98), add:

```kotlin
    /** Scheduled future for interval-based sync. Null when syncInterval is 0. */
    @Volatile
    private var syncIntervalFuture: java.util.concurrent.ScheduledFuture<*>? = null

    /** Separate scheduler for interval-based sync timer. */
    private val scheduler = Executors.newSingleThreadScheduledExecutor()
```

- [ ] **Step 2: Start timer in `start()`**

At the end of the `start()` method (after `registerConnectivityCallback()`), add:

```kotlin
        // Start interval-based sync timer if configured
        startSyncIntervalTimer()
```

- [ ] **Step 3: Add `startSyncIntervalTimer()` and `stopSyncIntervalTimer()` methods**

Add after `stop()`:

```kotlin
    /** Start or restart the sync interval timer based on current config. */
    private fun startSyncIntervalTimer() {
        stopSyncIntervalTimer()
        val interval = config.getSyncInterval().toLong()
        if (interval <= 0 || !config.getAutoSync()) return

        val clampedInterval = interval.coerceAtMost(3600)
        Log.d(TAG, "Starting sync interval timer: every ${clampedInterval}s")
        syncIntervalFuture = scheduler.scheduleAtFixedRate(
            { syncAsync() },
            clampedInterval,   // initial delay — don't fire immediately on start
            clampedInterval,   // period
            TimeUnit.SECONDS
        )
    }

    /** Cancel the running sync interval timer if active. */
    private fun stopSyncIntervalTimer() {
        syncIntervalFuture?.cancel(false)
        syncIntervalFuture = null
    }
```

- [ ] **Step 4: Stop timer in `stop()`**

In the `stop()` method, add `stopSyncIntervalTimer()` before existing cleanup:

```kotlin
    fun stop() {
        stopSyncIntervalTimer()       // <-- NEW
        unregisterConnectivityCallback()
        httpClient?.dispatcher?.cancelAll()
        httpClient = null
    }
```

- [ ] **Step 5: Modify `onLocationInserted()` to skip per-insert sync when interval is active**

Replace the current `onLocationInserted()` body with:

```kotlin
    fun onLocationInserted() {
        if (!config.getAutoSync()) {
            Log.d(TAG, "onLocationInserted: autoSync disabled — skipping")
            return
        }
        val url = config.getHttpUrl()
        if (url == null) {
            Log.d(TAG, "onLocationInserted: no URL configured — skipping")
            return
        }

        // When syncInterval is active, the timer handles sync — skip per-insert sync.
        if (config.getSyncInterval() > 0) {
            Log.d(TAG, "onLocationInserted: syncInterval active — deferring to timer")
            return
        }

        // Skip auto-sync on cellular if configured
        if (config.getDisableAutoSyncOnCellular() && isCellular()) {
            Log.d(TAG, "onLocationInserted: on cellular with disableAutoSyncOnCellular — skipping")
            return
        }

        val threshold = config.getAutoSyncThreshold()
        if (threshold > 0) {
            insertsSinceLastSync++
            if (insertsSinceLastSync < threshold) return
        }

        insertsSinceLastSync = 0
        syncAsync()
    }
```

- [ ] **Step 6: Commit**

```bash
git add sdk/android/tracelet-sdk/src/main/kotlin/com/ikolvi/tracelet/sdk/http/HttpSyncManager.kt
git commit -m "feat(android): add timer-based sync interval to HttpSyncManager"
```

---

### Task 5: Add `getSyncInterval()` to iOS `ConfigManager`

**Files:**
- Modify: `sdk/ios/Sources/TraceletSDK/ConfigManager.swift`

- [ ] **Step 1: Add accessor**

After the `getAutoSyncThreshold()` line (line ~172), add:

```swift
    public func getSyncInterval() -> Int { cache["syncInterval"] as? Int ?? 0 }
```

- [ ] **Step 2: Commit**

```bash
git add sdk/ios/Sources/TraceletSDK/ConfigManager.swift
git commit -m "feat(ios): add getSyncInterval() to ConfigManager"
```

---

### Task 6: Add timer-based sync to iOS `HttpSyncManager`

**Files:**
- Modify: `sdk/ios/Sources/TraceletSDK/http/HttpSyncManager.swift`

- [ ] **Step 1: Add timer property**

After `_pendingSyncOnConnect` declaration (line ~30), add:

```swift
    /// Dispatch source timer for interval-based sync. `nil` when syncInterval is 0.
    private var syncIntervalTimer: DispatchSourceTimer?
```

- [ ] **Step 2: Start timer in `start()`**

At the end of the `start()` method (after `pathMonitor.start(...)`), add:

```swift
        // Start interval-based sync timer if configured
        startSyncIntervalTimer()
```

- [ ] **Step 3: Add `startSyncIntervalTimer()` and `stopSyncIntervalTimer()` methods**

Add after `stop()`:

```swift
    // MARK: - Sync interval timer

    /// Start or restart the sync interval timer based on current config.
    private func startSyncIntervalTimer() {
        stopSyncIntervalTimer()
        let interval = configManager.getSyncInterval()
        guard interval > 0, configManager.getAutoSync() else { return }

        let clampedInterval = min(interval, 3600)
        NSLog("[Tracelet] Starting sync interval timer: every \(clampedInterval)s")
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(
            deadline: .now() + .seconds(clampedInterval),
            repeating: .seconds(clampedInterval)
        )
        timer.setEventHandler { [weak self] in
            self?.sync(completion: nil)
        }
        timer.resume()
        syncIntervalTimer = timer
    }

    /// Cancel the running sync interval timer if active.
    private func stopSyncIntervalTimer() {
        syncIntervalTimer?.cancel()
        syncIntervalTimer = nil
    }
```

- [ ] **Step 4: Stop timer in `stop()`**

In the `stop()` method, add `stopSyncIntervalTimer()` before the existing `session.getAllTasks`:

```swift
    public func stop() {
        stopSyncIntervalTimer()  // <-- NEW

        session.getAllTasks { tasks in
            tasks.forEach { $0.cancel() }
        }
        pathMonitor.cancel()
        pathMonitor = NWPathMonitor()
    }
```

- [ ] **Step 5: Modify `onLocationInserted()` to skip per-insert sync when interval is active**

Add this guard at the top of `onLocationInserted()`, after the URL check:

```swift
    public func onLocationInserted() {
        guard configManager.getAutoSync() else {
            NSLog("[Tracelet] onLocationInserted: autoSync disabled — skipping")
            return
        }
        guard !configManager.getUrl().isEmpty else {
            NSLog("[Tracelet] onLocationInserted: no URL configured — skipping")
            return
        }

        // When syncInterval is active, the timer handles sync — skip per-insert sync.
        if configManager.getSyncInterval() > 0 {
            NSLog("[Tracelet] onLocationInserted: syncInterval active — deferring to timer")
            return
        }

        // Skip auto-sync on cellular if configured
        if configManager.getDisableAutoSyncOnCellular() && isCellular() {
            NSLog("[Tracelet] onLocationInserted: on cellular with disableAutoSyncOnCellular — skipping")
            return
        }

        let threshold = configManager.getAutoSyncThreshold()
        if threshold > 0 {
            let count = database.getLocationCount()
            guard count >= threshold else { return }
        }

        sync(completion: nil)
    }
```

- [ ] **Step 6: Commit**

```bash
git add sdk/ios/Sources/TraceletSDK/http/HttpSyncManager.swift
git commit -m "feat(ios): add timer-based sync interval to HttpSyncManager"
```

---

### Task 7: Update documentation

**Files:**
- Modify: `help/HTTP-SYNC.md`
- Modify: `help/CONFIGURATION.md`

- [ ] **Step 1: Add Interval Sync section to `help/HTTP-SYNC.md`**

Add before the "## Retry Strategy" section:

```markdown
---

## Interval-Based Sync

By default, `autoSync` flushes locations to the server each time one is
recorded. For fleet/logistics apps that need a **fixed business-defined
cadence**, set `syncInterval`:

```dart
HttpConfig(
  url: 'https://api.example.com/locations',
  autoSync: true,
  syncInterval: 45,   // Flush every 45 seconds
  batchSync: true,     // Recommended with interval sync
)
```

### How It Works

| syncInterval | Behavior |
|---|---|
| `0` (default) | Sync on every location insert (original behavior) |
| `> 0` | A repeating timer fires every N seconds and flushes all pending locations |

When `syncInterval > 0`:
- `onLocationInserted()` **does not** trigger a sync — the timer handles it.
- The timer calls the same sync engine used by manual `Tracelet.sync()`.
- If a sync is already in progress when the timer fires, it's skipped (no overlap).
- The timer respects `disableAutoSyncOnCellular` — if active, the timer-triggered sync checks connectivity before proceeding.
- `autoSync` must be `true` for the timer to start.
- Maximum value: `3600` (1 hour). Values above are clamped.

### Recommended Pairings

| Config | Why |
|---|---|
| `batchSync: true` | Multiple locations accumulate between timer ticks — send them in one request |
| `maxBatchSize: 50` | Prevent very large batches if interval is long |

### Manual Sync Still Works

`Tracelet.sync()` works normally regardless of `syncInterval`. Use it for
force-flush scenarios (e.g., trip end, app foregrounding).
```

- [ ] **Step 2: Add `syncInterval` to `help/CONFIGURATION.md`**

In the `http: HttpConfig(` section, add after `autoSyncThreshold`:

```dart
    syncInterval: 0,                 // Flush every N seconds (0 = per-insert)
```

- [ ] **Step 3: Commit**

```bash
git add help/HTTP-SYNC.md help/CONFIGURATION.md
git commit -m "docs: add syncInterval to HTTP sync and configuration guides"
```

---

### Task 8: Validation

- [ ] **Step 1: Run Dart formatter**

```bash
melos exec -- "dart format --set-exit-if-changed ."
```

Fix any formatting issues.

- [ ] **Step 2: Run analyzer**

```bash
melos run analyze
```

Fix any lint/analysis issues.

- [ ] **Step 3: Run Dart tests**

```bash
cd packages/tracelet && dart test
```

Expected: ALL PASS

- [ ] **Step 4: Build Android SDK**

```bash
cd sdk/android && ./gradlew :tracelet-sdk:assembleRelease
```

Expected: BUILD SUCCESSFUL

- [ ] **Step 5: Build iOS SDK**

```bash
cd sdk/ios && swift build
```

Expected: Build complete

- [ ] **Step 6: Final commit (if any fixups)**

```bash
git add -A && git commit -m "chore: fix formatting/lint for syncInterval feature"
```
