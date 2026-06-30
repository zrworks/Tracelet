import { useEffect, useState } from 'react';
import { Tracelet } from '../Tracelet';
import type { Location } from '../types/Location';

/** Returns the most recent location, updating as new fixes arrive. */
export function useLocation(): Location | null {
  const [location, setLocation] = useState<Location | null>(null);

  useEffect(() => {
    const sub = Tracelet.onLocation(setLocation);
    return () => sub.remove();
  }, []);

  return location;
}
