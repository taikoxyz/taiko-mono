// Ported from stores/network.ts (the `connectedSourceChain` writable + `switchingNetwork`).
//
// The migration plan derives `connectedSourceChain` from wagmi in React via a hook
// (useConnectedSourceChain) and the `switchingNetwork` UI flag from a small UI store.
// Non-React library callers (token lib: fetchNFTMetadata.ts, fetchNFTImageUrl.ts)
// only need imperative read access to the currently connected source chain, so we
// expose VANILLA zustand stores here whose `.getState()` returns the value directly,
// mirroring svelte's `get(connectedSourceChain)`.
//
// NOTE: the wagmi React watcher (a later unit) is responsible for calling
// `connectedSourceChain.setState(chain)` when the wallet's chain changes.
import { useStore } from "zustand";
import { createStore } from "zustand/vanilla";
import type { Chain } from "viem";

/** Currently connected source chain. `.getState()` returns `Chain | undefined`. */
export const connectedSourceChain = createStore<Chain | undefined>(
  () => undefined,
);

/** Pure UI flag toggled around switchChain calls. */
export const switchingNetwork = createStore<boolean>(() => false);

/**
 * React hook over the connected source chain (reactive in components).
 * Mirrors svelte's `$connectedSourceChain`.
 */
export function useConnectedSourceChain<T = Chain | undefined>(
  selector: (state: Chain | undefined) => T = (s) => s as unknown as T,
): T {
  return useStore(connectedSourceChain, selector);
}

/**
 * React hook over the `switchingNetwork` UI flag (reactive in components).
 * Mirrors svelte's `$switchingNetwork`.
 */
export function useSwitchingNetwork<T = boolean>(
  selector: (state: boolean) => T = (s) => s as unknown as T,
): T {
  return useStore(switchingNetwork, selector);
}
