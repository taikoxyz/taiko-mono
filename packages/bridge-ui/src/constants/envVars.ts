import { getEnv } from '../utils/envVar';

// TODO: explain each of these env vars

export const L1_RPC = getEnv('VITE_L1_RPC_URL');
export const L1_TOKEN_VAULT_ADDRESS = getEnv(
  'VITE_MAINNET_TOKEN_VAULT_ADDRESS',
);
export const L1_BRIDGE_ADDRESS = getEnv('VITE_MAINNET_BRIDGE_ADDRESS');
export const L1_HEADER_SYNC_ADDRESS = getEnv(
  'VITE_MAINNET_HEADER_SYNC_ADDRESS',
);
export const L1_SIGNAL_SERVICE_ADDRESS = getEnv(
  'VITE_MAINNET_SIGNAL_SERVICE_ADDRESS',
);
export const L1_CHAIN_ID = parseInt(getEnv('VITE_MAINNET_CHAIN_ID'), 0);
export const L1_CHAIN_NAME = getEnv('VITE_MAINNET_CHAIN_NAME');
export const L1_EXPLORER_URL = getEnv('VITE_L1_EXPLORER_URL');

export const L2_RPC = getEnv('VITE_L2_RPC_URL');
export const L2_TOKEN_VAULT_ADDRESS = getEnv('VITE_TAIKO_TOKEN_VAULT_ADDRESS');
export const L2_BRIDGE_ADDRESS = getEnv('VITE_TAIKO_BRIDGE_ADDRESS');
export const L2_HEADER_SYNC_ADDRESS = getEnv('VITE_TAIKO_HEADER_SYNC_ADDRESS');
export const L2_SIGNAL_SERVICE_ADDRESS = getEnv(
  'VITE_TAIKO_SIGNAL_SERVICE_ADDRESS',
);
export const L2_CHAIN_ID = parseInt(getEnv('VITE_TAIKO_CHAIN_ID'));
export const L2_CHAIN_NAME = getEnv('VITE_TAIKO_CHAIN_NAME');
export const L2_EXPLORER_URL = getEnv('VITE_L2_EXPLORER_URL');

export const RELAYER_URL = getEnv('VITE_RELAYER_URL');

export const TEST_ERC20 = getEnv('VITE_TEST_ERC20');
