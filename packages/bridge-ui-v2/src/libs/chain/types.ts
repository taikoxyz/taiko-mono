import type { Chain } from '@wagmi/core';

export type ChainWithExtras = Chain & {
  contracts: {
    bridgeAddress: string;
    crossChainSyncAddress: string;
    signalServiceAddress: string;
  };
};
