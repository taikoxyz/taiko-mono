/// <reference types="svelte" />
/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_L1_RPC_URL: string;
  readonly VITE_L2_RPC_URL: string;
  readonly VITE_L1_EXPLORER_URL: string;
  readonly VITE_L2_EXPLORER_URL: string;
  readonly VITE_RELAYER_URL: string;
  readonly VITE_L1_CHAIN_ID: string;
  readonly VITE_L2_CHAIN_ID: string;
  readonly VITE_L1_CHAIN_NAME: string;
  readonly VITE_L2_CHAIN_NAME: string;
  readonly VITE_L1_CHAIN_ICON: string;
  readonly VITE_L2_CHAIN_ICON: string;
  readonly VITE_L1_TOKEN_VAULT_ADDRESS: string;
  readonly VITE_L2_TOKEN_VAULT_ADDRESS: string;
  readonly VITE_L1_CROSS_CHAIN_SYNC_ADDRESS: string;
  readonly VITE_L2_CROSS_CHAIN_SYNC_ADDRESS: string;
  readonly VITE_L1_BRIDGE_ADDRESS: string;
  readonly VITE_L2_BRIDGE_ADDRESS: string;
  readonly VITE_L1_SIGNAL_SERVICE_ADDRESS: string;
  readonly VITE_L2_SIGNAL_SERVICE_ADDRESS: string;
  readonly VITE_TEST_ERC20: string;
  readonly VITE_SENTRY_DSN: string;
  readonly VITE_WALLETCONNECT_PROJECT_ID: string;
  readonly VITE_ENABLE_FAUCET: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
