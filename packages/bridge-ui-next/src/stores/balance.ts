// Ported from stores/balance.ts.
//
// The original `ethBalance` writable<bigint> is written ONLY by
// `refreshUserBalance()` in libs/util/balance.ts (`ethBalance.set(balance)`) and
// read reactively in components (ConnectButton, ReviewStep, TokenInput,
// TokenAmountInput) for balance-vs-fee validation. The Zustand VANILLA store is
// the canonical reactive value (`ethBalance.setState(v)` replaces svelte's
// `ethBalance.set(v)`).
import { useStore } from "zustand";

import { createValueStore } from "@/stores/createValueStore";

/**
 * Currently held ETH balance. `.getState()` returns `bigint | undefined`
 * (undefined before the first refresh, matching svelte's uninitialised writable).
 */
export const ethBalance = createValueStore<bigint | undefined>(() => undefined);

/** React hook bound to the vanilla eth-balance store. */
export function useEthBalanceStore<T = bigint | undefined>(
  selector: (state: bigint | undefined) => T = (s) => s as unknown as T,
): T {
  return useStore(ethBalance, selector);
}
