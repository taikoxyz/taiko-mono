// Ported from stores/bridgedToken.ts.
//
// The original `bridgedTokens` writable<Record<Address, {isBridged, chainId}>>
// is a memoization cache written via `setBridgedTokenInfoStore` and read via
// `getBridgedStatusFromStore` / `getBridgedTokenInfoStore`. It currently has ZERO
// importers outside this file (flagged as likely-dead in the migration plan) but
// is ported 1:1 for parity. Re-implemented as a Zustand VANILLA store so the
// imperative get/set helpers keep working outside React; the public surface
// (bridgedTokens, setBridgedTokenInfoStore, getBridgedStatusFromStore,
// getBridgedTokenInfoStore) is identical.
import { createStore } from "zustand/vanilla";
import type { Address } from "viem";

import { getLogger } from "$libs/util/logger";

const log = getLogger("token:bridgedToken");

type TokenInfo = {
  isBridged: boolean;
  chainId: number;
};

type BridgedTokens = Record<Address, TokenInfo>;

/** Vanilla zustand store. `bridgedTokens.getState()` mirrors svelte `get(bridgedTokens)`. */
export const bridgedTokens = createStore<BridgedTokens>(() => ({}));

export const setBridgedTokenInfoStore = (
  tokenAddress: Address,
  isBridged: boolean,
  chainId: number,
) => {
  bridgedTokens.setState((currentTokens) => {
    return { ...currentTokens, [tokenAddress]: { isBridged, chainId } };
  });
};

export const getBridgedStatusFromStore = (tokenAddress: Address): boolean => {
  log("getting bridged token status from store", tokenAddress);
  const tokens = bridgedTokens.getState();
  return tokens[tokenAddress]?.isBridged ?? false;
};

export const getBridgedTokenInfoStore = (tokenAddress: Address): TokenInfo => {
  log("getting bridged token info from store", tokenAddress);
  const tokens = bridgedTokens.getState();
  return tokens[tokenAddress];
};
