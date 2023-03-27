import type { Chain as WagmiChain } from '@wagmi/core';
import {
  L1_BRIDGE_ADDRESS,
  L1_CHAIN_ID,
  L1_CHAIN_NAME,
  L1_EXPLORER_URL,
  L1_HEADER_SYNC_ADDRESS,
  L1_RPC,
  L1_SIGNAL_SERVICE_ADDRESS,
  L2_BRIDGE_ADDRESS,
  L2_CHAIN_ID,
  L2_CHAIN_NAME,
  L2_EXPLORER_URL,
  L2_HEADER_SYNC_ADDRESS,
  L2_RPC,
  L2_SIGNAL_SERVICE_ADDRESS,
} from '../constants/envVars';
import type { Chain, ChainID } from '../domain/chain';
import Eth from '../components/icons/ETH.svelte';
import Taiko from '../components/icons/TKO.svelte';

export const mainnetChain: Chain = {
  id: L1_CHAIN_ID,
  name: L1_CHAIN_NAME,
  rpc: L1_RPC,
  enabled: true,
  icon: Eth,
  bridgeAddress: L1_BRIDGE_ADDRESS,
  headerSyncAddress: L1_HEADER_SYNC_ADDRESS,
  explorerUrl: L1_EXPLORER_URL,
  signalServiceAddress: L1_SIGNAL_SERVICE_ADDRESS,
};

export const taikoChain: Chain = {
  id: L2_CHAIN_ID,
  name: L2_CHAIN_NAME,
  rpc: L2_RPC,
  enabled: true,
  icon: Taiko,
  bridgeAddress: L2_BRIDGE_ADDRESS,
  headerSyncAddress: L2_HEADER_SYNC_ADDRESS,
  explorerUrl: L2_EXPLORER_URL,
  signalServiceAddress: L2_SIGNAL_SERVICE_ADDRESS,
};

export const chains: Record<ChainID, Chain> = {
  [L1_CHAIN_ID]: mainnetChain,
  [L2_CHAIN_ID]: taikoChain,
};

// TODO: can we not merge this chain into mainnetChain?
export const mainnetWagmiChain: WagmiChain = {
  id: L1_CHAIN_ID,
  name: L1_CHAIN_NAME,
  network: '',
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  rpcUrls: {
    default: {
      http: [L1_RPC],
    },
  },
  blockExplorers: {
    default: {
      name: 'Main',
      url: L1_EXPLORER_URL,
    },
  },
};

// TODO: same here, merge it into taikoChain
export const taikoWagmiChain: WagmiChain = {
  id: L2_CHAIN_ID,
  name: L2_CHAIN_NAME,
  network: '',
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  rpcUrls: {
    default: {
      http: [L2_RPC],
    },
  },
  blockExplorers: {
    default: {
      name: 'Main',
      url: L2_EXPLORER_URL,
    },
  },
};
