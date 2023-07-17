import type { Chain as WagmiChain } from 'wagmi';

import Eldfell from '../components/icons/Eldfell.svelte';
import Eth from '../components/icons/ETH.svelte';
import Sepolia from '../components/icons/Sepolia.svelte';
import Taiko from '../components/icons/Taiko.svelte';
import TKO from '../components/icons/TKO.svelte';
import {
  L1_BRIDGE_ADDRESS,
  L1_CHAIN_ICON,
  L1_CHAIN_ID,
  L1_CHAIN_NAME,
  L1_CROSS_CHAIN_SYNC_ADDRESS,
  L1_EXPLORER_URL,
  L1_RPC,
  L1_SIGNAL_SERVICE_ADDRESS,
  L2_BRIDGE_ADDRESS,
  L2_CHAIN_ICON,
  L2_CHAIN_ID,
  L2_CHAIN_NAME,
  L2_CROSS_CHAIN_SYNC_ADDRESS,
  L2_EXPLORER_URL,
  L2_RPC,
  L2_SIGNAL_SERVICE_ADDRESS,
} from '../constants/envVars';
import type { Chain, ChainID } from '../domain/chain';

// TODO: in the future the whole URL will come from env var,
//       so we won't need any mapping
const chainIcons = {
  'sepolia': Eth,
  'taiko': TKO,
  'eldfell': Eldfell,
  'l1': Sepolia,
  'l2': Taiko,
  'l3': Eldfell,
};

export const L1Chain: Chain = {
  id: L1_CHAIN_ID,
  name: L1_CHAIN_NAME,
  rpc: L1_RPC,
  enabled: true,
  icon: chainIcons[L1_CHAIN_ICON.toLowerCase()] || Sepolia,
  bridgeAddress: L1_BRIDGE_ADDRESS,
  crossChainSyncAddress: L1_CROSS_CHAIN_SYNC_ADDRESS,
  explorerUrl: L1_EXPLORER_URL,
  signalServiceAddress: L1_SIGNAL_SERVICE_ADDRESS,
};

export const L2Chain: Chain = {
  id: L2_CHAIN_ID,
  name: L2_CHAIN_NAME,
  rpc: L2_RPC,
  enabled: true,
  icon: chainIcons[L2_CHAIN_ICON.toLowerCase()] || Taiko,
  bridgeAddress: L2_BRIDGE_ADDRESS,
  crossChainSyncAddress: L2_CROSS_CHAIN_SYNC_ADDRESS,
  explorerUrl: L2_EXPLORER_URL,
  signalServiceAddress: L2_SIGNAL_SERVICE_ADDRESS,
};

export const chains: Record<ChainID, Chain> = {
  [L1_CHAIN_ID]: L1Chain,
  [L2_CHAIN_ID]: L2Chain,
};

// TODO: can we not merge this chain into L1Chain?
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

// TODO: same here, merge it into L2Chain
export const taikoWagmiChain: WagmiChain = {
  id: L2_CHAIN_ID,
  name: L2_CHAIN_NAME,
  network: '',
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  rpcUrls: {
    default: { http: [L2_RPC] },
    public: { http: [L2_RPC] },
  },
  blockExplorers: {
    default: {
      name: 'Main',
      url: L2_EXPLORER_URL,
    },
  },
};
