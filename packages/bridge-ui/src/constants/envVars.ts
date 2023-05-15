// TODO: explain each of these env vars

import type { Address, ChainID } from '../domain/chain';

//=========== L1 =========== //

export const L1_RPC: string = import.meta.env.VITE_L1_RPC_URL;

export const L1_TOKEN_VAULT_ADDRESS: Address = import.meta.env
  .VITE_L1_TOKEN_VAULT_ADDRESS;

export const L1_BRIDGE_ADDRESS: Address = import.meta.env
  .VITE_L1_BRIDGE_ADDRESS;

export const L1_CROSS_CHAIN_SYNC_ADDRESS: Address = import.meta.env
  .VITE_L1_CROSS_CHAIN_SYNC_ADDRESS;

export const L1_SIGNAL_SERVICE_ADDRESS: Address = import.meta.env
  .VITE_L1_SIGNAL_SERVICE_ADDRESS;

export const L1_CHAIN_ID: ChainID = parseInt(import.meta.env.VITE_L1_CHAIN_ID);

export const L1_CHAIN_NAME: string = import.meta.env.VITE_L1_CHAIN_NAME;

export const L1_EXPLORER_URL: string = import.meta.env.VITE_L1_EXPLORER_URL;

//=========== L2 =========== //

export const L2_RPC: string = import.meta.env.VITE_L2_RPC_URL;

export const L2_TOKEN_VAULT_ADDRESS: Address = import.meta.env
  .VITE_L2_TOKEN_VAULT_ADDRESS;

export const L2_BRIDGE_ADDRESS: Address = import.meta.env
  .VITE_L2_BRIDGE_ADDRESS;

export const L2_CROSS_CHAIN_SYNC_ADDRESS: Address = import.meta.env
  .VITE_L2_CROSS_CHAIN_SYNC_ADDRESS;

export const L2_SIGNAL_SERVICE_ADDRESS: Address = import.meta.env
  .VITE_L2_SIGNAL_SERVICE_ADDRESS;

export const L2_CHAIN_ID: ChainID = parseInt(import.meta.env.VITE_L2_CHAIN_ID);

export const L2_CHAIN_NAME: string = import.meta.env.VITE_L2_CHAIN_NAME;

export const L2_EXPLORER_URL: string = import.meta.env.VITE_L2_EXPLORER_URL;

//=========== L3 =========== //

export const L3_RPC: string = import.meta.env.VITE_L3_RPC_URL;

export const L3_TOKEN_VAULT_ADDRESS: Address = import.meta.env
  .VITE_L3_TOKEN_VAULT_ADDRESS;

export const L3_BRIDGE_ADDRESS: Address = import.meta.env
  .VITE_L3_BRIDGE_ADDRESS;

export const L3_CROSS_CHAIN_SYNC_ADDRESS: Address = import.meta.env
  .VITE_L3_CROSS_CHAIN_SYNC_ADDRESS;

export const L3_SIGNAL_SERVICE_ADDRESS: Address = import.meta.env
  .VITE_L3_SIGNAL_SERVICE_ADDRESS;

export const L3_CHAIN_ID: ChainID = parseInt(import.meta.env.VITE_L3_CHAIN_ID);

export const L3_CHAIN_NAME: string = import.meta.env.VITE_L3_CHAIN_NAME;

export const L3_EXPLORER_URL: string = import.meta.env.VITE_L3_EXPLORER_URL;

//=========== Other vars =========== //

export const RELAYER_URL: string = import.meta.env.VITE_RELAYER_URL;

export const TEST_ERC20: {
  address: Address;
  symbol: string;
  name: string;
}[] = JSON.parse(import.meta.env.VITE_TEST_ERC20);
