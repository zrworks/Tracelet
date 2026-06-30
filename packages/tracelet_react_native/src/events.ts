import { NativeEventEmitter, NativeModules, Platform } from 'react-native';

/** A cancellable event subscription. */
export interface Subscription {
  remove(): void;
}

/** Native event names emitted by the Tracelet module. */
export const TraceletEvents = {
  location: 'tracelet:location',
  motionChange: 'tracelet:motionChange',
  speedMotionChange: 'tracelet:speedMotionChange',
  activityChange: 'tracelet:activityChange',
  providerChange: 'tracelet:providerChange',
  geofence: 'tracelet:geofence',
  geofencesChange: 'tracelet:geofencesChange',
  heartbeat: 'tracelet:heartbeat',
  http: 'tracelet:http',
  schedule: 'tracelet:schedule',
  powerSaveChange: 'tracelet:powerSaveChange',
  connectivityChange: 'tracelet:connectivityChange',
  enabledChange: 'tracelet:enabledChange',
  notificationAction: 'tracelet:notificationAction',
  authorization: 'tracelet:authorization',
  watchPosition: 'tracelet:watchPosition',
  drivingEvent: 'tracelet:drivingEvent',
  impact: 'tracelet:impact',
  modeChange: 'tracelet:modeChange',
  crashModelStatus: 'tracelet:crashModelStatus',
  trip: 'tracelet:trip',
  budgetAdjustment: 'tracelet:budgetAdjustment',
} as const;

const LINKING_ERROR =
  `The package '@ikolvi/tracelet' doesn't seem to be linked. Make sure:\n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

const nativeModule =
  NativeModules.TraceletReactNative ??
  new Proxy(
    {},
    {
      get() {
        throw new Error(LINKING_ERROR);
      },
    }
  );

const emitter = new NativeEventEmitter(nativeModule);

/** Subscribe to a native event with a typed payload. */
export function addEventListener<T>(
  eventName: string,
  callback: (payload: T) => void
): Subscription {
  return emitter.addListener(eventName, callback);
}
