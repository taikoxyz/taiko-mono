import type { Chain } from '@wagmi/core';

import { chainConfig } from '$chainConfig';
import type { ChainConfigMap } from '$libs/chain';

function mapChainConfigToChain(chainId: string, chainConfig: ChainConfigMap[number]): Chain {
  return {
    id: Number(chainId),
    name: chainConfig.name,
    network: chainConfig.name,
    nativeCurrency: {
      name: 'ETH',
      symbol: 'ETH',
      decimals: 18,
    },
    rpcUrls: {
      public: { http: [chainConfig.urls.rpc] },
      default: { http: [chainConfig.urls.rpc] },
    },
  };
}

export const chainIdToChain = (chainId: number): Chain => {
  const chain = chains.find((chain) => chain.id === chainId);
  if (!chain) {
    throw new Error(`Chain with id ${chainId} not found`);
  }
  return chain;
};

export const chains: Chain[] = Object.entries(chainConfig).map(([chainId, chainConfig]) =>
  mapChainConfigToChain(chainId, chainConfig),
);

export const getConfiguredChainIds = (): number[] => {
  return chains.map((chain) => Number(chain.id));
};

export const isSupportedChain = (chainId: number) => {
  return chains.some((chain) => chain.id === chainId);
};

export const getChainImages = (): Record<number, string> => {
  return Object.fromEntries(Object.entries(chainConfig).map(([chainId, config]) => [Number(chainId), config.icon]));
};
