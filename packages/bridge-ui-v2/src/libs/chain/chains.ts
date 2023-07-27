import type { Address, Chain } from '@wagmi/core';

import {
  PUBLIC_L1_BRIDGE_ADDRESS,
  PUBLIC_L1_CHAIN_ID,
  PUBLIC_L1_CHAIN_NAME,
  PUBLIC_L1_CROSS_CHAIN_SYNC_ADDRESS,
  PUBLIC_L1_EXPLORER_URL,
  PUBLIC_L1_RPC_URL,
  PUBLIC_L1_SIGNAL_SERVICE_ADDRESS,
  PUBLIC_L1_TOKEN_VAULT_ADDRESS,
  PUBLIC_L2_BRIDGE_ADDRESS,
  PUBLIC_L2_CHAIN_ID,
  PUBLIC_L2_CHAIN_NAME,
  PUBLIC_L2_CROSS_CHAIN_SYNC_ADDRESS,
  PUBLIC_L2_EXPLORER_URL,
  PUBLIC_L2_RPC_URL,
  PUBLIC_L2_SIGNAL_SERVICE_ADDRESS,
  PUBLIC_L2_TOKEN_VAULT_ADDRESS,
} from '$env/static/public';

export const mainnetChain: Chain = {
  id: Number(PUBLIC_L1_CHAIN_ID),
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
};

export const taikoChain: Chain = {
  id: Number(PUBLIC_L2_CHAIN_ID),
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
};

export const chains = [mainnetChain, taikoChain];

export const chainContractsMap: Record<
  string,
  {
    bridgeAddress: Address;
    tokenVaultAddress: Address;
    crossChainSyncAddress: Address;
    signalServiceAddress: Address;
  }
> = {
  [PUBLIC_L1_CHAIN_ID]: {
    bridgeAddress: PUBLIC_L1_BRIDGE_ADDRESS as Address,
    tokenVaultAddress: PUBLIC_L1_TOKEN_VAULT_ADDRESS as Address,
    crossChainSyncAddress: PUBLIC_L1_CROSS_CHAIN_SYNC_ADDRESS as Address,
    signalServiceAddress: PUBLIC_L1_SIGNAL_SERVICE_ADDRESS as Address,
  },
  [PUBLIC_L2_CHAIN_ID]: {
    bridgeAddress: PUBLIC_L2_BRIDGE_ADDRESS as Address,
    tokenVaultAddress: PUBLIC_L2_TOKEN_VAULT_ADDRESS as Address,
    crossChainSyncAddress: PUBLIC_L2_CROSS_CHAIN_SYNC_ADDRESS as Address,
    signalServiceAddress: PUBLIC_L2_SIGNAL_SERVICE_ADDRESS as Address,
  },
};
