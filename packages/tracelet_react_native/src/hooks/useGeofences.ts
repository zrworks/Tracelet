import { useCallback, useEffect, useState } from 'react';
import { Tracelet } from '../Tracelet';
import type { Geofence } from '../types/Geofence';

/** Returns the currently monitored geofences and a `refresh` function. */
export function useGeofences(): {
  geofences: Geofence[];
  refresh: () => void;
} {
  const [geofences, setGeofences] = useState<Geofence[]>([]);

  const refresh = useCallback(() => {
    Tracelet.getGeofences().then(setGeofences);
  }, []);

  useEffect(() => {
    refresh();
    const sub = Tracelet.onGeofencesChange(refresh);
    return () => sub.remove();
  }, [refresh]);

  return { geofences, refresh };
}
