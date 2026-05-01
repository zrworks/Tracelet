# React Native Tracelet Module — Design Spec

**Date:** 2026-04-11  
**Author:** Copilot (brainstorming session)  
**Status:** Approved

---

## Goal

Create a React Native package (`react-native-tracelet`) that exposes the full Tracelet geolocation API to React Native apps. The module reuses the existing standalone native SDKs (`sdk/android/` and `sdk/ios/`) without copying or modifying any Flutter or native code.

## Constraints

- **No changes** to existing Flutter packages, native SDKs, or any existing code
- **Reuses** the framework-agnostic `TraceletSdk` (Android/Kotlin) and `TraceletSdk` (iOS/Swift) directly
- **New Architecture only** — Turbo Modules with Codegen, minimum React Native 0.71+
- **Mirrors Dart API** — same method names, similar types, event streams → EventEmitter subscriptions
- **Algorithms run natively** — KalmanFilter, AdaptiveSampling, BatteryBudget, TripManager, LocationProcessor all exist in the native SDKs; no TypeScript ports needed
- **Lives inside monorepo** at `packages/tracelet_react_native/`

## Architecture

```
┌──────────────────────────────────────────────────────┐
│  React Native App (TypeScript)                       │
│  import { Tracelet } from 'react-native-tracelet'    │
├──────────────────────────────────────────────────────┤
│  TypeScript API Layer                                │
│  ├─ Tracelet class (mirrors Dart Tracelet class)     │
│  ├─ EventEmitter → onLocation, onGeofence, etc.      │
│  └─ Types: Config, Location, Geofence, State, etc.  │
├──────────────────────────────────────────────────────┤
│  Codegen Spec (NativeTracelet.ts)                    │
│  └─ TurboModuleRegistrySpec interface                │
├─────────────────┬────────────────────────────────────┤
│  Android        │  iOS                               │
│  (Java module)  │  (ObjC++ module)                   │
│  ↓              │  ↓                                 │
│  Kotlin bridge  │  Swift bridge                      │
│  (RNEventDisp.) │  (RNEventDisp.)                    │
│  ↓              │  ↓                                 │
│  TraceletSdk    │  TraceletSdk                       │
│  (Maven/local)  │  (CocoaPods/local)                 │
└─────────────────┴────────────────────────────────────┘
```

### Layer Mapping (Flutter → React Native)

| Flutter Component | React Native Equivalent | Purpose |
|---|---|---|
| `TraceletHostApiImpl.kt` | `TraceletBridge.kt` | Receives calls from JS, delegates to `TraceletSdk` |
| `TraceletHostApiImpl.swift` | `TraceletBridge.swift` | Same, iOS side |
| `EventDispatcher.kt` | `RNEventDispatcher.kt` | Implements `TraceletEventSender`, sends events to RN |
| `EventDispatcher.swift` | `RNEventDispatcher.swift` | Same, iOS side |
| `TraceletAndroidPlugin.kt` | `TraceletModule.java` | TurboModule lifecycle entry point |
| `TraceletIosPlugin.swift` | `TraceletModule.mm` | Same, iOS side |
| Pigeon `TraceletApi.g.kt/swift` | Codegen-generated interfaces | Type-safe bridge contract |
| `PigeonTracelet` (Dart) | `Tracelet.ts` (TypeScript) | App-facing API class |
| `PigeonEventReceiver` (Dart) | `TraceletEventEmitter.ts` | Event stream subscriptions |
| Pigeon type defs | `types.ts` | Config, Location, State, Geofence, etc. |

## Package Structure

```
packages/tracelet_react_native/
├── package.json                          # npm: react-native-tracelet
├── tsconfig.json
├── babel.config.js
├── react-native-tracelet.podspec         # iOS CocoaPods
├── react-native.config.js               # RN CLI autolinking config
├── src/
│   ├── index.ts                          # Public exports
│   ├── NativeTracelet.ts                 # Codegen TurboModule spec
│   ├── Tracelet.ts                       # Main API class
│   ├── TraceletEventEmitter.ts           # Event subscription layer
│   └── types.ts                          # TypeScript types
├── android/
│   ├── build.gradle.kts
│   ├── src/main/
│   │   ├── AndroidManifest.xml
│   │   ├── java/com/ikolvi/tracelet/rn/
│   │   │   ├── TraceletModule.java       # TurboModule (Codegen Java)
│   │   │   └── TraceletPackage.java      # ReactPackage registration
│   │   └── kotlin/com/ikolvi/tracelet/rn/
│   │       ├── TraceletBridge.kt         # Kotlin SDK delegation
│   │       └── RNEventDispatcher.kt      # TraceletEventSender → RN
├── ios/
│   ├── TraceletModule.mm                 # ObjC++ TurboModule
│   ├── TraceletModule.h                  # Header
│   ├── TraceletBridge.swift              # Swift SDK delegation
│   ├── RNEventDispatcher.swift           # TraceletEventSending → RN
│   └── TraceletReactNative-Bridging-Header.h
├── example/                              # Example RN app for testing
│   ├── package.json
│   ├── App.tsx
│   ├── android/
│   └── ios/
└── __tests__/
    ├── Tracelet.test.ts                  # Unit tests
    └── types.test.ts                     # Type tests
```

## SDK Consumption

### Android (`build.gradle.kts`)

```kotlin
// Development: composite build for local SDK source
if (findProject(":tracelet-sdk") != null) {
    implementation(project(":tracelet-sdk"))
} else {
    // Release: published Maven Central artifact
    implementation("com.ikolvi:tracelet-sdk:1.0.10")
}
```

Root `settings.gradle.kts` of the example app includes:
```kotlin
includeBuild("../../../../sdk/android") // local SDK
```

### iOS (`react-native-tracelet.podspec`)

```ruby
# Development: local podspec via Podfile path
# Release: published CocoaPod
s.dependency 'TraceletSDK', '~> 1.0'
```

Development Podfile override:
```ruby
pod 'TraceletSDK', :path => '../../../../TraceletSDK.podspec'
```

## TypeScript API Surface

### Lifecycle

```typescript
class Tracelet {
  static ready(config: Config): Promise<State>;
  static start(): Promise<State>;
  static stop(): Promise<State>;
  static startGeofences(): Promise<State>;
  static startPeriodic(): Promise<State>;
  static getState(): Promise<State>;
  static setConfig(config: Partial<Config>): Promise<State>;
  static reset(config?: Config): Promise<State>;
}
```

### Location

```typescript
class Tracelet {
  static getCurrentPosition(options?: CurrentPositionOptions): Promise<Location>;
  static getLastKnownLocation(options?: LastKnownOptions): Promise<Location | null>;
  static watchPosition(options?: WatchPositionOptions): Promise<number>;
  static stopWatchPosition(watchId: number): Promise<boolean>;
  static changePace(isMoving: boolean): Promise<Location>;
  static getOdometer(): Promise<number>;
  static setOdometer(value: number): Promise<Location>;
}
```

### Geofencing

```typescript
class Tracelet {
  static addGeofence(geofence: Geofence): Promise<boolean>;
  static addGeofences(geofences: Geofence[]): Promise<boolean>;
  static removeGeofence(identifier: string): Promise<boolean>;
  static removeGeofences(identifiers?: string[]): Promise<boolean>;
  static getGeofences(): Promise<Geofence[]>;
  static getGeofence(identifier: string): Promise<Geofence | null>;
  static geofenceExists(identifier: string): Promise<boolean>;
}
```

### Database / Persistence

```typescript
class Tracelet {
  static getLocations(query?: LocationQuery): Promise<Location[]>;
  static getCount(query?: LocationQuery): Promise<number>;
  static destroyLocations(): Promise<boolean>;
  static destroySyncedLocations(): Promise<number>;
  static destroyLocation(uuid: string): Promise<boolean>;
  static insertLocation(params: Record<string, unknown>): Promise<string>;
}
```

### HTTP Sync

```typescript
class Tracelet {
  static sync(): Promise<Location[]>;
  static setDynamicHeaders(headers: Record<string, string>): Promise<void>;
  static setRouteContext(context: Record<string, unknown>): Promise<void>;
  static clearRouteContext(): Promise<void>;
}
```

### Permissions

```typescript
class Tracelet {
  static getPermissionStatus(): Promise<AuthorizationStatus>;
  static requestPermission(): Promise<AuthorizationStatus>;
  static getNotificationPermissionStatus(): Promise<number>;
  static requestNotificationPermission(): Promise<number>;
  static getMotionPermissionStatus(): Promise<number>;
  static requestMotionPermission(): Promise<number>;
  static canScheduleExactAlarms(): Promise<boolean>;
  static requestTemporaryFullAccuracy(purposeKey: string): Promise<number>; // iOS only
}
```

### Utility

```typescript
class Tracelet {
  static isPowerSaveMode(): Promise<boolean>;
  static getProviderState(): Promise<ProviderState>;
  static getDeviceInfo(): Promise<DeviceInfo>;
  static getSensors(): Promise<Sensors>;
  static playSound(soundId: number): Promise<void>;
  static isIgnoringBatteryOptimizations(): Promise<boolean>;
  static requestSettings(options: SettingsRequest): Promise<SettingsResponse>;
  static showSettings(): Promise<boolean>;
  static getSettingsHealth(): Promise<HealthCheckResult>;
  static openOemSettings(): Promise<boolean>;
}
```

### Logging

```typescript
class Tracelet {
  static getLog(): Promise<string>;
  static destroyLog(): Promise<boolean>;
  static emailLog(email: string): Promise<boolean>;
  static log(message: string): Promise<void>;
}
```

### Scheduling

```typescript
class Tracelet {
  static startSchedule(schedule: ScheduleEntry[]): Promise<State>;
  static stopSchedule(): Promise<State>;
}
```

### Enterprise

```typescript
class Tracelet {
  static verifyAuditTrail(): Promise<AuditVerification>;
  static getAuditProof(uuid: string): Promise<AuditProof>;
  static addPrivacyZone(zone: PrivacyZone): Promise<boolean>;
  static addPrivacyZones(zones: PrivacyZone[]): Promise<boolean>;
  static removePrivacyZone(identifier: string): Promise<boolean>;
  static removePrivacyZones(): Promise<boolean>;
  static getPrivacyZones(): Promise<PrivacyZone[]>;
  static isDatabaseEncrypted(): Promise<boolean>;
  static encryptDatabase(password: string): Promise<boolean>;
  static getAttestationToken(): Promise<string>;
  static getCarbonReport(): Promise<CarbonReport>;
  static getDeadReckoningState(): Promise<DeadReckoningState>;
}
```

### Events

```typescript
class Tracelet {
  static onLocation(callback: (location: Location) => void): Subscription;
  static onMotionChange(callback: (event: MotionChangeEvent) => void): Subscription;
  static onActivityChange(callback: (event: ActivityChangeEvent) => void): Subscription;
  static onProviderChange(callback: (event: ProviderChangeEvent) => void): Subscription;
  static onGeofence(callback: (event: GeofenceEvent) => void): Subscription;
  static onGeofencesChange(callback: (event: GeofencesChangeEvent) => void): Subscription;
  static onHeartbeat(callback: (event: HeartbeatEvent) => void): Subscription;
  static onHttp(callback: (event: HttpEvent) => void): Subscription;
  static onSchedule(callback: (event: ScheduleEvent) => void): Subscription;
  static onPowerSaveChange(callback: (isPowerSave: boolean) => void): Subscription;
  static onConnectivityChange(callback: (event: ConnectivityChangeEvent) => void): Subscription;
  static onEnabledChange(callback: (enabled: boolean) => void): Subscription;
  static onNotificationAction(callback: (action: string) => void): Subscription;
  static onAuthorization(callback: (event: AuthorizationEvent) => void): Subscription;
}

interface Subscription {
  remove(): void;
}
```

## Native Bridge: Event Flow

### Android

```
SDK background thread
  → TraceletEventSender.sendLocation(Map<String, Any?>)
    → RNEventDispatcher (implements TraceletEventSender)
      → marshals to main thread (Handler/Looper)
        → reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
          .emit("tracelet:location", WritableMap)
            → JS EventEmitter
              → user callback
```

### iOS

```
SDK background queue
  → TraceletEventSending.sendLocation([String: Any])
    → RNEventDispatcher (implements TraceletEventSending)
      → DispatchQueue.main.async
        → [self sendEventWithName:@"tracelet:location" body:dict]
            → JS EventEmitter
              → user callback
```

### Event Name Mapping

| SDK Event | RN Event Name | TypeScript Callback |
|---|---|---|
| `sendLocation` | `tracelet:location` | `onLocation` |
| `sendMotionChange` | `tracelet:motionchange` | `onMotionChange` |
| `sendActivityChange` | `tracelet:activitychange` | `onActivityChange` |
| `sendProviderChange` | `tracelet:providerchange` | `onProviderChange` |
| `sendGeofence` | `tracelet:geofence` | `onGeofence` |
| `sendGeofencesChange` | `tracelet:geofenceschange` | `onGeofencesChange` |
| `sendHeartbeat` | `tracelet:heartbeat` | `onHeartbeat` |
| `sendHttp` | `tracelet:http` | `onHttp` |
| `sendSchedule` | `tracelet:schedule` | `onSchedule` |
| `sendPowerSaveChange` | `tracelet:powersavechange` | `onPowerSaveChange` |
| `sendConnectivityChange` | `tracelet:connectivitychange` | `onConnectivityChange` |
| `sendEnabledChange` | `tracelet:enabledchange` | `onEnabledChange` |
| `sendAuthorization` | `tracelet:authorization` | `onAuthorization` |
| `sendNotificationAction` | `tracelet:notificationaction` | `onNotificationAction` |
| `sendWatchPosition` | `tracelet:watchposition` | (internal, routed to watchPosition callbacks) |

## Data Type Mapping

| Dart Type | TypeScript Type | Native Format |
|---|---|---|
| `Config` | `Config` (interface) | `Map<String, Any?>` / `[String: Any]` |
| `Location` | `Location` (interface) | `Map<String, Any?>` / `[String: Any]` |
| `State` | `State` (interface) | `Map<String, Any?>` / `[String: Any]` |
| `Geofence` | `Geofence` (interface) | `Map<String, Any?>` / `[String: Any]` |
| `GeofenceEvent` | `GeofenceEvent` (interface) | `Map<String, Any?>` / `[String: Any]` |
| `Activity` | `Activity` (interface) | `Map<String, Any?>` / `[String: Any]` |
| `ProviderState` | `ProviderState` (interface) | `Map<String, Any?>` / `[String: Any]` |

**Key advantage:** The native SDKs already work with raw `Map`/`Dict` types. The Flutter bridge converts these to Pigeon types at the boundary. The React Native bridge converts them to `WritableMap`/`NSDictionary` at the boundary. No intermediate conversion layer needed.

## What's NOT Included (vs Flutter)

1. **Headless Dart execution** — Not applicable. React Native uses Headless JS (Android) or native background processing. The SDK handles all background work natively.
2. **Pigeon codegen** — Replaced by React Native Codegen (TurboModule spec).
3. **Dart-side algorithms** — All algorithms (KalmanFilter, AdaptiveSampling, BatteryBudget, TripManager, LocationProcessor, GeofenceEvaluator) already exist in the native SDKs and will be used directly.
4. **Platform interface abstraction** — React Native doesn't use federated plugins. Single package with both platform implementations.
5. **Web support** — Can be added later as a separate concern (React Native Web).

## Headless / Background Event Handling

React Native apps that need to handle location events when the app is killed will use:

- **Android:** Headless JS Task — the SDK fires events while backgrounded; `RNEventDispatcher` checks if JS bridge is available, falls back to queuing events until next JS startup.
- **iOS:** The SDK already handles background location via `CLLocationManager` and stores events in the local database. When the app is re-launched, events are available via `getLocations()`.

This is simpler than the Flutter headless approach because the SDKs already persist data independently.

## Testing Strategy

- **TypeScript:** Jest unit tests for `Tracelet.ts`, `TraceletEventEmitter.ts`, type serialization
- **Android:** JUnit + Robolectric for `TraceletBridge.kt` and `RNEventDispatcher.kt`
- **iOS:** XCTest for `TraceletBridge.swift` and `RNEventDispatcher.swift`
- **Integration:** Example app with manual + Detox E2E tests

## npm Package

```json
{
  "name": "react-native-tracelet",
  "version": "1.0.0",
  "description": "Production-grade background geolocation for React Native",
  "main": "lib/commonjs/index",
  "module": "lib/module/index",
  "types": "lib/typescript/index.d.ts",
  "react-native": "src/index",
  "codegenConfig": {
    "name": "RNTraceletSpec",
    "type": "modules",
    "jsSrcsDir": "src"
  }
}
```
