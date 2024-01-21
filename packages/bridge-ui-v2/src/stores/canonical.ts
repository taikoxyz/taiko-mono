import type { Address } from '@wagmi/core';
import { get, writable } from 'svelte/store';

import { getLogger } from '$libs/util/logger';

const log = getLogger('token:canonical');

type TokenInfo = {
  isCanonical: boolean;
  chainId: number;
};

type CanonicalTokens = Record<Address, TokenInfo>;
export const canonicalTokens = writable<CanonicalTokens>({});

export const setCanonicalTokenInfoStore = (tokenAddress: Address, isCanonical: boolean, chainId: number) => {
  canonicalTokens.update((currentTokens) => {
    return { ...currentTokens, [tokenAddress]: { isCanonical, chainId } };
  });
};

export const getCanonicalStatusFromStore = (tokenAddress: Address): boolean => {
  log('getting canonical token status from store', tokenAddress);
  const tokens = get(canonicalTokens);
  return tokens[tokenAddress]?.isCanonical ?? false;
};

export const getCanonicalTokenInfoStore = (tokenAddress: Address): TokenInfo => {
  log('getting canonical token info from store', tokenAddress);
  const tokens = get(canonicalTokens);
  return tokens[tokenAddress];
};
