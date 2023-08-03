import type { Address } from 'wagmi';

export type ChainID = number;

export type Chain = {
  id: ChainID;
  name: string;
  rpc: string;
  enabled?: boolean;
  iconUrl?: string;
  bridgeAddress: Address;
  crossChainSyncAddress: Address;
  explorerUrl: string;
  signalServiceAddress: Address;
};
