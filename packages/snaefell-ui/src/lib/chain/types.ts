import type { Chain } from 'viem';

export type ChainID = bigint;

export enum LayerType {
  L1 = 'L1',
  L2 = 'L2',
  L3 = 'L3',
}

export type ChainConfig = Omit<Chain, 'id'> & {
  icon: string;
  type: LayerType;
};

export type ChainConfigMap = Record<number, ChainConfig>;

export type ConfiguredChains = {
  configuredChains: Array<Record<string, ChainConfig>>;
};
