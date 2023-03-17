import type { ComponentType } from 'svelte';

export type Chain = {
  id: number;
  name: string;
  rpc: string;
  enabled?: boolean;
  icon?: ComponentType;
  bridgeAddress: string;
  headerSyncAddress: string;
  explorerUrl: string;
  signalServiceAddress: string;
};
