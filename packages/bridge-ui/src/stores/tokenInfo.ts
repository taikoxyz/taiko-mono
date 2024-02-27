// tokenInfoStore.ts
import { get, writable } from 'svelte/store';
import type { Address } from 'viem';

import { getLogger } from '$libs/util/logger';

const log = getLogger('stores:tokenInfoStore');

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

export const tokenInfoStore = writable<TokenInfoStore>({});

export const setTokenInfo = ({ canonicalAddress, bridgedAddress, info }: SetTokenInfoParams) => {
  log('setting token info', canonicalAddress, bridgedAddress, info);
  tokenInfoStore.update((store) => {
    store[canonicalAddress] = info;
    if (!bridgedAddress) return store;
    store[bridgedAddress] = info;
    return store;
  });
};

export const isCanonicalAddress = (address: Address): boolean => {
  const store = get(tokenInfoStore);
  const tokenInfo = store[address];

  return tokenInfo?.canonical?.address === address;
};

export const isBridgedAddress = (address: Address): boolean => {
  const store = get(tokenInfoStore);
  const tokenInfo = store[address];

  return tokenInfo?.bridged?.address === address;
};
