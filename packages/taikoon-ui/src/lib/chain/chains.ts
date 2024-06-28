import type { Chain } from 'viem';
import { taiko, taikoHekla } from 'viem/chains';

import { isDevelopmentEnv } from '$lib/util/isDevelopmentEnv';

export const getChainImages = (): Record<number, string> => {
  const map = {
    167000: '/chains/taiko.svg',
    167009: '/chains/taiko.svg',
  };
  return map;
};

export const getChainImage = (chainId: number) => {
  const chain = getChainImages()[chainId];
  if (!chain) {
    throw new Error(`Chain with id ${chainId} not found`);
  }
  return chain;
};

export const isSupportedChain = (chainId: number) => {
  return chains.some((chain) => chain.id === chainId);
};

export const chains: [Chain, ...Chain[]] = isDevelopmentEnv ? [taikoHekla] : [taiko];

export const chainId = isDevelopmentEnv ? taikoHekla.id : taiko.id;
