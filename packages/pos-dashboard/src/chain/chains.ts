import type { Chain as WagmiChain } from 'wagmi';

import Eth from '../components/icons/ETH.svelte';
import {
  L1_EXPLORER_URL,
  L1_RPC,
  L1_CHAIN_ID,
  L1_CHAIN_NAME,
} from '../constants/envVars';
import type { Chain, ChainID } from '../domain/chain';

export const mainnetChain: Chain = {
  id: L1_CHAIN_ID,
  name: L1_CHAIN_NAME,
  rpc: L1_RPC,
  enabled: true,
  icon: Eth,
  explorerUrl: L1_EXPLORER_URL,
};

export const chains: Record<ChainID, Chain> = {
  [L1_CHAIN_ID]: mainnetChain,
};

export const mainnetWagmiChain: WagmiChain = {
  id: L1_CHAIN_ID,
  name: L1_CHAIN_NAME,
  network: '',
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  rpcUrls: {
    default: { http: [L1_RPC] },
    public: { http: [L1_RPC] },
  },
  blockExplorers: {
    default: {
      name: 'Main',
      url: L1_EXPLORER_URL,
    },
  },
};
