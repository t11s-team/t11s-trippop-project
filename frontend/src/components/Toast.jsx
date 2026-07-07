import { useEffect, useRef } from "react";
import Icon from "./Icon.jsx";

/**
 * Auto-dismissing toast. Parent owns the message state and clears it via onDone.
 *
 * `onDone` is read via a ref so a parent that recreates the callback every
 * render (the common React case) doesn't keep resetting the dismiss timer.
 * The effect re-runs only when the message itself changes.
 */
export default function Toast({ message, type = "success", onDone, duration = 2600 }) {
  const onDoneRef = useRef(onDone);

  // Sync the latest onDone into the ref after commit, not during render —
  // React 19's `react-hooks/refs` rule forbids writing ref.current in the
  // render body. This effect has no deps, so it runs after every render.
  useEffect(() => {
    onDoneRef.current = onDone;
  });

  useEffect(() => {
    if (!message) return undefined;
    const id = setTimeout(() => onDoneRef.current?.(), duration);
    return () => clearTimeout(id);
  }, [message, duration]);

  if (!message) return null;
  return (
    <div className={`toast${type === "error" ? " toast--error" : ""}`} role="status">
      <Icon name={type === "error" ? "x" : "check"} size={18} />
      {message}
    </div>
  );
}
