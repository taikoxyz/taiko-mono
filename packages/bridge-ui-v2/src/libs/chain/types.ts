import type { Chain } from '@wagmi/core';

export type ExtendedChain = Chain & {
  contracts: {
    bridgeAddress: string;
    crossChainSyncAddress: string;
    signalServiceAddress: string;
  };
};
