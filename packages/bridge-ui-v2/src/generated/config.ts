import type { Address } from "viem";

type Urls = {
  rpc: string;
  explorer: string;
};

enum LayerType {
  L1 = "L1",
  L2 = "L2",
  L3 = "L3",
}

export type ChainConfig = {
  name: string;
  urls: Urls;
  type: LayerType;
};
export type AddressConfig = {
  bridgeAddress: Address;
  erc20VaultAddress: Address;
  erc721VaultAddress: Address;
  erc1155VaultAddress: Address;
  crossChainSyncAddress: Address;
  signalServiceAddress: Address;
};
export type RoutingMap = Record<string, Record<string, AddressConfig>>;
export type ChainConfigMap = Record<number, ChainConfig>;

export const routingContractsMap: RoutingMap = {
  167005: {
    167006: {
      bridgeAddress: "0x1000777700000000000000000000000000000004",
      erc20VaultAddress: "0x1000777700000000000000000000000000000002",
      erc721VaultAddress: "0x1000777700000000000000000000000000000721",
      erc1155VaultAddress: "0x1000777700000000000000000000000000001155",
      crossChainSyncAddress: "0x1000777700000000000000000000000000000001",
      signalServiceAddress: "0x1000777700000000000000000000000000000007",
    },
    11155111: {
      bridgeAddress: "0x7D992599E1B8b4508Ba6E2Ba97893b4C36C23A28",
      erc20VaultAddress: "0xD70506580B5F65e68ed0dbA7B4Ae507641C48197",
      erc721VaultAddress: "0x1000777700000000000000000000000000000721",
      erc1155VaultAddress: "0x1000777700000000000000000000000000001155",
      crossChainSyncAddress: "0x6375394335f34848b850114b66A49D6F47f2cdA8",
      signalServiceAddress: "0x23baAc3892a823e9E59B85d6c90068474fe60086",
    },
  },
  167006: {
    167005: {
      bridgeAddress: "0x21561e1c1c64e18aB02654F365F3b0f7509d9481",
      erc20VaultAddress: "0xD90d8e85d0472eBC61267Ecbba544252b7197452",
      erc721VaultAddress: "0x1000777700000000000000000000000000000721",
      erc1155VaultAddress: "0x1000777700000000000000000000000000001155",
      crossChainSyncAddress: "0x4e7c942D51d977459108bA497FDc71ae0Fc54a00",
      signalServiceAddress: "0x5d2a35AC6464596b7aA04fdb69c5aFC37e391dFf",
    },
  },
  11155111: {
    167005: {
      bridgeAddress: "0x1000777700000000000000000000000000000004",
      erc20VaultAddress: "0xD70506580B5F65e68ed0dbA7B4Ae507641C48197",
      erc721VaultAddress: "0x1000777700000000000000000000000000000721",
      erc1155VaultAddress: "0x1000777700000000000000000000000000001155",
      crossChainSyncAddress: "0x1000777700000000000000000000000000000001",
      signalServiceAddress: "0x5d2a35AC6464596b7aA04fdb69c5aFC37e391dFf",
    },
  },
};
export const chainConfig: ChainConfigMap = {
  167005: {
    name: "Grimsvotn",
    type: LayerType.L2,
    urls: {
      rpc: "https://rpc.test.taiko.xyz",
      explorer: "https://test.taikoscan.io",
    },
  },
  167006: {
    name: "Eldfell",
    type: LayerType.L3,
    urls: {
      rpc: "https://rpc.l3test.taiko.xyz",
      explorer: "https://explorer.l3test.taiko.xyz/",
    },
  },
  11155111: {
    name: "Sepolia",
    type: LayerType.L1,
    urls: {
      rpc: "https://l1rpc.test.taiko.xyz",
      explorer: "https://sepolia.etherscan.io",
    },
  },
};
