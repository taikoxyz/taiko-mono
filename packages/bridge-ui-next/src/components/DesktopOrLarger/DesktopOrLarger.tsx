"use client";

import { useEffect } from "react";

import { useMediaQuery } from "@/hooks/useResponsive";

/**
 * React port of `components/DesktopOrLarger/DesktopOrLarger.svelte`.
 *
 * This component programmatically mirrors a CSS media query so callers can
 * show/hide elements or render different components based on whether the
 * viewport is desktop-or-larger (`min-width: 768px`). The original was a
 * render-less Svelte component exposing the match via a two-way `bind:is`.
 *
 * COMPONENT CONVENTION mapping:
 *   - Svelte `bind:is` (two-way) -> controlled `value` + `onValueChange(detail)`.
 *   - Renders no DOM (returns `null`), matching the original.
 *   - `onMount`/`onDestroy` matchMedia wiring is delegated to the shared
 *     `useMediaQuery` hook (built on `useSyncExternalStore`), which is
 *     functionally identical: `false` on the server / first paint, then resolved
 *     from `window.matchMedia('(min-width: 768px)')`.
 *
 * Most React-idiomatic consumers should prefer the `useDesktopOrLarger()` hook
 * (exported below) instead of rendering this render-less component, exactly as
 * the migrated `Card`/`Stepper`/`TokenDropdown` components do. This component is
 * provided for path parity and for callers that want to lift the value into
 * their own state via `onValueChange`.
 */

const DESKTOP_OR_LARGER_QUERY = "(min-width: 768px)";

export interface DesktopOrLargerProps {
  /**
   * Controlled current value (Svelte `bind:is`). Optional — the component is the
   * source of truth and reports changes via `onValueChange`; pass this back in if
   * you want a fully controlled binding.
   */
  value?: boolean;
  /** Fired whenever the desktop-or-larger match changes (Svelte `bind:is` write). */
  onValueChange?: (is: boolean) => void;
}

export default function DesktopOrLarger({
  value,
  onValueChange,
}: DesktopOrLargerProps) {
  const is = useMediaQuery(DESKTOP_OR_LARGER_QUERY);

  // Mirror the resolved match back to the parent (Svelte two-way `bind:is`).
  useEffect(() => {
    if (value !== is) {
      onValueChange?.(is);
    }
    // Only re-run when the resolved match flips; `value`/`onValueChange` are
    // controlled inputs from the parent and intentionally excluded to avoid
    // feedback loops (matching the original write-on-change semantics).
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [is]);

  // Render-less, exactly like the original Svelte component.
  return null;
}

/**
 * Hook form of `DesktopOrLarger` — the idiomatic React replacement for the
 * renderless `<DesktopOrLarger bind:is={isDesktopOrLarger} />` pattern. Returns
 * `true` when the viewport is `>= 768px`. SSR-safe (returns `false` on the
 * server / first paint, matching the original's pre-mount default).
 */
export function useDesktopOrLarger(): boolean {
  return useMediaQuery(DESKTOP_OR_LARGER_QUERY);
}
