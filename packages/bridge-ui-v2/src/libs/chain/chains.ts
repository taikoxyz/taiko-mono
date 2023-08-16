import type { Address, Chain } from '@wagmi/core';

import {
  PUBLIC_L1_BRIDGE_ADDRESS,
  PUBLIC_L1_CHAIN_ID,
  PUBLIC_L1_CHAIN_NAME,
  PUBLIC_L1_CROSS_CHAIN_SYNC_ADDRESS,
  PUBLIC_L1_ERC20_VAULT_ADDRESS,
  PUBLIC_L1_ERC721_VAULT_ADDRESS,
  PUBLIC_L1_ERC1155_VAULT_ADDRESS,
  PUBLIC_L1_EXPLORER_URL,
  PUBLIC_L1_L2_BRIDGE_ADDRESS,
  PUBLIC_L1_L2_CROSS_CHAIN_SYNC_ADDRESS,
  PUBLIC_L1_L2_ERC20_VAULT_ADDRESS,
  PUBLIC_L1_L2_ERC721_VAULT_ADDRESS,
  PUBLIC_L1_L2_ERC1155_VAULT_ADDRESS,
  PUBLIC_L1_L2_SIGNAL_SERVICE_ADDRESS,
  PUBLIC_L1_RPC_URL,
  PUBLIC_L1_SIGNAL_SERVICE_ADDRESS,
  PUBLIC_L2_CHAIN_ID,
  PUBLIC_L2_CHAIN_NAME,
  PUBLIC_L2_EXPLORER_URL,
  PUBLIC_L2_RPC_URL,
  PUBLIC_L3_BRIDGE_ADDRESS,
  PUBLIC_L3_CHAIN_ID,
  PUBLIC_L3_CHAIN_NAME,
  PUBLIC_L3_CROSS_CHAIN_SYNC_ADDRESS,
  PUBLIC_L3_ERC20_VAULT_ADDRESS,
  PUBLIC_L3_ERC721_VAULT_ADDRESS,
  PUBLIC_L3_ERC1155_VAULT_ADDRESS,
  PUBLIC_L3_EXPLORER_URL,
  PUBLIC_L3_L2_BRIDGE_ADDRESS,
  PUBLIC_L3_L2_CROSS_CHAIN_SYNC_ADDRESS,
  PUBLIC_L3_L2_ERC20_VAULT_ADDRESS,
  PUBLIC_L3_L2_ERC721_VAULT_ADDRESS,
  PUBLIC_L3_L2_ERC1155_VAULT_ADDRESS,
  PUBLIC_L3_L2_SIGNAL_SERVICE_ADDRESS,
  PUBLIC_L3_RPC_URL,
  PUBLIC_L3_SIGNAL_SERVICE_ADDRESS,
} from '$env/static/public';

export type ChainID = bigint;

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
      name: 'Layer 2',
      url: PUBLIC_L2_EXPLORER_URL,
    },
  },
};

export const taikoL3Chain: Chain = {
  id: Number(PUBLIC_L3_CHAIN_ID),
  name: PUBLIC_L3_CHAIN_NAME,
  network: 'L3',
  nativeCurrency: {
    name: 'Ether',
    symbol: 'ETH',
    decimals: 18,
  },
  rpcUrls: {
    public: { http: [PUBLIC_L3_RPC_URL] },
    default: { http: [PUBLIC_L3_RPC_URL] },
  },
  blockExplorers: {
    default: {
      name: 'Layer 3',
      url: PUBLIC_L3_EXPLORER_URL,
    },
  },
};

//Todo: add L3 chain
export const chains = [mainnetChain, taikoChain, taikoL3Chain];

export const getChainName = (chainId: number) => {
  const chain = chains.find((chain) => chain.id === chainId);
  return chain?.name || chainId;
};

export const isSupportedChain = (chainId: ChainID): boolean => {
  return chains.some((chain) => BigInt(chain.id) === chainId);
};

export const chainUrlMap: Record<
  string,
  {
    rpcUrl: string;
    explorerUrl: string;
  }
> = {
  [PUBLIC_L1_CHAIN_ID]: {
    rpcUrl: PUBLIC_L1_RPC_URL,
    explorerUrl: PUBLIC_L1_EXPLORER_URL,
  },
  [PUBLIC_L2_CHAIN_ID]: {
    rpcUrl: PUBLIC_L2_RPC_URL,
    explorerUrl: PUBLIC_L2_EXPLORER_URL,
  },
  [PUBLIC_L3_CHAIN_ID]: {
    rpcUrl: PUBLIC_L3_RPC_URL,
    explorerUrl: PUBLIC_L3_EXPLORER_URL,
  },
};

// Todo: export to env?
export const chainIcons = {
  [PUBLIC_L1_CHAIN_ID]: '/ethereum-chain.png',
  [PUBLIC_L2_CHAIN_ID]: '/taiko-chain.png',
  [PUBLIC_L3_CHAIN_ID]: '/eldfell.svg',
};

type AddressConfig = {
  bridgeAddress: Address;
  erc20VaultAddress: Address;
  erc721VaultAddress: Address;
  erc1155VaultAddress: Address;
  crossChainSyncAddress: Address;
  signalServiceAddress: Address;
};

type ConfiguredChain = (typeof chains)[number]['id'];
type RoutingConfig = Record<ConfiguredChain, AddressConfig>;

export const routingContractsMap: Record<ConfiguredChain, RoutingConfig> = {
  [PUBLIC_L1_CHAIN_ID]: {
    // L1 -> L2
    [PUBLIC_L2_CHAIN_ID]: {
      bridgeAddress: PUBLIC_L1_BRIDGE_ADDRESS as Address,
      erc20VaultAddress: PUBLIC_L1_ERC20_VAULT_ADDRESS as Address,
      erc721VaultAddress: PUBLIC_L1_ERC721_VAULT_ADDRESS as Address,
      erc1155VaultAddress: PUBLIC_L1_ERC1155_VAULT_ADDRESS as Address,
      crossChainSyncAddress: PUBLIC_L1_CROSS_CHAIN_SYNC_ADDRESS as Address,
      signalServiceAddress: PUBLIC_L1_SIGNAL_SERVICE_ADDRESS as Address,
    } as AddressConfig,
  },
  [PUBLIC_L2_CHAIN_ID]: {
    // L2 -> L1
    [PUBLIC_L1_CHAIN_ID]: {
      bridgeAddress: PUBLIC_L1_L2_BRIDGE_ADDRESS as Address,
      erc20VaultAddress: PUBLIC_L1_L2_ERC20_VAULT_ADDRESS as Address,
      erc721VaultAddress: PUBLIC_L1_L2_ERC721_VAULT_ADDRESS as Address,
      erc1155VaultAddress: PUBLIC_L1_L2_ERC1155_VAULT_ADDRESS as Address,
      crossChainSyncAddress: PUBLIC_L1_L2_CROSS_CHAIN_SYNC_ADDRESS as Address,
      signalServiceAddress: PUBLIC_L1_L2_SIGNAL_SERVICE_ADDRESS as Address,
    } as AddressConfig,
    // L2 -> L3
    [PUBLIC_L3_CHAIN_ID]: {
      bridgeAddress: PUBLIC_L3_L2_BRIDGE_ADDRESS as Address,
      erc20VaultAddress: PUBLIC_L3_L2_ERC20_VAULT_ADDRESS as Address,
      erc721VaultAddress: PUBLIC_L3_L2_ERC721_VAULT_ADDRESS as Address,
      erc1155VaultAddress: PUBLIC_L3_L2_ERC1155_VAULT_ADDRESS as Address,
      crossChainSyncAddress: PUBLIC_L3_L2_CROSS_CHAIN_SYNC_ADDRESS as Address,
      signalServiceAddress: PUBLIC_L3_L2_SIGNAL_SERVICE_ADDRESS as Address,
    } as AddressConfig,
  },
  [PUBLIC_L3_CHAIN_ID]: {
    // L3 -> L2
    [PUBLIC_L2_CHAIN_ID]: {
      bridgeAddress: PUBLIC_L3_BRIDGE_ADDRESS as Address,
      erc20VaultAddress: PUBLIC_L3_ERC20_VAULT_ADDRESS as Address,
      erc721VaultAddress: PUBLIC_L3_ERC721_VAULT_ADDRESS as Address,
      erc1155VaultAddress: PUBLIC_L3_ERC1155_VAULT_ADDRESS as Address,
      crossChainSyncAddress: PUBLIC_L3_CROSS_CHAIN_SYNC_ADDRESS as Address,
      signalServiceAddress: PUBLIC_L3_SIGNAL_SERVICE_ADDRESS as Address,
    } as AddressConfig,
  },
};
