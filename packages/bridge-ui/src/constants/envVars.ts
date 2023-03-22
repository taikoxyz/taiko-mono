// TODO: think about a way to blow up the build if env var is missing
//       dotenv-safe ?
// TODO: does it make sense to provide with defaults?
// TODO: explain each of these env vars

import type { Token } from '../domain/token';
import type { Address, ChainID } from '../domain/chain';

export const L1_RPC: string = import.meta.env?.VITE_L1_RPC_URL;

export const L1_TOKEN_VAULT_ADDRESS: Address = import.meta.env
  ?.VITE_MAINNET_TOKEN_VAULT_ADDRESS;

export const L1_BRIDGE_ADDRESS: Address = import.meta.env
  ?.VITE_MAINNET_BRIDGE_ADDRESS;

export const L1_HEADER_SYNC_ADDRESS: Address = import.meta.env
  ?.VITE_MAINNET_HEADER_SYNC_ADDRESS;

export const L1_SIGNAL_SERVICE_ADDRESS: Address = import.meta.env
  ?.VITE_MAINNET_SIGNAL_SERVICE_ADDRESS;

export const L1_CHAIN_ID: ChainID = parseInt(
  import.meta.env?.VITE_MAINNET_CHAIN_ID,
);

export const L1_CHAIN_NAME: string = import.meta.env?.VITE_MAINNET_CHAIN_NAME;

export const L1_EXPLORER_URL: string = import.meta.env?.VITE_L1_EXPLORER_URL;

export const L2_RPC: string = import.meta.env?.VITE_L2_RPC_URL;

export const L2_TOKEN_VAULT_ADDRESS: Address = import.meta.env
  ?.VITE_TAIKO_TOKEN_VAULT_ADDRESS;

export const L2_BRIDGE_ADDRESS: Address = import.meta.env
  ?.VITE_TAIKO_BRIDGE_ADDRESS;

export const L2_HEADER_SYNC_ADDRESS: Address = import.meta.env
  ?.VITE_TAIKO_HEADER_SYNC_ADDRESS;

export const L2_SIGNAL_SERVICE_ADDRESS: Address = import.meta.env
  ?.VITE_TAIKO_SIGNAL_SERVICE_ADDRESS;

export const L2_CHAIN_ID: ChainID = parseInt(
  import.meta.env?.VITE_TAIKO_CHAIN_ID,
);

export const L2_CHAIN_NAME: string = import.meta.env?.VITE_TAIKO_CHAIN_NAME;

export const L2_EXPLORER_URL: string = import.meta.env?.VITE_L2_EXPLORER_URL;

export const RELAYER_URL: string = import.meta.env?.VITE_RELAYER_URL;

export const TEST_ERC20: Partial<Token>[] = JSON.parse(
  import.meta.env?.VITE_TEST_ERC20,
);
