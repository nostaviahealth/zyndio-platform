import { useCallback, useEffect, useRef, useState } from 'react';

// Henry's override (#14): warning at 13 min, forced sign-out at 15 min.
export const IDLE_WARNING_MS = 13 * 60 * 1000;
export const IDLE_EXPIRE_MS = 15 * 60 * 1000;

// Activity events that reset the idle clock. `mousemove` is deliberately
// excluded - cursor drift must not keep a session alive (OVERRIDES #14).
export const IDLE_ACTIVITY_EVENTS = ['mousedown', 'keydown', 'scroll', 'touchstart'] as const;

export type IdleState = 'active' | 'warning' | 'expired';

interface UseIdleTimerOptions {
  onWarning?: () => void;
  onExpire?: () => void;
  warningMs?: number;
  expireMs?: number;
}

interface UseIdleTimerResult {
  state: IdleState;
  secondsUntilExpire: number;
  reset: () => void;
}

// Uses absolute setTimeout deadlines (not a polling setInterval) so
// vi.useFakeTimers() + advanceTimersByTime() tests are exact.
export function useIdleTimer({
  onWarning,
  onExpire,
  warningMs = IDLE_WARNING_MS,
  expireMs = IDLE_EXPIRE_MS,
}: UseIdleTimerOptions = {}): UseIdleTimerResult {
  const [state, setState] = useState<IdleState>('active');
  const [secondsUntilExpire, setSecondsUntilExpire] = useState(Math.ceil(expireMs / 1000));
  const stateRef = useRef<IdleState>('active');
  const warningTimer = useRef<ReturnType<typeof setTimeout>>();
  const expireTimer = useRef<ReturnType<typeof setTimeout>>();
  const tickTimer = useRef<ReturnType<typeof setTimeout>>();

  const clearTimers = useCallback(() => {
    clearTimeout(warningTimer.current);
    clearTimeout(expireTimer.current);
    clearTimeout(tickTimer.current);
  }, []);

  const reset = useCallback(() => {
    clearTimers();
    stateRef.current = 'active';
    setState('active');
    setSecondsUntilExpire(Math.ceil(expireMs / 1000));

    const deadline = Date.now() + expireMs;
    const tick = () => {
      const remaining = Math.max(0, Math.ceil((deadline - Date.now()) / 1000));
      setSecondsUntilExpire(remaining);
      if (remaining > 0) {
        tickTimer.current = setTimeout(tick, 1000);
      }
    };

    warningTimer.current = setTimeout(() => {
      stateRef.current = 'warning';
      setState('warning');
      tick();
      onWarning?.();
    }, warningMs);

    expireTimer.current = setTimeout(() => {
      stateRef.current = 'expired';
      setState('expired');
      clearTimeout(tickTimer.current);
      setSecondsUntilExpire(0);
      onExpire?.();
    }, expireMs);
  }, [clearTimers, expireMs, warningMs, onWarning, onExpire]);

  useEffect(() => {
    reset();
    return clearTimers;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    // Activity only resets the clock while still 'active' - once the
    // warning dialog is up, only an explicit "Stay signed in" (reset())
    // dismisses it, never incidental background activity.
    const handleActivity = () => {
      if (stateRef.current === 'active') reset();
    };
    IDLE_ACTIVITY_EVENTS.forEach((evt) => window.addEventListener(evt, handleActivity));
    return () => {
      IDLE_ACTIVITY_EVENTS.forEach((evt) => window.removeEventListener(evt, handleActivity));
    };
  }, [reset]);

  return { state, secondsUntilExpire, reset };
}
