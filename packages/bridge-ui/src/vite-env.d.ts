/// <reference types="svelte" />
/// <reference types="vite/client" />

/* eslint-disable no-var */
declare namespace globalThis {
  var Buffer: typeof import('buffer').Buffer;
  var ethereum: import('ethers').providers.ExternalProvider;

  // Add your custom global variables here.
  // Note: use `var` instead of `const` or `let`.
}
/* eslint-enable no-var */

interface ImportMetaEnv {
  readonly VITE_L1_RPC_URL: string;
  readonly VITE_L2_RPC_URL: string;
  readonly VITE_L1_EXPLORER_URL: string;
  readonly VITE_L2_EXPLORER_URL: string;
  readonly VITE_RELAYER_URL: string;
  readonly VITE_TEST_ERC20_ADDRESS_MAINNET: string;
  readonly VITE_TEST_ERC20_SYMBOL_MAINNET: string;
  readonly VITE_TEST_ERC20_NAME_MAINNET: string;
  readonly VITE_MAINNET_CHAIN_ID: string;
  readonly VITE_TAIKO_CHAIN_ID: string;
  readonly VITE_MAINNET_CHAIN_NAME: string;
  readonly VITE_TAIKO_CHAIN_NAME: string;
  readonly VITE_MAINNET_TOKEN_VAULT_ADDRESS: string;
  readonly VITE_TAIKO_TOKEN_VAULT_ADDRESS: string;
  readonly VITE_MAINNET_HEADER_SYNC_ADDRESS: string;
  readonly VITE_TAIKO_HEADER_SYNC_ADDRESS: string;
  readonly VITE_MAINNET_BRIDGE_ADDRESS: string;
  readonly VITE_TAIKO_BRIDGE_ADDRESS: string;
  readonly VITE_MAINNET_SIGNAL_SERVICE_ADDRESS: string;
  readonly VITE_TAIKO_SIGNAL_SERVICE_ADDRESS: string;
  readonly VITE_TEST_ERC20: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
