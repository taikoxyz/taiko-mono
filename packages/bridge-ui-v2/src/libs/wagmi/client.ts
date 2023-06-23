import { type Chain, configureChains, createConfig } from '@wagmi/core';
import { EthereumClient, w3mConnectors, w3mProvider } from '@web3modal/ethereum';
import { Web3Modal } from '@web3modal/html';

import {
  PUBLIC_L1_CHAIN_ID,
  PUBLIC_L1_CHAIN_NAME,
  PUBLIC_L1_EXPLORER_URL,
  PUBLIC_L1_RPC_URL,
  PUBLIC_L2_CHAIN_ID,
  PUBLIC_L2_CHAIN_NAME,
  PUBLIC_L2_EXPLORER_URL,
  PUBLIC_L2_RPC_URL,
  PUBLIC_WEB3_MODAL_PROJECT_ID,
} from '$env/static/public';

const mainnet: Chain = {
  id: PUBLIC_L1_CHAIN_ID,
  name: PUBLIC_L1_CHAIN_NAME,
  nativeCurrency: {
    name: 'Ether',
    symbol: 'ETH',
    decimals: 18,
  },
  rpcUrls: {
    default: { http: [PUBLIC_L1_RPC_URL] },
  },
  blockExplorers: {
    default: {
      name: 'Main',
      url: PUBLIC_L1_EXPLORER_URL,
    },
  },
};

const taiko: Chain = {
  id: PUBLIC_L2_CHAIN_ID,
  name: PUBLIC_L2_CHAIN_NAME,
  nativeCurrency: {
    name: 'Ether',
    symbol: 'ETH',
    decimals: 18,
  },
  rpcUrls: {
    default: { http: [PUBLIC_L2_RPC_URL] },
  },
  blockExplorers: {
    default: {
      name: 'Main',
      url: PUBLIC_L2_EXPLORER_URL,
    },
  },
};

const chains = [mainnet, taiko];

const projectId = PUBLIC_WEB3_MODAL_PROJECT_ID;

export const { publicClient } = configureChains(chains, [w3mProvider({ projectId })]);

const wagmiConfig = createConfig({
  autoConnect: true,
  connectors: w3mConnectors({ projectId, version: 2, chains }),
  publicClient,
});

export const ethereumClient = new EthereumClient(wagmiConfig, chains);

export const web3modal = new Web3Modal({ projectId }, ethereumClient);
