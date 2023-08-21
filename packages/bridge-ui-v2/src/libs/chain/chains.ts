
import type { Chain } from '@wagmi/core';

import { chainConfig, type ChainConfigMap } from '$chainConfig';



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
  mapChainConfigToChain(chainId, chainConfig)
);

export const isSupportedChain = (chainId: number) => {
  return chains.some((chain) => chain.id === chainId);
};


// Todo: export to env?
// export const chainIcons = {
//   [PUBLIC_L1_CHAIN_ID]: '/ethereum-chain.png',
//   [PUBLIC_L2_CHAIN_ID]: '/taiko-chain.png',
//   [PUBLIC_L3_CHAIN_ID]: '/eldfell.svg',
// };
