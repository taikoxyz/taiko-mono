// Ported from libs/util/responsiveCheck.ts.
//
// The original used svelte `writable`/`derived` stores driven by `window.matchMedia`
// listeners. React consumers should use the `useResponsive` / `useMediaQuery` hooks
// in `@/hooks/useResponsive` (built on `useSyncExternalStore`). This module keeps the
// underlying, framework-agnostic media-query logic so non-React callers and the hook
// share a single source of truth.
//
// Breakpoints (identical to the original):
//   desktop: (min-width: 1200px)
//   tablet:  (min-width: 768px) and (max-width: 1199px)
//   mobile:  (max-width: 767px)

export const DESKTOP_MEDIA_QUERY = "(min-width: 1200px)";
export const TABLET_MEDIA_QUERY = "(min-width: 768px) and (max-width: 1199px)";
export const MOBILE_MEDIA_QUERY = "(max-width: 767px)";

export type Breakpoints = {
  isDesktop: boolean;
  isTablet: boolean;
  isMobile: boolean;
};

// SSR / initial default matches the original svelte stores (desktop true, rest false).
let state: Breakpoints = { isDesktop: true, isTablet: false, isMobile: false };

let desktopQuery: MediaQueryList | undefined;
let tabletQuery: MediaQueryList | undefined;
let mobileQuery: MediaQueryList | undefined;

const listeners = new Set<() => void>();

function notify() {
  for (const listener of listeners) listener();
}

// Recompute the breakpoint state from the current media queries.
export function updateMediaQueries() {
  let changed = false;
  const next: Breakpoints = { ...state };

  if (desktopQuery) {
    next.isDesktop = desktopQuery.matches;
  }
  if (tabletQuery) {
    next.isTablet = tabletQuery.matches;
  }
  if (mobileQuery) {
    next.isMobile = mobileQuery.matches;
  }

  changed =
    next.isDesktop !== state.isDesktop ||
    next.isTablet !== state.isTablet ||
    next.isMobile !== state.isMobile;

  if (changed) {
    state = next;
    notify();
  }
}

export function mediaQueryHandler() {
  updateMediaQueries();
}

// Initialize media queries only on the client side (matches the original guard).
export function initializeMediaQueries() {
  if (typeof window !== "undefined" && !desktopQuery) {
    desktopQuery = window.matchMedia(DESKTOP_MEDIA_QUERY);
    tabletQuery = window.matchMedia(TABLET_MEDIA_QUERY);
    mobileQuery = window.matchMedia(MOBILE_MEDIA_QUERY);

    // Set initial values
    updateMediaQueries();

    // Listen for changes
    desktopQuery.addEventListener("change", updateMediaQueries);
    tabletQuery.addEventListener("change", updateMediaQueries);
    mobileQuery.addEventListener("change", updateMediaQueries);
  }
}

/** Current breakpoint snapshot (synchronous read for non-React callers). */
export function getBreakpoints(): Breakpoints {
  return state;
}

// Stable reference for the server snapshot. `useSyncExternalStore` compares
// snapshots by identity, so this MUST be a cached constant — returning a fresh
// object each call triggers React's "getServerSnapshot should be cached to
// avoid an infinite loop" error.
const SERVER_BREAKPOINTS: Breakpoints = {
  isDesktop: true,
  isTablet: false,
  isMobile: false,
};

/** SSR-safe default snapshot (desktop=true), matching the original svelte defaults. */
export function getServerBreakpoints(): Breakpoints {
  return SERVER_BREAKPOINTS;
}

/**
 * Subscribe to breakpoint changes. Lazily initializes the media queries on the first
 * client subscription. Returns an unsubscribe function. Used by `useSyncExternalStore`.
 */
export function subscribeBreakpoints(listener: () => void): () => void {
  initializeMediaQueries();
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}
