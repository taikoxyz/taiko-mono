// React port of src/components/Dialogs/RetryDialog/state.ts.
//
// The original was a svelte `writable<RETRY_OPTION>(RETRY_OPTION.CONTINUE)`
// read/written reactively in components (RetryOptionStep, RetryDialog) AND read
// imperatively from non-React library code (Dialogs/Claim reads it via
// `get(selectedRetryMethod)`). Mirroring the state-migration convention, this is
// a small shared UI flag, so it becomes a zustand VANILLA store (exposing
// `.getState()` / `.setState()` / `.subscribe()` for library callers — identical
// to svelte's `get()` / `.set()`) plus a bound hook for reactive React usage
// (`$selectedRetryMethod` -> `useSelectedRetryMethod()`).
import { useStore } from "zustand";
import { createStore } from "zustand/vanilla";

import { RETRY_OPTION } from "./types";

/**
 * Currently selected retry method. Defaults to `RETRY_OPTION.CONTINUE`
 * (verbatim from the source writable). `.getState()` returns `RETRY_OPTION`.
 */
export const selectedRetryMethod = createStore<RETRY_OPTION>(
  () => RETRY_OPTION.CONTINUE,
);

/**
 * React hook over the selected retry method (reactive in components).
 * Mirrors svelte's `$selectedRetryMethod`.
 */
export function useSelectedRetryMethod<T = RETRY_OPTION>(
  selector: (state: RETRY_OPTION) => T = (s) => s as unknown as T,
): T {
  return useStore(selectedRetryMethod, selector);
}
