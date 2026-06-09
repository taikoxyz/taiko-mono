"use client";

import { useEffect, useRef } from "react";

/**
 * React port of the original SvelteKit `closeOnClickOrEscape` custom action.
 *
 * Svelte actions follow the `(node, params) => { destroy, update }` contract,
 * which has no direct React equivalent. The DOM logic is portable, the action
 * signature is not — so this is re-implemented as a hook.
 *
 * Behavior is preserved verbatim from the original:
 *  - Listeners are attached to `document` in the CAPTURE phase (`true`).
 *  - Attachment is deferred via `setTimeout(..., 0)` so the very click that
 *    opened the element doesn't immediately re-trigger the callback.
 *  - A `click` anywhere fires `callback()`; a `keydown` fires `callback()` only
 *    when the key is `Escape`.
 *  - When `enabled` is false the listeners are detached.
 *
 * The original action ignored its `node` argument entirely (any click/Escape
 * closes), so this hook does not require a ref. `callback` is read through a ref
 * so changing it never re-attaches listeners — matching the original `update`
 * which reassigned `callback` without touching the listeners.
 *
 * @param enabled  Whether the listeners are active.
 * @param callback Invoked on any click or on the Escape key.
 */
export function useCloseOnClickOrEscape(
  enabled: boolean,
  callback: () => void,
): void {
  const callbackRef = useRef(callback);

  // Keep the latest callback in a ref so changing it never re-attaches listeners
  // (mirrors the original `update` which reassigned `callback` only). Synced in
  // an effect to satisfy React 19's no-ref-writes-during-render rule.
  useEffect(() => {
    callbackRef.current = callback;
  });

  useEffect(() => {
    if (!enabled) return;

    let attached = false;

    const handleEvent = (event: Event) => {
      if (!attached) return;

      if (event.type === "click") {
        callbackRef.current();
      }

      // For keydown events, check if the key is Escape
      if (
        event.type === "keydown" &&
        (event as KeyboardEvent).key === "Escape"
      ) {
        callbackRef.current();
      }
    };

    const attachListeners = () => {
      document.addEventListener("click", handleEvent, true);
      document.addEventListener("keydown", handleEvent, true);
      attached = true;
    };

    const detachListeners = () => {
      document.removeEventListener("click", handleEvent, true);
      document.removeEventListener("keydown", handleEvent, true);
      attached = false;
    };

    const timeoutId = setTimeout(attachListeners, 0); // Delay the attachment of listeners

    return () => {
      clearTimeout(timeoutId);
      detachListeners();
    };
  }, [enabled]);
}

export default useCloseOnClickOrEscape;
