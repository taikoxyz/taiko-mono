import type { ComponentType } from 'svelte';

export type ChainID = number;

export type Chain = {
  id: ChainID;
  name: string;
  rpc: string;
  enabled?: boolean;
  icon?: ComponentType;
  explorerUrl: string;
};
