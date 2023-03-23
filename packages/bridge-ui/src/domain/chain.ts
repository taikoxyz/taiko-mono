import type { ComponentType } from 'svelte';

export type ChainID = number;

export type Address = string;

export type Chain = {
  id: ChainID;
  name: string;
  rpc: string;
  enabled?: boolean;
  icon?: ComponentType;
  bridgeAddress: Address;
  headerSyncAddress: Address;
  explorerUrl: string;
  signalServiceAddress: Address;
};
