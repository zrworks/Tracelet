# Motion Detection Architecture

Tracelet uses a highly optimized, battery-efficient approach to detecting motion. A common misconception is that Tracelet wakes up the device based on GPS distance or a geofence around the stationary location (which is how iOS CoreLocation `startMonitoringSignificantLocationChanges` historically works). 

**Tracelet does NOT use distance-based GPS checks to manage motion state.** Instead, it relies on low-power hardware sensors.

This document clarifies how the state machine transitions between `MOVING` and `STATIONARY`.

## Core States
Tracelet maintains two primary states for continuous tracking:
1. **`MOVING`**: The GPS hardware is active and location updates are being recorded.
2. **`STATIONARY`**: The GPS hardware is fully turned off to save battery, and low-power hardware sensors take over to monitor for movement.

## State Transitions

### 1. Transitioning from `MOVING` to `STATIONARY`
When the device stops moving, Tracelet waits to ensure it's a permanent stop (not just waiting at a traffic light) before turning off the GPS.

- **Full Mode (Activity Recognition):** The Google Activity Recognition API or iOS CoreMotion reports an `ENTER_STILL` event.
- **Accelerometer-Only Mode:** The hardware accelerometer registers consecutive samples (~5 seconds worth) below a strict threshold (0.4 m/s²).

Once stillness is detected, a **Stop Timeout Countdown** begins (configurable via `stopTimeout` and `stopDetectionDelay`). If the device remains completely still for the duration of this timeout, the SDK declares the state as `STATIONARY` and powers down the GPS.

### 2. Transitioning from `STATIONARY` to `MOVING`
Once in the `STATIONARY` state, how does Tracelet know to wake up without using GPS? It relies instantly on hardware triggers:

- **Google Activity Recognition / iOS CoreMotion:** The OS-level APIs detect a moving activity (`IN_VEHICLE`, `WALKING`, `ON_BICYCLE`, etc.).
- **Significant Motion Sensor:** On Android, the hardware `TYPE_SIGNIFICANT_MOTION` sensor detects sustained movement.
- **Accelerometer Shake:** If the user drops or aggressively jolts the phone (exceeding a threshold of `2.5 m/s²`), the accelerometer fires an event. *(Note: To conserve battery, accelerometer events in stationary mode are batched, which may add a 0-3 second delay).*

The moment any of these low-power sensors trigger, the SDK instantly transitions back to `MOVING` and turns the GPS hardware back on to resume tracking.

## What about the "Heartbeat"?

You might notice a `heartbeatInterval` in the configuration. 

**Does the heartbeat wake up the GPS?** No. 

The heartbeat timer fires continuously (e.g., every 60 seconds) in both `STATIONARY` and `MOVING` states. Its only purpose is to act as a "keep-alive" ping for the Flutter application and to persist the *last known cached location* to the local database. 

During `STATIONARY`, the heartbeat **does not** turn on the GPS hardware to get a fresh fix, nor does it calculate the distance moved to trigger a state transition. State transitions are strictly governed by the motion hardware sensors detailed above.

## Handling False Positives
What happens if you are sitting at a desk and aggressively use or tilt your phone?

If the shake threshold is breached, the accelerometer might trigger a false positive, causing the SDK to briefly transition to `MOVING` and activate the GPS. 

However, we heavily filter these events (e.g., applying absolute values to accelerometer magnitudes to ignore gravity and simple rotations). If a false positive does occur, the moment the phone is held steady again, the SDK immediately detects stillness, restarts the stop timeout, and returns to `STATIONARY`.
