"use client";

import { useEffect, useRef, type RefObject } from "react";

/**
 * React port of the original SvelteKit `withHoverAndFocusListener` custom action.
 *
 * Reports hover/focus state changes of a node back to the caller via callbacks.
 *
 * Svelte actions follow the `(node, params) => { destroy }` contract, which has
 * no direct React equivalent. The DOM logic is portable, the action signature is
 * not — so this is re-implemented as a hook taking a ref to the target node.
 *
 * Behavior preserved from the original:
 *  - `focus`/`blur` -> `onFocusChange(document.activeElement === node)`.
 *  - `mouseenter` -> `onHoverChange(true)`, `mouseleave` -> `onHoverChange(false)`.
 *
 * NOTE on a divergence from the original (intentional, not a behavior change for
 * the live runtime): the original `destroy()` passed FRESH arrow functions to
 * `removeEventListener` for the mouseenter/mouseleave handlers, so those two
 * listeners were never actually removed (a latent listener leak). In React,
 * effect cleanup must reliably detach to avoid leaking listeners across
 * re-renders/unmounts under StrictMode/fast-refresh, so stable named handlers
 * are used for all four events. The observable hover/focus callbacks fire
 * identically; only the (broken) teardown is corrected.
 *
 * @param nodeRef Ref to the target element (the original action's `node`).
 * @param params  `{ onFocusChange, onHoverChange }`.
 */
export function useHoverAndFocusListener(
  nodeRef: RefObject<HTMLElement | null>,
  {
    onFocusChange,
    onHoverChange,
  }: {
    onFocusChange: (focused: boolean) => void;
    onHoverChange: (hovered: boolean) => void;
  },
): void {
  const onFocusChangeRef = useRef(onFocusChange);
  const onHoverChangeRef = useRef(onHoverChange);

  // Keep the latest callbacks in refs so changing them never re-attaches the DOM
  // listeners. Synced in an effect to satisfy React 19's
  // no-ref-writes-during-render rule.
  useEffect(() => {
    onFocusChangeRef.current = onFocusChange;
    onHoverChangeRef.current = onHoverChange;
  });

  useEffect(() => {
    const node = nodeRef.current;
    if (!node) return;

    const updateFocusState = () => {
      onFocusChangeRef.current(document.activeElement === node);
    };

    const handleMouseEnter = () => {
      onHoverChangeRef.current(true);
    };

    const handleMouseLeave = () => {
      onHoverChangeRef.current(false);
    };

    node.addEventListener("focus", updateFocusState);
    node.addEventListener("blur", updateFocusState);
    node.addEventListener("mouseenter", handleMouseEnter);
    node.addEventListener("mouseleave", handleMouseLeave);

    return () => {
      node.removeEventListener("focus", updateFocusState);
      node.removeEventListener("blur", updateFocusState);
      node.removeEventListener("mouseenter", handleMouseEnter);
      node.removeEventListener("mouseleave", handleMouseLeave);
    };
  }, [nodeRef]);
}

export default useHoverAndFocusListener;
