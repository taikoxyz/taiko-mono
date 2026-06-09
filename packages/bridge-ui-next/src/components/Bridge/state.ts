"use client";

import type { GetBalanceReturnType } from "@wagmi/core";
import type { Address, Chain } from "viem";

import { useStore } from "zustand";
import { createStore } from "zustand/vanilla";

import { bridges } from "$libs/bridge";
import type { Bridge } from "$libs/bridge/Bridge";
import { chains } from "$libs/chain";
import { ProcessingFeeMethod } from "$libs/fee";
import type { NFT, Token } from "$libs/token";

import { type BridgeType, BridgeTypes } from "./types";

/**
 * Bridge component form state — ported from the original Svelte
 * `$components/Bridge/state.ts`.
 *
 * Each original `writable<T>` becomes a VANILLA zustand store holding the raw
 * value (matching the `$stores/account` / `$stores/network` convention), so the
 * svelte idioms map 1:1 for the non-React library callers that read/write it:
 *   get(store)                -> store.getState()
 *   store.set(v) / $store = v -> store.setState(v)
 *
 * The original `derived` `bridgeService` is reproduced as a derived vanilla store
 * that recomputes whenever `selectedToken` changes.
 *
 * React components subscribe via `useBridgeState(store, selector?)` (mirrors
 * svelte's `$store`). This is the single source of truth for Bridge form state
 * shared across the bridge / token / fee logic units and the Bridge UI.
 */

export const activeBridge = createStore<BridgeType>(() => BridgeTypes.FUNGIBLE);
export const selectedToken = createStore<Maybe<Token | NFT>>(() => null);
export const selectedNFTs = createStore<Maybe<NFT[]>>(() => null);
export const tokenBalance = createStore<Maybe<GetBalanceReturnType>>(
  () => null,
);
export const enteredAmount = createStore<bigint>(() => BigInt(0));
export const destNetwork = createStore<Maybe<Chain>>(() => null);
export const destOptions = createStore<Chain[]>(() => chains);
export const processingFee = createStore<bigint>(() => BigInt(0));
export const gasLimitZero = createStore<boolean>(() => false);
export const processingFeeMethod = createStore<ProcessingFeeMethod>(
  () => ProcessingFeeMethod.RECOMMENDED,
);
export const recipientAddress = createStore<Maybe<Address>>(() => null);
export const destOwnerAddress = createStore<Maybe<Address>>(() => null);

// Loading state
export const bridging = createStore<boolean>(() => false);
export const approving = createStore<boolean>(() => false);
export const computingBalance = createStore<boolean>(() => false);
export const validatingAmount = createStore<boolean>(() => false);
export const calculatingProcessingFee = createStore<boolean>(() => false);

// Errors state
export const errorComputingBalance = createStore<boolean>(() => false);

// There are two possible errors that can happen when the user
// enters an amount:
// 1. Insufficient balance
// 2. Insufficient allowance
// The first one is an error and the user cannot proceed. The second one
// is a warning but the user must approve allowance before bridging
export const insufficientBalance = createStore<boolean>(() => false);
export const insufficientAllowance = createStore<boolean>(() => false);

export const allApproved = createStore<boolean>(() => false);
export const needsApprovalReset = createStore<boolean>(() => false);

// Derived state — mirrors the original
//   derived(selectedToken, (token) => token ? bridges[token.type] : null)
// Recomputes whenever `selectedToken` changes.
export const bridgeService = createStore<Bridge | null>(() => {
  const token = selectedToken.getState();
  return token ? bridges[token.type] : null;
});

selectedToken.subscribe(() => {
  const token = selectedToken.getState();
  bridgeService.setState(() => (token ? bridges[token.type] : null), true);
});

export const importDone = createStore<boolean>(() => false);

/**
 * React hook over any of the vanilla bridge-state stores. Mirrors svelte's
 * `$store`. Pass an optional selector to subscribe to a slice.
 *
 * @example const amount = useBridgeState(enteredAmount);
 * @example const symbol = useBridgeState(selectedToken, (t) => t?.symbol);
 */
export function useBridgeState<S, T = S>(
  store: { getState: () => S; subscribe: (listener: () => void) => () => void },
  selector: (state: S) => T = (s) => s as unknown as T,
): T {
  return useStore(
    store as Parameters<typeof useStore>[0],
    selector as never,
  ) as T;
}

/**
 * React hook bound to the vanilla destination-network store. Kept for the
 * network logic unit that already imports it. Equivalent to
 * `useBridgeState(destNetwork, selector)`.
 */
export function useDestNetwork<T = Maybe<Chain>>(
  selector: (state: Maybe<Chain>) => T = (s) => s as unknown as T,
): T {
  return useStore(
    destNetwork as Parameters<typeof useStore>[0],
    selector as never,
  ) as T;
}
