import { useRef, useCallback } from "react";

/**
 * useDragScroll
 *
 * Adds mouse-drag horizontal scrolling to an overflow-x container.
 * Touch (mobile) already works via native scroll; this is for desktop mice.
 *
 * Two problems this version fixes over a naive implementation:
 *
 *  1. Dragging over an <img> or <a> did nothing, because the browser's
 *     native image/link drag (ghost image) hijacked the gesture. We call
 *     preventDefault on dragstart, and the consumer sets draggable={false}
 *     on images.
 *
 *  2. A drag would also fire a click on the card underneath (navigating to
 *     the detail page). We track whether the pointer actually moved past a
 *     small threshold; if so, we swallow the click that follows in the
 *     capture phase.
 *
 * Usage:
 *   const drag = useDragScroll();
 *   <div className="ticket-list" {...drag.containerProps}>…cards…</div>
 */
export default function useDragScroll() {
  const ref = useRef(null);
  const state = useRef({
    dragging: false,
    moved: false,
    startX: 0,
    scrollLeft: 0,
  });

  const onMouseDown = useCallback((e) => {
    const el = ref.current;
    if (!el) return;
    if (e.button !== 0) return; // primary button only
    state.current = {
      dragging: true,
      moved: false,
      startX: e.pageX - el.offsetLeft,
      scrollLeft: el.scrollLeft,
    };
    el.style.cursor = "grabbing";
    el.style.userSelect = "none";
  }, []);

  const onMouseMove = useCallback((e) => {
    const s = state.current;
    if (!s.dragging) return;
    const el = ref.current;
    if (!el) return;
    e.preventDefault();
    const x = e.pageX - el.offsetLeft;
    const walk = x - s.startX;
    if (Math.abs(walk) > 5) s.moved = true; // past ~5px = a drag, not a click
    el.scrollLeft = s.scrollLeft - walk * 1.2; // 1.2x for a natural feel
  }, []);

  const endDrag = useCallback(() => {
    const el = ref.current;
    if (!el) return;
    state.current.dragging = false;
    el.style.cursor = "grab";
    el.style.userSelect = "";
  }, []);

  // Capture-phase click handler: if the pointer moved (a drag), cancel the
  // click so the card doesn't navigate. Reset the flag afterwards.
  const onClickCapture = useCallback((e) => {
    if (state.current.moved) {
      e.preventDefault();
      e.stopPropagation();
      state.current.moved = false;
    }
  }, []);

  // Block the browser's native drag (ghost image / link drag) so the gesture
  // stays a scroll even when it starts on an <img> or <a>.
  const onDragStart = useCallback((e) => {
    e.preventDefault();
  }, []);

  return {
    ref,
    containerProps: {
      ref,
      onMouseDown,
      onMouseMove,
      onMouseUp: endDrag,
      onMouseLeave: endDrag,
      onClickCapture,
      onDragStart,
      style: { cursor: "grab" },
    },
  };
}
