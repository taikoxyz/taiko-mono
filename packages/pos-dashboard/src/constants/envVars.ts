import type { ChainID } from '../domain/chain';

export const L1_CHAIN_ID: ChainID = parseInt(import.meta.env?.VITE_L1_CHAIN_ID);

export const L1_CHAIN_NAME: string = import.meta.env?.VITE_L1_CHAIN_NAME;

export const L1_RPC: string = import.meta.env?.VITE_L1_RPC_URL;

export const L1_EXPLORER_URL: string = import.meta.env?.VITE_L1_EXPLORER_URL;

export const WALLETCONNECT_PROJECT_ID: string = import.meta.env
  ?.VITE_WALLETCONNECT_PROJECT_ID;

export const EVENT_INDEXER_API_URL: string = import.meta.env
  ?.VITE_EVENT_INDEXER_URL;

export const PROVER_POOL_ADDRESS: string = import.meta.env
  ?.VITE_PROVER_POOL_ADDRESS;

export const TAIKO_L1_ADDRESS: string = import.meta.env?.VITE_TAIKO_L1_ADDRESS;

export const TTKO_ADDRESS: string = import.meta.env?.VITE_TTKO_ADDRESS;
