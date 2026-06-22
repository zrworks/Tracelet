# PLAN — React Native Support for Tracelet (`@ikolvi/tracelet`)

> Branch: `feat/react-native-support`
> npm package: **`@ikolvi/tracelet`** (already reserved on npm; keeps the Tracelet brand)
> Goal: A first-class React Native binding that exposes **the full Dart public API** of Tracelet,
> backed by the **already-published, framework-agnostic native SDKs** — no Rust or native logic rewrite.

---

## 1. Why this is now low-risk

The first RN attempt (published `0.1.0-alpha.x`, then removed in commit `054a013a`) failed for ONE reason:
it bundled the native `tracelet-core` Kotlin/Swift source via **monorepo-relative paths** that don't exist
in published packages. That whole problem is gone:

| Layer | Status (v3.5.1) | RN consumes it via |
| --- | --- | --- |
| Android native SDK | `com.ikolvi:tracelet-sdk:3.5.1` on **Maven Central** | `implementation("com.ikolvi:tracelet-sdk:3.5.1")` |
| iOS native SDK | `TraceletSDK` 3.5.1 on **CocoaPods** / SPM | `s.dependency 'TraceletSDK'` |
| Rust core | Compiled **into** those SDKs (`.so` in AAR, `.xcframework` auto-downloaded) | transitively — nothing to do |

Both SDKs are explicitly designed to be hosted from any framework:

- **Android:** `TraceletSdk.getInstance(context)` — all methods take/return `Map<String, Any?>`.
- **iOS:** `TraceletSdk.shared` — all methods take/return `[String: Any]`.
- **Events:** `setEventSender(...)` + the `TraceletListener` / `TraceletEventSending` interface (22 callbacks).
- **Sync:** `registerSyncProvider(...)` for native-driven HTTP sync.

Because every SDK method already speaks **maps**, the RN bridge is a *pure marshalling layer*:
`JS object → ReadableMap/NSDictionary → TraceletSdk → map result → Promise`. This is the same shape the
Flutter Pigeon plugin produces, so behaviour parity is guaranteed.

---

## 2. Architecture

```
JS / TS app
   │  import { Tracelet } from '@ikolvi/tracelet'
   ▼
src/Tracelet.ts            ← static facade mirroring the Dart `Tracelet` class
src/NativeTracelet.ts      ← TurboModule spec (codegen: TraceletReactNativeSpec)
src/types/*                ← every Config / model / enum / event from the Dart API
src/hooks/*                ← useLocation / useTraceletState / useGeofences / ...
   │   (New Architecture TurboModule + RCTDeviceEventEmitter for streams)
   ▼
Android: TraceletModule.kt (ReactContextBaseJavaModule / Turbo)
         → TraceletSdk.getInstance(ctx)         (com.ikolvi:tracelet-sdk)
         → implements TraceletListener → emits events to JS
iOS:     TraceletModule.swift (RCTEventEmitter)
         → TraceletSdk.shared                   (TraceletSDK pod)
         → implements TraceletEventSending → emits events to JS
   ▼
Rust core (already inside the SDKs) — battery engine, EKF, geofence R-tree,
SQLite, delta encoding, crash/telematics, sync.
```

**Design rules**
- The TS facade is the single source of truth for the JS API; it mirrors the Dart `Tracelet` class 1:1.
- The native modules contain **zero business logic** — they only marshal maps and forward events.
- Method names + payload keys match the Pigeon contract exactly (same maps the SDK already emits).
- New Architecture only (RN 0.76+ default). No legacy bridge fallback.

---

## 3. Tooling (recommended modern setup)

- **Scaffold:** `create-react-native-library` conventions, **TurboModule** (`codegenConfig.type: "modules"`).
- **Build:** `react-native-builder-bob` → `commonjs` + `module` + `typescript` targets.
- **Lang:** TypeScript 5.x (strict, no `any` in public API — matches the Dart "no `dynamic`" rule).
- **Tests:** Jest + ts-jest for the TS facade/marshalling and hooks.
- **Lint/format:** eslint (flat config) + prettier, mirroring repo conventions.
- **Release:** changesets (`@ikolvi/tracelet` is independent of the Dart/pub.dev versioning).
- **Min versions:** RN 0.76+, Android `minSdk 26`, iOS 14.0, matching the native SDKs.

---

## 4. Full feature coverage (mapped to Dart API)

Every public Dart capability is exposed. Grouped by area; each row = TS facade method(s) → SDK call.

### 4.1 Lifecycle
`ready` · `start` · `stop` · `startGeofences` · `startPeriodic` · `getState` · `getHealth`
· `setConfig` · `reset` · `isHeadlessRegistered` · `isKalmanFilterEnabled` · `activeConfig`

### 4.2 Location
`getCurrentPosition` · `getLastKnownLocation` · `watchPosition` · `stopWatchPosition`
· `changePace` · `getOdometer` · `setOdometer`

### 4.3 Geofencing (circular + polygon)
`addGeofence` · `addGeofences` · `removeGeofence` · `removeGeofences` · `getGeofences`
· `getGeofence` · `geofenceExists`  (polygon via `Geofence.vertices`)

### 4.4 Persistence / DB / Logs
`getLocations` · `getCount` · `getPendingLocations` · `getPendingLocationCount`
· `destroyLocations` · `destroySyncedLocations` · `destroyLocation` · `insertLocation`
· `getLogs` · `clearLogs` · `getLog` · `destroyLog` · `emailLog` · `log`

### 4.5 HTTP Sync + custom body/headers
`sync` · `setDynamicHeaders` · `setHeadersCallback` · `refreshHeaders` · `setTokenRefreshCallback`
· `setSyncBodyBuilder` · `setSyncBodyResponse` · `registerHeadlessSyncBodyBuilder`
· `registerHeadlessHeadersCallback` · `setRouteContext` · `clearRouteContext`
(SSL pinning, delta compression, batch/retry are config-only — fully covered by `HttpConfig`.)

### 4.6 Telematics / Crash & Fall / Transport Mode
`getTelematicsEvents` · `destroyTelematicsEvents` · `simulateTelematicsEvent`
· `debugRunCrashModelInference` · `confirmImpact` · `cancelImpact`
(driving events, AI crash model, fused classifier — all config-driven via
`TelematicsConfig` / `ImpactConfig` / `ClassifierConfig`.)

### 4.7 Motion / Activity
`getMotionAuthorization` · `requestMotionAuthorization` · `changePace`
(full Activity-Recognition mode and accelerometer-only mode via `MotionConfig`.)

### 4.8 Permissions / Settings / OEM
`getLocationAuthorization` · `requestLocationAuthorization` · `getNotificationAuthorization`
· `requestNotificationAuthorization` · `canScheduleExactAlarms` · `openExactAlarmSettings`
· `hasBackgroundPermission` · `requestTemporaryFullAccuracyAuthorization`
· `requestSettings` · `showSettings` · `openAppSettings` · `openLocationSettings`
· `openBatterySettings` · `getSettingsHealth` · `openOemSettings` · `showPowerManager`

### 4.9 Device / Diagnostics
`getProviderState` · `getSensors` · `getDeviceInfo` · `isPowerSaveMode`
· `isIgnoringBatteryOptimizations` · `getHealth` · `playSound`

### 4.10 Background / Scheduling / Headless
`startBackgroundTask` · `stopBackgroundTask` · `registerHeadlessTask`
· `startSchedule` · `stopSchedule`
(Android Headless JS task; iOS BGTask — see §6 headless notes.)

### 4.11 Enterprise
- **Audit trail:** `verifyAuditTrail` · `getAuditProof`
- **Privacy zones:** `addPrivacyZone(s)` · `removePrivacyZone(s)` · `getPrivacyZones`
- **DB encryption:** `isDatabaseEncrypted` · `encryptDatabase`
- **Device attestation:** `getAttestationToken`
- **Dead reckoning:** `getDeadReckoningState`
- **Carbon estimator:** `getCarbonReport`
- **Compliance:** `generateComplianceReport`

### 4.12 Event streams (22) — via `RCTDeviceEventEmitter`
`onLocation` · `onMotionChange` · `onSpeedMotionChange` · `onActivityChange` · `onProviderChange`
· `onGeofence` · `onGeofencesChange` · `onHeartbeat` · `onHttp` · `onSchedule` · `onPowerSaveChange`
· `onConnectivityChange` · `onEnabledChange` · `onNotificationAction` · `onAuthorization`
· `onDrivingEvent` · `onImpact` · `onModeChange` · `onCrashModelStatus` · `onTrip`
· `onBudgetAdjustment` · (watchPosition callback)

### 4.13 Config objects (mirrored as TS interfaces)
`Config` + `GeoConfig` · `AppConfig` · `AndroidConfig` (+ `ForegroundServiceConfig`) · `IosConfig`
(+ `LiveActivityConfig`) · `HttpConfig` · `LoggerConfig` · `MotionConfig` · `GeofenceConfig`
· `PersistenceConfig` · `AuditConfig` · `PrivacyZoneConfig` · `SecurityConfig` · `AttestationConfig`
· `TelematicsConfig` · `ClassifierConfig` · `ImpactConfig` · `LocationFilter`
+ factory presets `highAccuracy / balanced / lowPower / passive`.

### 4.14 React hooks (DX layer)
`useLocation()` · `useTraceletState()` · `useGeofences()` · `useMotionChange()` · `useGeofenceEvents()`

---

## 5. Package layout

```
packages/tracelet_react_native/
├── package.json                # name: @ikolvi/tracelet, bob + codegen config
├── tsconfig.json  tsconfig.build.json
├── babel.config.js  eslint.config.mjs  jest.config.js
├── react-native.config.js
├── TraceletReactNative.podspec # depends on TraceletSDK
├── README.md  CHANGELOG.md  INSTALL.md
├── .changeset/
├── src/
│   ├── index.tsx               # public exports
│   ├── Tracelet.ts             # static facade (full API)
│   ├── NativeTracelet.ts       # TurboModule spec
│   ├── events.ts               # event-emitter plumbing
│   ├── types/
│   │   ├── Config.ts  Location.ts  Geofence.ts  State.ts
│   │   ├── Events.ts  Enums.ts  Errors.ts
│   │   ├── Telematics.ts  Privacy.ts  Audit.ts  Health.ts  Sync.ts
│   ├── hooks/
│   │   └── useLocation.ts  useTraceletState.ts  useGeofences.ts ...
│   └── __tests__/
├── android/
│   ├── build.gradle            # implementation com.ikolvi:tracelet-sdk
│   ├── src/main/AndroidManifest.xml
│   └── src/main/java/com/ikolvi/tracelet/reactnative/
│       ├── TraceletModule.kt       # marshals maps → TraceletSdk
│       ├── TraceletPackage.kt
│       └── TraceletHeadlessService.kt
├── ios/
│   ├── TraceletModule.swift        # marshals dicts → TraceletSdk.shared
│   └── TraceletModule.mm           # RCT module registration
└── example/                    # RN example app exercising the API
```

> Note: javaPackage moves from the old `com.tracelet.reactnative` to **`com.ikolvi.tracelet.reactnative`**
> to match the `com.ikolvi` namespace used everywhere else (Maven group, SDK package).

---

## 6. Known platform constraints (documented, not blockers)

- **Headless custom sync body / header callbacks (JS):** RN has no Dart-isolate equivalent. v1 ships:
  native default payload + static/dynamic headers + `setRouteContext` (works when terminated).
  JS-driven `setSyncBodyBuilder`/header callbacks while *terminated* are **v2** (Android Headless JS,
  iOS BGTaskScheduler). Foreground callbacks work in v1.
- **iOS Live Activities / notifications:** config passthrough in v1; UI templates are app-side.
- **TurboModule only:** drops RN < 0.73 / legacy arch (acceptable — matches SDK min versions).

---

## 7. Phases

| Phase | Deliverable | Exit criteria |
| --- | --- | --- |
| **P0** | Branch + this plan + package scaffold (config files) | `npm i` resolves, `tsc --noEmit` clean |
| **P1** | Full TS type layer (all configs/models/enums/events) | types compile, exported from `index.tsx` |
| **P2** | TS `Tracelet` facade + `NativeTracelet` spec + events plumbing | facade typechecks; jest marshalling tests pass |
| **P3** | Android `TraceletModule.kt` → `TraceletSdk` + event sender | builds; example app gets locations on device |
| **P4** | iOS `TraceletModule.swift` → `TraceletSdk.shared` + event sender | builds; example app gets locations on device |
| **P5** | React hooks + example app screens | hooks render live data |
| **P6** | Headless (Android JS task) + scheduling | terminated-app events delivered |
| **P7** | README / INSTALL / CHANGELOG + `@ikolvi/tracelet` 1.0.0 publish | published, install verified in fresh app |

---

## 8. Out of scope (v1)
- Web (RN-Web) target — Flutter `tracelet_web` is separate; revisit later.
- Expo config plugin — add after the bare-RN package is stable.
- Supabase/Firebase RN convenience wrappers — separate `@ikolvi/tracelet-supabase` etc. later.
