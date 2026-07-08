// tokenInfoStore.ts
//
// Ported from stores/tokenInfo.ts. The original was a svelte `writable` Record
// cache written/read imperatively by non-React lib code (getTokenAddresses.ts,
// getCanonicalInfoForToken.ts). Re-implemented as a Zustand VANILLA store so the
// same imperative `get(tokenInfoStore)` / `setTokenInfo()` API keeps working from
// outside React. The public surface (tokenInfoStore, setTokenInfo,
// isCanonicalAddress, isBridgedAddress, TokenInfo, SetTokenInfoParams) is identical.
import { createValueStore } from "@/stores/createValueStore";
import type { Address } from "viem";

import { getLogger } from "$libs/util/logger";

const log = getLogger("stores:tokenInfoStore");

export type TokenInfo = {
  canonical: {
    chainId: number;
    address: Address;
  } | null;
  bridged: {
    chainId: number;
    address: Address;
  } | null;
};
export type SetTokenInfoParams = {
  canonicalAddress: Address;
  bridgedAddress: Address | null;
  info: TokenInfo;
};
type TokenInfoStore = Record<Address, TokenInfo>;

/**
 * Vanilla zustand store. `tokenInfoStore.getState()` returns the Record, mirroring
 * the svelte `get(tokenInfoStore)` access used throughout the token lib.
 */
export const tokenInfoStore = createValueStore<TokenInfoStore>(() => ({}));

export const setTokenInfo = ({
  canonicalAddress,
  bridgedAddress,
  info,
}: SetTokenInfoParams) => {
  log("setting token info", canonicalAddress, bridgedAddress, info);
  // Preserve the original mutate-then-return-new-reference semantics: build a new
  // object so React subscribers re-render (the svelte version mutated in place).
  const store = { ...tokenInfoStore.getState() };
  store[canonicalAddress] = info;
  if (bridgedAddress) {
    store[bridgedAddress] = info;
  }
  tokenInfoStore.setState(store, true);
};

export const isCanonicalAddress = (address: Address): boolean => {
  const store = tokenInfoStore.getState();
  const tokenInfo = store[address];

  return tokenInfo?.canonical?.address === address;
};

export const isBridgedAddress = (address: Address): boolean => {
  const store = tokenInfoStore.getState();
  const tokenInfo = store[address];

  return tokenInfo?.bridged?.address === address;
};
