import { get, writable } from 'svelte/store';
import type { Address } from 'viem';

import { getLogger } from '$libs/util/logger';

const log = getLogger('token:bridgedToken');

type TokenInfo = {
  isBridged: boolean;
  chainId: number;
};

type BridgedTokens = Record<Address, TokenInfo>;
export const bridgedTokens = writable<BridgedTokens>({});

export const setBridgedTokenInfoStore = (tokenAddress: Address, isBridged: boolean, chainId: number) => {
  bridgedTokens.update((currentTokens) => {
    return { ...currentTokens, [tokenAddress]: { isBridged, chainId } };
  });
};

export const getBridgedStatusFromStore = (tokenAddress: Address): boolean => {
  log('getting bridged token status from store', tokenAddress);
  const tokens = get(bridgedTokens);
  return tokens[tokenAddress]?.isBridged ?? false;
};

export const getBridgedTokenInfoStore = (tokenAddress: Address): TokenInfo => {
  log('getting bridged token info from store', tokenAddress);
  const tokens = get(bridgedTokens);
  return tokens[tokenAddress];
};
