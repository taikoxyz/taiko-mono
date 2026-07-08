// Ported from stores/account.ts.
//
// The original `account` writable holds wagmi's GetAccountReturnType and is set
// imperatively from libs/wagmi/watcher.ts (`account.set(data)`) and read both
// reactively in components and imperatively via `get(account)` in
// libs/token/getTokenApprovalStatus.ts and libs/network/setAlternateNetwork.ts.
//
// Re-implemented as Zustand VANILLA stores so the non-React watcher can call
// `account.setState(data)` / `connectedSmartContractWallet.setState(flag)` and lib
// callers can read via `account.getState()` (mirroring svelte's `get(account)`).
// React components subscribe through the `useAccount` / `useSmartContractWallet`
// hooks below. The migration plan recommends wagmi's own `useAccount()` for
// components, but the watcher already drives this store, so we keep the store as
// the single source of truth the watcher writes to and expose a thin hook over it.
import type { GetAccountReturnType } from "@wagmi/core";
import { useStore } from "zustand";
import { createValueStore } from "@/stores/createValueStore";

export type Account = GetAccountReturnType;

/**
 * Currently connected wagmi account. `.getState()` returns the
 * `GetAccountReturnType` (or `undefined` before the watcher's first write),
 * mirroring svelte's `get(account)`.
 */
export const account = createValueStore<GetAccountReturnType | undefined>(
  () => undefined,
);

/** Whether the connected wallet is a smart-contract wallet (set inside the watcher). */
export const connectedSmartContractWallet = createValueStore<boolean>(() => false);

/** React hook bound to the vanilla account store. */
export function useAccount<T>(
  selector: (state: GetAccountReturnType | undefined) => T,
): T {
  return useStore(account, selector);
}

/** React hook bound to the smart-contract-wallet flag store. */
export function useSmartContractWallet<T = boolean>(
  selector: (state: boolean) => T = (s) => s as unknown as T,
): T {
  return useStore(connectedSmartContractWallet, selector);
}
