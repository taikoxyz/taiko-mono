import type { Chain } from 'viem';

import { type ChainConfig, type ChainConfigMap, LayerType } from '../../lib/chain';

//import { chainConfig } from '$chainConfig';

const chainConfigs: ChainConfigMap = {
  /*
  '1': {
    name: 'Ethereum',
    rpcUrls: {
      default: {
        http: ['https://mainnet.infura.io/v3/'],
        webSocket: ['wss://mainnet.infura.io/ws/v3/'],
      },
    },
    nativeCurrency: {
      name: 'Ether',
      symbol: 'ETH',
      decimals: 18,
    },
    icon: '/chains/ethereum.svg',
    type: 'L1' as LayerType, // Add the missing 'type' property with the value of 'LayerType'
  },*/
  '31337': {
    name: 'Hardhat',
    rpcUrls: {
      default: {
        http: ['http://localhost:8545'],
        //webSocket: ['wss://mainnet.infura.io/ws/v3/'],
      },
    },
    nativeCurrency: {
      name: 'Ether',
      symbol: 'ETH',
      decimals: 18,
    },
    icon: '/chains/ethereum.svg',
    type: 'L1' as LayerType, // Add the missing 'type' property with the value of 'LayerType'
  },
  '167001': {
    name: 'Devnet',
    rpcUrls: {
      default: {
        http: ['https://rpc.internal.taiko.xyz'],
      },
    },
    nativeCurrency: {
      name: 'Ether',
      symbol: 'ETH',
      decimals: 18,
    },
    icon: '/chains/ethereum.svg',
    type: 'L1' as LayerType, // Add the missing 'type' property with the value of 'LayerType'
  },
  '167000': {
    name: 'Taiko',
    rpcUrls: {
      default: {
        http: ['https://rpc.mainnet.taiko.xyz'],
      },
    },
    nativeCurrency: {
      name: 'Ether',
      symbol: 'ETH',
      decimals: 18,
    },
    icon: '/chains/taiko.svg',
    type: 'L1' as LayerType, // Add the missing 'type' property with the value of 'LayerType'
  },
};

function mapChainConfigToChain(chainId: string, chainConfig: ChainConfig): Chain {
  return {
    id: Number(chainId),
    name: chainConfig.name,
    rpcUrls: chainConfig.rpcUrls,
    nativeCurrency: chainConfig.nativeCurrency,
    blockExplorers: chainConfig.blockExplorers,
  };
}

export const chainIdToChain = (chainId: number): Chain => {
  const chain = chains.find((chain) => chain.id === chainId);
  if (!chain) {
    throw new Error(`Chain with id ${chainId} not found`);
  }
  return chain;
};

export const chains: Chain[] = Object.entries(chainConfigs).map(([chainId, chainConfig]) =>
  mapChainConfigToChain(chainId, chainConfig as ChainConfig),
);

export const getConfiguredChainIds = (): number[] => {
  return chains.map((chain) => Number(chain.id));
};

export const isSupportedChain = (chainId: number) => {
  return chains.some((chain) => chain.id === chainId);
};

export const getChainImages = (): Record<number, string> => {
  return Object.fromEntries(
    Object.entries(chainConfigs).map(([chainId]) => [Number(chainId), chainConfigs[Number(chainId)].icon]),
  );
};

export const getChainImage = (chainId: number) => {
  const images = getChainImages();
  if (!images[chainId]) {
    throw new Error(`Chain with id ${chainId} not found`);
  }

  return images[chainId];
};

export const getChainName = (chainId: number) => {
  const chain = chains.find((chain) => chain.id === chainId);
  if (!chain) {
    throw new Error(`Chain with id ${chainId} not found`);
  }
  return chain.name;
};
