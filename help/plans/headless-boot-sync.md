# Plan: Headless sync after reboot (Android)

> **Status: IMPLEMENTED** (3.2.13). The `onDetachedFromEngine` change was
> **dropped** — verified unnecessary: `destroyAll()` does not clear
> `dartSyncInterceptor`, and the retained plugin instance already routes to the
> headless service when detached, so app-close (process alive) already works.
> The only real gap was cold boot (no plugin instance), fixed by the
> `ContentProvider`. Delivered:
> `TraceletStartupProvider` + `HeadlessSyncInterceptor` + manifest `<provider>` +
> a dead-code cleanup in `startBootTracking`, with Robolectric tests
> (`TraceletStartupProviderTest`, `ManifestComponentTest`).

## Problem

After a device reboot, `startOnBoot` starts the foreground service and native tracking
(the notification appears), but **HTTP sync does not work** until the user opens the app.
Symptoms reported:
- Sync silently does nothing after reboot.
- Opening the app shows the SDK in a "not initialized" state.

## Root cause

On a cold reboot, tracking is started by `BootReceiver` (in the **tracelet-sdk** module)
in a process that has **no Flutter UI engine**. The Flutter plugin's
`TraceletAndroidPlugin.onAttachedToEngine` never runs — and that method is the **only**
place that wires the Dart↔native sync bridge:

- `sdk.dartSyncInterceptor = this` — the bridge whose impl already falls back to the
  headless engine for token refresh + custom body
  (`TraceletAndroidPlugin.kt:129`).
- `TraceletBootstrap.headlessDispatcherFactory = { ctx -> HeadlessTaskService(ctx) }`
  (`TraceletAndroidPlugin.kt:137`).

So in the boot process both are `null`. When `NativeSyncProvider.triggerSync()` runs:
- `sdk.dartSyncInterceptor` is null → it cannot refresh the (expired) auth token and
  cannot ask Dart to build the custom body;
- it falls through to a plain native POST with the **stale persisted token** → 401 (or a
  rejected default payload) → no sync.

Everything else is already in place:
- The Dart app registers `registerHeadlessHeadersCallback` + `registerHeadlessSyncBodyBuilder`
  (example `main.dart:88-93`); callback IDs are **persisted to SharedPreferences** by
  `HeadlessTaskService.registerCallbacks()`, so they survive reboot.
- `HeadlessTaskService` already implements `requestHeadersRefresh()` (token refresh) and
  `requestCustomSyncBody()` (custom body) by spinning up a background `FlutterEngine`.

The only missing link is **native wiring in the cold-boot process**.

The "not initialized" state is a *sibling symptom*, not the cause: `isReady` is a per-process
flag set only by `ready()` (Dart). The boot process runs `bootstrapForBackground()` which
deliberately does not set it.

## Goal

In a process with no UI engine (cold boot / headless restart), `NativeSyncProvider` must be
able to invoke the already-registered, persisted headless Dart callbacks to (a) refresh the
auth token and (b) build the custom body — so sync works after reboot without the user
opening the app.

## Design

Wire the headless plumbing at **process start** instead of only on UI-engine attach.

A `ContentProvider` is the chosen hook: Android instantiates every declared `ContentProvider`
and calls `onCreate()` on **every process creation**, including a `BootReceiver`-spawned
process, and **before** any `BroadcastReceiver.onReceive()`. This requires no new dependency
(unlike `androidx.startup`).

### New components (all in the `tracelet_android` plugin module)

1. **`HeadlessSyncInterceptor`** — a `DartSyncInterceptor` implementation backed by a single
   shared `HeadlessTaskService`. It routes:
   - `requestSyncBody(locations)` → `hs.requestCustomSyncBody(locations, TIMEOUT)`
   - `requestFreshHeaders()` → `hs.requestHeadersRefresh(TIMEOUT)`
   - `requestTokenRefresh()` → `hs.requestHeadersRefresh(TIMEOUT)`

   It must hold **one** `HeadlessTaskService` instance for the process (so header-refresh and
   body-build reuse the same background engine and its latches line up). Constructed with
   `ConfigManager.getInstance(ctx)` so `setDynamicHeaders` persists.

2. **`TraceletStartupProvider`** — a no-op `ContentProvider` whose `onCreate()`:
   - sets `TraceletBootstrap.headlessDispatcherFactory` (if null) to create a
     `HeadlessTaskService`, and
   - sets `sdk.dartSyncInterceptor` (if null) to a `HeadlessSyncInterceptor`.

   Both are set **only if currently null**, so they act as a *background fallback*: when a UI
   engine later attaches, `onAttachedToEngine` overrides `dartSyncInterceptor = this` with the
   richer main-engine interceptor (existing behavior, unchanged).

   `query/insert/update/delete/getType` return null/0 (it is not a real provider).

3. **Manifest entry** (`packages/tracelet_android/android/src/main/AndroidManifest.xml`):
   ```xml
   <provider
       android:name=".TraceletStartupProvider"
       android:authorities="${applicationId}.tracelet-startup"
       android:exported="false"
       android:initOrder="100" />
   ```
   `${applicationId}` keeps the authority unique per host app (no collisions across apps that
   embed Tracelet).

### Lifecycle reconciliation

- **Cold boot (no UI):** provider sets headless interceptor → `NativeSyncProvider` uses it →
  headless callbacks run → token refreshed + body built → sync succeeds.
- **App opened:** `onAttachedToEngine` overrides with the main-engine interceptor (better:
  no extra engine spin-up). Order is guaranteed (provider runs at process start, before the
  Activity/engine).
- **App backgrounded/detached:** `onDetachedFromEngine` currently may leave
  `dartSyncInterceptor` pointing at a dead engine. **Change:** on detach, *restore* the
  headless fallback (`sdk.dartSyncInterceptor = HeadlessSyncInterceptor(...)`) instead of
  leaving a stale main-engine reference, so background sync keeps working after the UI goes
  away (not just after a reboot). (Verify current `onDetachedFromEngine` behavior and adjust.)

### Why not put this in the SDK module

`HeadlessTaskService` (and the `FlutterEngine` it drives) lives in the plugin module; the SDK
cannot reference it. The SDK already owns the seams (`TraceletBootstrap.headlessDispatcherFactory`,
`HeadlessDispatcher`, `HeadersRefreshable`, `DartSyncInterceptor`); the plugin just needs to
populate them at process start. Hence the provider lives in the plugin.

## Files touched

| File | Change |
|------|--------|
| `packages/tracelet_android/android/.../flutter/sync/HeadlessSyncInterceptor.kt` | **new** — `DartSyncInterceptor` backed by `HeadlessTaskService` |
| `packages/tracelet_android/android/.../flutter/TraceletStartupProvider.kt` | **new** — `ContentProvider` process-start hook |
| `packages/tracelet_android/android/src/main/AndroidManifest.xml` | add `<provider>` |
| `packages/tracelet_android/android/.../flutter/TraceletAndroidPlugin.kt` | `onDetachedFromEngine`: restore headless fallback instead of leaving stale interceptor |
| `sdk/android/.../service/LocationService.kt` | remove the dead `headless` local at `startBootTracking` (or actually use the dispatcher) — minor cleanup |

## Testing

- **Robolectric (plugin module):** after `TraceletStartupProvider().onCreate()` with no UI
  engine attached, assert `TraceletSdk.getInstance(ctx).dartSyncInterceptor != null` and
  `TraceletBootstrap.headlessDispatcherFactory != null`.
- **Robolectric:** assert that when a UI engine attaches after the provider ran,
  `dartSyncInterceptor` becomes the plugin instance (main-engine path wins), and after detach
  it falls back to a `HeadlessSyncInterceptor` (non-null).
- **Unit:** `HeadlessSyncInterceptor.requestSyncBody` delegates to
  `HeadlessTaskService.requestCustomSyncBody` (mock the service) and returns the sentinel when
  no callback is registered.
- Manual: reboot device with app NOT opened; confirm via logcat that `headersRefresh` /
  `syncBodyBuild` dispatch and the POST carries a fresh token.

## App-side requirement (document, already satisfied by example)

The host app MUST register the headless callbacks (top-level functions) so there is a Dart
entrypoint to invoke headlessly:
- `Tracelet.registerHeadlessTask(...)`
- `Tracelet.registerHeadlessHeadersCallback(...)` — refresh + `setDynamicHeaders`
- `Tracelet.registerHeadlessSyncBodyBuilder(...)` — build + return body

The example already does this (`example/lib/main.dart:88-93`). Add a short note to the README /
sync docs that headless sync after reboot requires these.

## iOS parity

iOS has no `BOOT_COMPLETED`; it relaunches via region/significant-location monitoring into a
background `UIApplication`. The equivalent question is whether the iOS background relaunch path
sets up the sync interceptor + token refresh without the Dart UI running. **Out of scope for
this change** — track as a separate investigation/issue and verify on iOS before claiming
cross-platform headless-sync parity.

## Release

Lands in **3.2.13** if not yet published; otherwise **3.2.14**. Changelog entries:
- `tracelet_android`, `tracelet`, `sdk/android`: **FIX**(android): HTTP sync (auth-token
  refresh + custom sync body) now works headlessly after a reboot, by wiring the headless
  Dart bridge at process start instead of only on UI-engine attach.

## Risks / open questions

- **Engine spin-up cost on boot:** each headless sync may start a `FlutterEngine`. Acceptable
  (debounced; same mechanism used elsewhere) but confirm it is torn down/reused sensibly.
- **Provider runs in every process** (incl. `:remote` isolate processes if any) — the
  null-guards make it cheap and idempotent; verify no multi-process surprises.
- **`onDetachedFromEngine` restoration** must not race with a quick re-attach; set the fallback
  synchronously on detach.
- Confirm `HeadlessTaskService`'s manifest `<service>` declaration (currently
  `BIND_JOB_SERVICE`) is correct/needed — it is used as a plain class, not a bound service.
