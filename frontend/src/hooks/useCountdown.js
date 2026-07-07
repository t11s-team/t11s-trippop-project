import { useEffect, useState } from "react";

/**
 * Counts down to `target` (ms timestamp), ticking once per second.
 * Returns the remaining milliseconds, clamped at zero.
 *
 * Implementation notes:
 *  - The initial `remaining` is computed lazily by useState's initializer,
 *    so the first paint already shows the correct value without any
 *    synchronous setState inside an effect.
 *  - Subsequent updates happen inside setInterval's callback, which the
 *    `react-hooks/set-state-in-effect` rule explicitly allows (it only
 *    flags setState calls in the synchronous body of the effect).
 *  - If `target` changes mid-lifecycle, the effect's cleanup re-runs and
 *    a fresh interval is started; the next tick (within 1s) re-syncs to
 *    the new target. For our use case (one fixed promo deadline per page
 *    mount) that's acceptable.
 */
export function useCountdown(target) {
  const [remaining, setRemaining] = useState(() => Math.max(0, target - Date.now()));

  useEffect(() => {
    // setRemaining inside setInterval is asynchronous from React's POV,
    // so it is NOT flagged by react-hooks/set-state-in-effect.
    const id = setInterval(() => {
      setRemaining(Math.max(0, target - Date.now()));
    }, 1000);
    return () => clearInterval(id);
  }, [target]);

  return remaining;
}
