import type { Chain } from '@wagmi/core';

import { chainConfig, type ChainConfigMap } from '$chainConfig';

export type ChainID = bigint;

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

export const chains: Chain[] = Object.entries(chainConfig).map(([chainId, chainConfig]) =>
  mapChainConfigToChain(chainId, chainConfig),
);

export const isSupportedChain = (chainId: number) => {
  return chains.some((chain) => chain.id === chainId);
};
