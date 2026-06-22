import React, { useEffect, useRef, useState } from 'react';
import {
  SafeAreaView,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import {
  Tracelet,
  DesiredAccuracy,
  type Location,
  type State,
} from '@ikolvi/tracelet';

const PRIMARY = '#0B6E4F';
const DANGER = '#B00020';
const SURFACE = '#11181C';

export default function App() {
  const [enabled, setEnabled] = useState(false);
  const [isMoving, setIsMoving] = useState(false);
  const [location, setLocation] = useState<Location | null>(null);
  const [count, setCount] = useState(0);
  const [log, setLog] = useState<string[]>([]);

  const logRef = useRef<string[]>([]);
  const append = (line: string) => {
    const stamped = `${new Date().toLocaleTimeString()}  ${line}`;
    logRef.current = [stamped, ...logRef.current].slice(0, 50);
    setLog([...logRef.current]);
  };

  useEffect(() => {
    const subs = [
      Tracelet.onLocation((loc) => {
        setLocation(loc);
        append(
          `📍 ${loc.coords.latitude.toFixed(5)}, ${loc.coords.longitude.toFixed(5)}`
        );
        Tracelet.getCount().then(setCount).catch(() => {});
      }),
      Tracelet.onMotionChange((loc: Location) => {
        setIsMoving(loc.isMoving);
        append(loc.isMoving ? '🏃 moving' : '🛑 stationary');
      }),
      Tracelet.onEnabledChange((value) => {
        setEnabled(value);
        append(`⚙️ enabled = ${value}`);
      }),
      Tracelet.onProviderChange((p) => append(`📡 provider: gps=${p.gps}`)),
      Tracelet.onHttp((res) => append(`☁️ sync HTTP ${res.status}`)),
    ];

    bootstrap().catch((e) => append(`❌ ${String(e)}`));

    return () => subs.forEach((s) => s.remove());
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function bootstrap() {
    const state: State = await Tracelet.ready({
      geo: {
        desiredAccuracy: DesiredAccuracy.high,
        distanceFilter: 10,
      },
      app: {
        stopOnTerminate: false,
        startOnBoot: true,
      },
      logger: {
        debug: true,
      },
      android: {
        foregroundService: {
          title: 'Tracelet Example',
          text: 'Tracking your location',
        },
      },
    });
    setEnabled(state.enabled);
    setIsMoving(state.isMoving);
    setCount(await Tracelet.getCount());
    append('✅ ready');

    const status = await Tracelet.requestLocationAuthorization();
    append(`🔐 permission = ${status}`);
  }

  async function toggleTracking() {
    try {
      const state = enabled ? await Tracelet.stop() : await Tracelet.start();
      setEnabled(state.enabled);
    } catch (e) {
      append(`❌ ${String(e)}`);
    }
  }

  async function getCurrent() {
    try {
      const loc = await Tracelet.getCurrentPosition({
        samples: 2,
        persist: true,
      });
      setLocation(loc);
      append('🎯 getCurrentPosition');
    } catch (e) {
      append(`❌ ${String(e)}`);
    }
  }

  async function syncNow() {
    try {
      const synced = await Tracelet.sync();
      append(`☁️ synced ${synced.length} records`);
    } catch (e) {
      append(`❌ ${String(e)}`);
    }
  }

  async function clearDb() {
    await Tracelet.destroyLocations();
    setCount(0);
    append('🗑️ cleared database');
  }

  return (
    <SafeAreaView style={styles.safe}>
      <StatusBar barStyle="light-content" backgroundColor={SURFACE} />
      <View style={styles.header}>
        <Text style={styles.title}>Tracelet</Text>
        <Text style={styles.subtitle}>React Native Example</Text>
      </View>

      <View style={styles.statusRow}>
        <Stat label="Tracking" value={enabled ? 'ON' : 'OFF'} on={enabled} />
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
            ±{location.coords.accuracy.toFixed(0)}m · {location.coords.speed.toFixed(1)} m/s
          </Text>
        </View>
      )}

      <View style={styles.actions}>
        <Button
          label={enabled ? 'Stop tracking' : 'Start tracking'}
          color={enabled ? DANGER : PRIMARY}
          onPress={toggleTracking}
        />
        <Button label="Current position" onPress={getCurrent} />
        <Button label="Sync now" onPress={syncNow} />
        <Button label="Clear DB" color={DANGER} onPress={clearDb} />
      </View>

      <Text style={styles.logHeader}>Event log</Text>
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
      <Text style={[styles.statValue, { color: on ? PRIMARY : '#8A9197' }]}>
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
  safe: { flex: 1, backgroundColor: '#F4F6F8' },
  header: { paddingHorizontal: 20, paddingTop: 16, paddingBottom: 8 },
  title: { fontSize: 32, fontWeight: '800', color: SURFACE },
  subtitle: { fontSize: 14, color: '#5A6268', marginTop: 2 },
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
  },
  statLabel: { fontSize: 12, color: '#8A9197', marginBottom: 4 },
  statValue: { fontSize: 18, fontWeight: '700' },
  card: {
    marginHorizontal: 16,
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 16,
    elevation: 1,
  },
  cardLabel: { fontSize: 12, color: '#8A9197', marginBottom: 6 },
  coords: { fontSize: 18, fontWeight: '700', color: SURFACE },
  meta: { fontSize: 13, color: '#5A6268', marginTop: 4 },
  actions: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    padding: 16,
    gap: 10,
  },
  button: {
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderRadius: 10,
    flexGrow: 1,
    alignItems: 'center',
  },
  buttonText: { color: '#FFFFFF', fontWeight: '600', fontSize: 14 },
  logHeader: {
    paddingHorizontal: 20,
    paddingTop: 4,
    fontSize: 12,
    fontWeight: '700',
    color: '#8A9197',
    textTransform: 'uppercase',
  },
  log: { flex: 1, marginHorizontal: 16, marginBottom: 12 },
  logContent: { paddingVertical: 8 },
  logLine: {
    fontFamily: 'Courier',
    fontSize: 12,
    color: '#3A4147',
    paddingVertical: 2,
  },
});
