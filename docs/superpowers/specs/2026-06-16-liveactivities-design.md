# Feature Spec: iOS Live Activities & CLLiveUpdate

## Overview
This specification outlines the architecture for integrating iOS 17 `CLLiveUpdate` and `ActivityKit` into the Tracelet SDK to provide best-in-class background location battery optimization.

## Goals
1. Provide developers with a mechanism to start a background tracking session using a Live Activity.
2. Utilize `CLLiveUpdate.Updates()` asynchronous streams for highly battery-efficient location tracking.
3. Maintain backward compatibility with iOS 14-16 using the existing `CLLocationManagerDelegate` architecture.

## Approach: Hybrid Engine (Approach 1)

### 1. Live Activity UI Extension
- The SDK will provide a default, lightweight `TraceletLiveActivityView` (SwiftUI).
- Developers can either use this default view in their Xcode Widget Extension target or provide their own custom UI.
- The SDK will expose an `ActivityKit` wrapper to start/update/stop the Live Activity from Dart.

### 2. Parallel Location Engine
- `LocationEngine.swift` will be refactored to support two parallel tracking mechanisms.
- **Legacy Delegate (iOS 14-16):** The existing `CLLocationManagerDelegate` remains untouched for backward compatibility.
- **Modern Async/Await (iOS 17+):** When a Live Activity is active, a new Swift `Task` is spawned. This task iterates over `CLLiveUpdate.Updates()` and feeds the incoming locations directly into `LocationMapper.swift`.

### 3. Dart API Updates
- Add `tl.LiveActivityConfig` to `IosConfig`.
- Add `Tracelet.startLiveActivity()` and `Tracelet.stopLiveActivity()`.

## Sub-tasks for GitHub Issue
1. Update Pigeon API and Dart Models for `LiveActivityConfig`.
2. Create `ActivityKit` wrapper in Swift to manage Live Activity lifecycle.
3. Provide default `TraceletLiveActivityView` in SDK sources.
4. Implement `CLLiveUpdate` async stream consumer in `LocationEngine.swift`.
5. Update website documentation with Xcode Widget Extension setup guide.

## Open Questions
- Should the Live Activity be started automatically when `Tracelet.start()` is called (if configured), or should it strictly require a separate `Tracelet.startLiveActivity()` call by the developer?
