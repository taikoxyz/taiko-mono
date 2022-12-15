import type { Chain as WagmiChain } from "@wagmi/core";
import type { ComponentType } from "svelte";

import Eth from "../components/icons/ETH.svelte";
import Taiko from "../components/icons/TKO.svelte";

export type Chain = {
  id: number;
  name: string;
  rpc: string;
  enabled?: boolean;
  icon?: ComponentType;
  bridgeAddress: string;
  headerSyncAddress: string;
  explorerUrl: string;
};

export const CHAIN_MAINNET = {
  id: 31336,
  name: "Ethereum A1",
  rpc: "https://l1rpc.a1.taiko.xyz",
  enabled: true,
  icon: Eth,
  bridgeAddress: "0x0237443359aB0b11EcDC41A7aF1C90226a88c70f",
  headerSyncAddress: "0xa7dF1d30f6456Dc72cE18fE011896105651a1f86",
  explorerUrl: "https://l1explorer.a1.taiko.xyz",
};

export const CHAIN_TKO = {
  id: 167001,
  name: "Taiko A1",
  rpc: "https://l2rpc.a1.taiko.xyz",
  enabled: true,
  icon: Taiko,
  bridgeAddress: "0x0000777700000000000000000000000000000004",
  headerSyncAddress: "0x0000777700000000000000000000000000000001",
  explorerUrl: "https://l2explorer.a1.taiko.xyz",
};

export const chains: Record<string, Chain> = {
  31336: CHAIN_MAINNET,
  167001: CHAIN_TKO,
};

export const mainnet: WagmiChain = {
  id: 31336,
  name: "Ethereum A1",
  network: "",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: {
    default: "https://l1rpc.a1.taiko.xyz",
  },
  blockExplorers: {
    default: {
      name: "Main",
      url: "https://l1explorer.a1.taiko.xyz",
    },
  },
  // ens: {
  //   address: "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e",
  // },
  multicall: {
    address: "0xca11bde05977b3631167028862be2a173976ca11",
    blockCreated: 14353601,
  },
};

export const taiko: WagmiChain = {
  id: 167001,
  name: "Taiko A1",
  network: "",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: {
    default: "https://l2rpc.a1.taiko.xyz",
  },
  blockExplorers: {
    default: {
      name: "Main",
      url: "https://l2explorer.a1.taiko.xyz",
    },
  },
  // ens: {
  //   address: "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e",
  // },
  multicall: {
    address: "0xca11bde05977b3631167028862be2a173976ca11",
    blockCreated: 14353601,
  },
};
