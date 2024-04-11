import type { Chain } from 'viem';

import { chainConfig } from '$chainConfig';
import type { ChainConfig } from '$libs/chain';

import { LayerType } from './types';

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

export const isL2Chain = (chainId: number) => {
  return chainConfig[chainId].type === LayerType.L2;
};

export const chains: [Chain, ...Chain[]] = Object.entries(chainConfig).map(([chainId, chainConfig]) =>
  mapChainConfigToChain(chainId, chainConfig),
) as [Chain, ...Chain[]];

export const getConfiguredChainIds = (): number[] => {
  return chains.map((chain) => Number(chain.id));
};

export const isSupportedChain = (chainId: number) => {
  return chains.some((chain) => chain.id === chainId);
};

export const getChainImages = (): Record<number, string> => {
  return Object.fromEntries(Object.entries(chainConfig).map(([chainId, config]) => [Number(chainId), config.icon]));
};

export const getChainImage = (chainId: number) => {
  const chain = chains.find((chain) => chain.id === chainId);
  if (!chain) {
    throw new Error(`Chain with id ${chainId} not found`);
  }
  return chainConfig[chainId].icon;
};

export const getChainName = (chainId: number) => {
  const chain = chains.find((chain) => chain.id === chainId);
  if (!chain) {
    throw new Error(`Chain with id ${chainId} not found`);
  }
  return chain.name;
};
