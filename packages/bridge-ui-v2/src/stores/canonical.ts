import type { Address } from '@wagmi/core';
import { get, writable } from 'svelte/store';

type TokenInfo = {
  isCanonical: boolean;
  chainId: number;
};

type CanonicalTokens = Record<Address, TokenInfo>;
export const canonicalTokens = writable<CanonicalTokens>({});

export const setCanonicalTokenInfo = (tokenAddress: Address, isCanonical: boolean, chainId: number) => {
  canonicalTokens.update((currentTokens) => {
    return { ...currentTokens, [tokenAddress]: { isCanonical, chainId } };
  });
};

export const getCanonicalStatus = (tokenAddress: Address): boolean => {
  const tokens = get(canonicalTokens);
  return tokens[tokenAddress]?.isCanonical ?? false;
};

export const getCanonicalTokenInfo = (tokenAddress: Address): TokenInfo => {
  const tokens = get(canonicalTokens);
  return tokens[tokenAddress];
};
