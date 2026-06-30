import React, { useEffect, useRef, useState } from 'react';
import {
  SafeAreaView,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
  Platform,
} from 'react-native';
import {
  Tracelet,
  DesiredAccuracy,
  TrackingMode,
  MotionDetectionMode,
  NotificationPriority,
  type Location,
  type State,
} from '@ikolvi/tracelet';

const PRIMARY = '#0B6E4F';
const DANGER = '#B00020';
const SURFACE = '#11181C';
const SECONDARY = '#5A6268';
const LIGHT_BG = '#F4F6F8';

export default function App() {
  const [isReady, setIsReady] = useState(false);
  const [enabled, setEnabled] = useState(false);
  const [isMoving, setIsMoving] = useState(false);
  const [isPeriodicMode, setIsPeriodicMode] = useState(false);
  const [location, setLocation] = useState<Location | null>(null);
  const [count, setCount] = useState(0);
  const [log, setLog] = useState<string[]>([]);
  
  const logRef = useRef<string[]>([]);

  const appendLog = (tag: string, message: string) => {
    const ts = new Date().toLocaleTimeString('en-US', { hour12: false });
    const stamped = `[${ts}] ${tag}: ${message}`;
    logRef.current = [stamped, ...logRef.current].slice(0, 200); // keep up to 200 logs
    setLog([...logRef.current]);
  };

  useEffect(() => {
    const subs = [
      Tracelet.onLocation((loc) => {
        setLocation(loc);
        appendLog(
          'LOCATION',
          `${loc.coords.latitude.toFixed(6)}, ${loc.coords.longitude.toFixed(6)} acc=${loc.coords.accuracy.toFixed(1)}m odo=${loc.odometer.toFixed(0)}m`
        );
        Tracelet.getCount().then(setCount).catch(() => {});
      }),
      Tracelet.onMotionChange((loc) => {
        setIsMoving(loc.isMoving);
        if (loc.coords) {
          setLocation(loc);
        }
        appendLog('MOTION', loc.isMoving ? 'MOVING' : 'STATIONARY');
      }),
      Tracelet.onActivityChange((evt) => {
        appendLog('ACTIVITY', `${evt.activity.name} (${evt.confidence.name})`);
      }),
      Tracelet.onProviderChange((evt) => {
        if (evt.mockLocationsDetected) {
          appendLog('⚠️ MOCK', 'Mock location provider detected!');
        }
        if (evt.gpsFallback) {
          appendLog('⚠️ GPS FALLBACK', 'GPS disabled — using Wi-Fi/Cell');
        }
        appendLog('PROVIDER', `status=${evt.status} gps=${evt.gps} network=${evt.network}`);
      }),
      Tracelet.onGeofence((evt) => {
        appendLog(evt.identifier.startsWith('poly_') ? 'POLYGON' : 'GEOFENCE', `${evt.action} → ${evt.identifier}`);
      }),
      Tracelet.onHeartbeat((evt) => {
        appendLog('HEARTBEAT', `${evt.location.coords.latitude.toFixed(5)}, ${evt.location.coords.longitude.toFixed(5)}`);
      }),
      Tracelet.onHttp((evt) => {
        appendLog('HTTP', `status=${evt.status} success=${evt.success}`);
      }),
      Tracelet.onConnectivityChange((evt) => {
        appendLog('CONNECTIVITY', `connected=${evt.connected}`);
      }),
      Tracelet.onEnabledChange((on) => {
        setEnabled(on);
        appendLog('ENABLED', on ? 'ON' : 'OFF');
      }),
      Tracelet.onBudgetAdjustment((evt) => {
        appendLog(
          'BUDGET',
          `drain=${evt.currentBatteryDrain.toFixed(2)}%/hr target=${evt.targetBudget.toFixed(2)}%/hr df=${evt.newDistanceFilter.toFixed(0)}m`
        );
      }),
    ];

    bootstrap().catch((e) => appendLog('ERROR', String(e)));

    return () => subs.forEach((s) => s.remove());
  }, []);

  async function bootstrap() {
    try {
      const locStatus = await Tracelet.requestLocationAuthorization();
      appendLog('PERMISSION', `Location: ${locStatus}`);

      if (Platform.OS === 'android') {
        const notifStatus = await Tracelet.requestNotificationAuthorization();
        appendLog('PERMISSION', `Notification: ${notifStatus}`);
      }

      // ── Motion / Activity Recognition permission ──
      // Critical for pace detection to work on Android (ACTIVITY_RECOGNITION)
      const motionStatus = await Tracelet.requestMotionAuthorization();
      appendLog('PERMISSION', `Motion: ${motionStatus}`);

      const state: State = await Tracelet.ready({
        geo: {
          distanceFilter: 0,
          resolveAddress: true,
          filter: {
            useKalmanFilter: true,
            mockDetectionLevel: 2,
          },
          batteryBudgetPerHour: 3,
        },
        app: {
          stopOnTerminate: false,
          startOnBoot: true,
          heartbeatInterval: 10,
        },
        android: {
          periodicUseForegroundService: true,
          locationUpdateInterval: 2000,
          deferTime: 10000,
          foregroundService: Platform.OS === 'android' ? {
            title: '📍 Tracelet Demo Active',
            text: 'Smart Notifications — disappears when app is open!',
            channelId: 'tracelet_demo_channel',
            channelName: 'Tracelet Demo Background',
            priority: NotificationPriority.high,
            showNotificationOnPauseOnly: true,
          } : { enabled: false },
          scheduleUseAlarmManager: true,
        },
        ios: {
          preventSuspend: true,
          useBackgroundActivitySession: true,
        },
        motion: {
          stopTimeout: 1,
          motionDetectionMode: MotionDetectionMode.smart,
          shakeThreshold: 2,
          speedStationaryDelay: 30,
          stationaryPeriodicInterval: 60,
        },
        http: {
          url: 'http://192.168.20.103:8099/locations',
          autoSyncDelay: 5000,
        },
        audit: { enabled: true },
        security: { encryptDatabase: true },
        persistence: {
          maxDaysToPersist: 7,
          maxRecordsToPersist: 5000,
        },
        logger: { debug: true },
      });

      setIsReady(true);
      setEnabled(state.enabled);
      setIsMoving(state.isMoving);
      setIsPeriodicMode(state.trackingMode === TrackingMode.periodic);
      setCount(await Tracelet.getCount());
      appendLog('READY', `enabled=${state.enabled} mode=${state.trackingMode}`);
    } catch (e) {
      appendLog('ERROR', `ready() failed: ${e}`);
    }
  }

  async function startWithNotification() {
    try {
      const state = await Tracelet.start();
      setEnabled(state.enabled);
      setIsPeriodicMode(false);
      appendLog('START', `Background tracking started enabled=${state.enabled}`);
    } catch (e) {
      appendLog('ERROR', `startWithNotification() failed: ${e}`);
    }
  }

  async function startPeriodic() {
    try {
      await Tracelet.setConfig({
        geo: {
          periodicLocationInterval: 15 * 60, // 15 min
          periodicDesiredAccuracy: DesiredAccuracy.medium,
        },
        app: { heartbeatInterval: -1 }, // disable heartbeats
      });
      const state = await Tracelet.startPeriodic();
      setEnabled(state.enabled);
      setIsPeriodicMode(true);
      appendLog('PERIODIC', `Started 15min interval mode=${state.trackingMode}`);
    } catch (e) {
      appendLog('ERROR', `startPeriodic() failed: ${e}`);
    }
  }

  async function stopTracking() {
    try {
      const state = await Tracelet.stop();
      setEnabled(state.enabled);
      setIsPeriodicMode(false);
      appendLog('STOP', `Tracking stopped enabled=${state.enabled}`);
    } catch (e) {
      appendLog('ERROR', `stopTracking() failed: ${e}`);
    }
  }

  async function getCurrent() {
    try {
      const loc = await Tracelet.getCurrentPosition({
        desiredAccuracy: DesiredAccuracy.high,
        timeout: 30,
      });
      setLocation(loc);
      appendLog('POSITION', `${loc.coords.latitude.toFixed(6)}, ${loc.coords.longitude.toFixed(6)} acc=${loc.coords.accuracy.toFixed(1)}m`);
    } catch (e) {
      appendLog('ERROR', `getCurrentPosition() failed: ${e}`);
    }
  }

  async function changePace() {
    try {
      await Tracelet.changePace(!isMoving);
      setIsMoving(!isMoving);
      appendLog('PACE', !isMoving ? 'forced MOVING' : 'forced STATIONARY');
    } catch (e) {
      appendLog('ERROR', `changePace() failed: ${e}`);
    }
  }

  async function addGeofence() {
    if (!location) {
      appendLog('WARN', 'No location yet — get a position first');
      return;
    }
    try {
      const id = `geo_${Date.now()}`;
      await Tracelet.addGeofence({
        identifier: id,
        latitude: location.coords.latitude,
        longitude: location.coords.longitude,
        radius: 200,
        notifyOnDwell: true,
        loiteringDelay: 30000,
      });
      appendLog('GEOFENCE+', `${id} r=200m added at current location`);
    } catch (e) {
      appendLog('ERROR', `addGeofence() failed: ${e}`);
    }
  }

  async function syncNow() {
    try {
      const synced = await Tracelet.sync();
      appendLog('SYNC', `☁️ synced ${synced.length} records`);
    } catch (e) {
      appendLog('ERROR', `sync() failed: ${e}`);
    }
  }

  async function clearDb() {
    await Tracelet.destroyLocations();
    setCount(0);
    appendLog('DB', '🗑️ cleared database');
  }

  return (
    <SafeAreaView style={styles.safe}>
      <StatusBar barStyle="light-content" backgroundColor={SURFACE} />
      <View style={styles.header}>
        <Text style={styles.title}>Tracelet</Text>
        <Text style={styles.subtitle}>React Native Example</Text>
      </View>

      <View style={styles.statusRow}>
        <Stat label="Tracking" value={enabled ? (isPeriodicMode ? 'PERIODIC' : 'ON') : 'OFF'} on={enabled} />
        <Stat label="Motion" value={isMoving ? 'MOVING' : 'STILL'} on={isMoving} />
        <Stat label="DB" value={String(count)} on={count > 0} />
      </View>

      {location && (
        <View style={styles.card}>
          <Text style={styles.cardLabel}>Last location</Text>
          <Text style={styles.coords}>
            {location.coords.latitude.toFixed(6)},{' '}
            {location.coords.longitude.toFixed(6)}
          </Text>
          <Text style={styles.meta}>
            ±{location.coords.accuracy.toFixed(0)}m · {location.coords.speed.toFixed(1)} m/s · {location.odometer?.toFixed(0) ?? 0}m odo
          </Text>
        </View>
      )}

      <View style={styles.actionsContainer}>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.actions}>
          {enabled ? (
            <Button label="Stop Tracking" color={DANGER} onPress={stopTracking} />
          ) : (
            <>
              <Button label="Start (Foreground Svc)" color={PRIMARY} onPress={startWithNotification} />
              <Button label="Start Periodic" color={PRIMARY} onPress={startPeriodic} />
            </>
          )}
          <Button label="Current Position" onPress={getCurrent} />
          <Button label="Toggle Pace" onPress={changePace} />
          <Button label="Add Geofence" onPress={addGeofence} />
          <Button label="Sync HTTP" onPress={syncNow} />
          <Button label="Clear DB" color={DANGER} onPress={clearDb} />
        </ScrollView>
      </View>

      <Text style={styles.logHeader}>Event Log (Latest at top)</Text>
      <ScrollView style={styles.log} contentContainerStyle={styles.logContent}>
        {log.map((line, i) => (
          <Text key={i} style={styles.logLine}>
            {line}
          </Text>
        ))}
      </ScrollView>
    </SafeAreaView>
  );
}

function Stat({ label, value, on }: { label: string; value: string; on: boolean }) {
  return (
    <View style={styles.stat}>
      <Text style={styles.statLabel}>{label}</Text>
      <Text style={[styles.statValue, { color: on ? PRIMARY : SECONDARY }]}>
        {value}
      </Text>
    </View>
  );
}

function Button({
  label,
  onPress,
  color = SURFACE,
}: {
  label: string;
  onPress: () => void;
  color?: string;
}) {
  return (
    <TouchableOpacity
      style={[styles.button, { backgroundColor: color }]}
      onPress={onPress}
      activeOpacity={0.8}
    >
      <Text style={styles.buttonText}>{label}</Text>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: LIGHT_BG },
  header: { paddingHorizontal: 20, paddingTop: 16, paddingBottom: 8 },
  title: { fontSize: 32, fontWeight: '800', color: SURFACE },
  subtitle: { fontSize: 14, color: SECONDARY, marginTop: 2 },
  statusRow: {
    flexDirection: 'row',
    paddingHorizontal: 16,
    paddingVertical: 12,
    gap: 12,
  },
  stat: {
    flex: 1,
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: 'center',
    elevation: 1,
    shadowColor: '#000',
    shadowOpacity: 0.05,
    shadowRadius: 4,
    shadowOffset: { width: 0, height: 2 },
  },
  statLabel: { fontSize: 12, color: SECONDARY, marginBottom: 4 },
  statValue: { fontSize: 16, fontWeight: '700' },
  card: {
    marginHorizontal: 16,
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 16,
    elevation: 1,
    shadowColor: '#000',
    shadowOpacity: 0.05,
    shadowRadius: 4,
    shadowOffset: { width: 0, height: 2 },
  },
  cardLabel: { fontSize: 12, color: SECONDARY, marginBottom: 6 },
  coords: { fontSize: 18, fontWeight: '700', color: SURFACE },
  meta: { fontSize: 13, color: SECONDARY, marginTop: 4 },
  actionsContainer: {
    marginTop: 16,
    marginBottom: 8,
  },
  actions: {
    paddingHorizontal: 16,
    gap: 10,
    alignItems: 'center',
  },
  button: {
    paddingVertical: 10,
    paddingHorizontal: 16,
    borderRadius: 10,
    justifyContent: 'center',
    alignItems: 'center',
  },
  buttonText: { color: '#FFFFFF', fontWeight: '600', fontSize: 13 },
  logHeader: {
    paddingHorizontal: 20,
    paddingTop: 8,
    paddingBottom: 4,
    fontSize: 12,
    fontWeight: '700',
    color: SECONDARY,
    textTransform: 'uppercase',
  },
  log: { 
    flex: 1, 
    marginHorizontal: 16, 
    marginBottom: 12,
    backgroundColor: '#FFFFFF',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#E1E4E8'
  },
  logContent: { padding: 12 },
  logLine: {
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
    fontSize: 11,
    color: '#24292E',
    paddingVertical: 2,
    lineHeight: 16,
  },
});
