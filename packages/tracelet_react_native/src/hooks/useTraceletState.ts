import { useEffect, useState } from 'react';
import { Tracelet } from '../Tracelet';
import type { State } from '../types/State';

/** Returns the current plugin {@link State}, updating on enable/disable changes. */
export function useTraceletState(): State | null {
  const [state, setState] = useState<State | null>(null);

  useEffect(() => {
    let mounted = true;
    Tracelet.getState().then((s) => {
      if (mounted) setState(s);
    });

    const refresh = () => {
      Tracelet.getState().then((s) => {
        if (mounted) setState(s);
      });
    };

    const enabledSub = Tracelet.onEnabledChange(refresh);
    const scheduleSub = Tracelet.onSchedule(setState);

    return () => {
      mounted = false;
      enabledSub.remove();
      scheduleSub.remove();
    };
  }, []);

  return state;
}
