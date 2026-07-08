import { createStore, type StoreApi } from "zustand/vanilla";

/**
 * A vanilla zustand store holding a single raw value — the port of a Svelte
 * `writable<T>`, where `store.set(v)` always replaced the value wholesale.
 *
 * zustand v5's `setState` MERGES non-null objects (including arrays) into the
 * previous state via `Object.assign` unless `replace` is passed, which
 * corrupts value stores: `setState([])` over `[nft]` yields `{0: nft}`, and
 * optional fields of a previously stored object leak into the next one. This
 * factory wraps `setState` so every write replaces, restoring the Svelte
 * `.set` contract for all callers without threading `replace: true` through
 * every call site.
 */
export function createValueStore<T>(init: () => T): StoreApi<T> {
  const store = createStore<T>(init);
  const replaceState = store.setState;
  store.setState = ((partial: T | ((state: T) => T)) =>
    replaceState(partial, true)) as typeof store.setState;
  return store;
}
