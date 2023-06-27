import {
  PUBLIC_L1_BRIDGE_ADDRESS,
  PUBLIC_L1_CHAIN_ID,
  PUBLIC_L1_CHAIN_NAME,
  PUBLIC_L1_CROSS_CHAIN_SYNC_ADDRESS,
  PUBLIC_L1_EXPLORER_URL,
  PUBLIC_L1_RPC_URL,
  PUBLIC_L1_SIGNAL_SERVICE_ADDRESS,
  PUBLIC_L2_BRIDGE_ADDRESS,
  PUBLIC_L2_CHAIN_ID,
  PUBLIC_L2_CHAIN_NAME,
  PUBLIC_L2_CROSS_CHAIN_SYNC_ADDRESS,
  PUBLIC_L2_EXPLORER_URL,
  PUBLIC_L2_RPC_URL,
  PUBLIC_L2_SIGNAL_SERVICE_ADDRESS,
} from '$env/static/public';

import type { ChainWithExtras } from './types';

export const mainnetChain: ChainWithExtras = {
  id: parseInt(PUBLIC_L1_CHAIN_ID),
  name: PUBLIC_L1_CHAIN_NAME,
  network: 'L1',
  nativeCurrency: {
    name: 'Ether',
    symbol: 'ETH',
    decimals: 18,
  },
  rpcUrls: {
    public: { http: [PUBLIC_L1_RPC_URL] },
    default: { http: [PUBLIC_L1_RPC_URL] },
  },
  blockExplorers: {
    default: {
      name: 'Main',
      url: PUBLIC_L1_EXPLORER_URL,
    },
  },
  contracts: {
    bridgeAddress: PUBLIC_L1_BRIDGE_ADDRESS,
    crossChainSyncAddress: PUBLIC_L1_CROSS_CHAIN_SYNC_ADDRESS,
    signalServiceAddress: PUBLIC_L1_SIGNAL_SERVICE_ADDRESS,
  },
};

export const taikoChain: ChainWithExtras = {
  id: parseInt(PUBLIC_L2_CHAIN_ID),
  name: PUBLIC_L2_CHAIN_NAME,
  network: 'L2',
  nativeCurrency: {
    name: 'Ether',
    symbol: 'ETH',
    decimals: 18,
  },
  rpcUrls: {
    public: { http: [PUBLIC_L2_RPC_URL] },
    default: { http: [PUBLIC_L2_RPC_URL] },
  },
  blockExplorers: {
    default: {
      name: 'Main',
      url: PUBLIC_L2_EXPLORER_URL,
    },
  },
  contracts: {
    bridgeAddress: PUBLIC_L2_BRIDGE_ADDRESS,
    crossChainSyncAddress: PUBLIC_L2_CROSS_CHAIN_SYNC_ADDRESS,
    signalServiceAddress: PUBLIC_L2_SIGNAL_SERVICE_ADDRESS,
  },
};
