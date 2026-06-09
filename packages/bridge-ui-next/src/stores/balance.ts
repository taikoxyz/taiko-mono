// Ported from stores/balance.ts.
//
// The original `ethBalance` writable<bigint> is written ONLY by
// `refreshUserBalance()` in libs/util/balance.ts (`ethBalance.set(balance)`) and
// read reactively in components (ConnectButton, ReviewStep, TokenInput,
// TokenAmountInput) for balance-vs-fee validation.
//
// The state-migration plan models eth balance as server/async state via TanStack
// React Query. To keep the existing imperative writer working unchanged, we keep a
// Zustand VANILLA store as the canonical reactive value (`ethBalance.setState(v)`
// replaces svelte's `ethBalance.set(v)`), and additionally expose a React Query
// hook (`useEthBalance`) + query key so callers preferring the Query cache can use
// `queryClient.invalidateQueries({ queryKey: ethBalanceQueryKey })`. Both stay in
// sync because `refreshUserBalance` writes the vanilla store; the query simply
// reads it (or re-fetches) on demand.
import { getAccount, getBalance } from "@wagmi/core";
import { useQuery } from "@tanstack/react-query";
import { useStore } from "zustand";
import { createStore } from "zustand/vanilla";

import { config } from "$libs/wagmi";

/**
 * Currently held ETH balance. `.getState()` returns `bigint | undefined`
 * (undefined before the first refresh, matching svelte's uninitialised writable).
 */
export const ethBalance = createStore<bigint | undefined>(() => undefined);

/** React hook bound to the vanilla eth-balance store. */
export function useEthBalanceStore<T = bigint | undefined>(
  selector: (state: bigint | undefined) => T = (s) => s as unknown as T,
): T {
  return useStore(ethBalance, selector);
}

/** Stable query key for the eth-balance React Query, parameterised by address. */
export const ethBalanceQueryKey = (address?: string) =>
  ["ethBalance", address] as const;

/**
 * TanStack React Query hook for the connected account's ETH balance. The queryFn
 * performs the same read as `refreshUserBalance` (getAccount -> getBalance) and
 * also commits the result to the vanilla `ethBalance` store so the imperative
 * readers stay current. Returns 0n when no address is connected, matching the
 * original `refreshUserBalance` fallback.
 */
export function useEthBalance() {
  const { address } = getAccount(config);
  return useQuery({
    queryKey: ethBalanceQueryKey(address),
    queryFn: async () => {
      let balance = BigInt(0);
      if (address) {
        balance = (await getBalance(config, { address })).value;
      }
      ethBalance.setState(balance);
      return balance;
    },
    enabled: Boolean(address),
  });
}
