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
};

export const CHAIN_MAINNET = {
  id: 31336,
  name: "Ethereum A1",
  rpc: "https://l1rpc.a1.taiko.xyz",
  enabled: true,
  icon: Eth,
};

export const CHAIN_TKO = {
  id: 167001,
  name: "Taiko A1",
  rpc: "https://l2rpc.a1.taiko.xyz",
  enabled: true,
  icon: Taiko,
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
  ens: {
    address: "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e",
  },
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
  ens: {
    address: "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e",
  },
  multicall: {
    address: "0xca11bde05977b3631167028862be2a173976ca11",
    blockCreated: 14353601,
  },
};
