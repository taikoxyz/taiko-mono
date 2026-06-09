"use client";

import { useCallback, useSyncExternalStore } from "react";

import {
  type Breakpoints,
  getBreakpoints,
  getServerBreakpoints,
  subscribeBreakpoints,
} from "@/libs/util/responsiveCheck";

/**
 * React hook replacement for the svelte `isDesktop`/`isTablet`/`isMobile` derived
 * stores in libs/util/responsiveCheck.ts.
 *
 * Built on `useSyncExternalStore` over `window.matchMedia` at the original
 * breakpoints (desktop >=1200px, tablet 768-1199px, mobile <=767px). The server
 * snapshot returns `isDesktop: true` (others false), matching the original SSR
 * defaults and avoiding a hydration-mismatch flash.
 */
export function useResponsive(): Breakpoints {
  return useSyncExternalStore(
    subscribeBreakpoints,
    getBreakpoints,
    getServerBreakpoints,
  );
}

/**
 * Generic media-query hook. Subscribes to a single `(min/max-width: …)` style query
 * and returns whether it currently matches. SSR-safe (returns `false` on the server).
 */
export function useMediaQuery(query: string): boolean {
  const subscribe = useCallback(
    (onChange: () => void) => {
      if (typeof window === "undefined") return () => {};
      const mql = window.matchMedia(query);
      mql.addEventListener("change", onChange);
      return () => mql.removeEventListener("change", onChange);
    },
    [query],
  );

  const getSnapshot = useCallback(() => {
    if (typeof window === "undefined") return false;
    return window.matchMedia(query).matches;
  }, [query]);

  const getServerSnapshot = useCallback(() => false, []);

  return useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);
}
