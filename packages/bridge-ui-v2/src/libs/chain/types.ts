import type { Chain } from 'wagmi';

export type ExtendedChain = Chain & {
  contracts: {
    bridgeAddress: string;
    crossChainSyncAddress: string;
    signalServiceAddress: string;
  };
};
