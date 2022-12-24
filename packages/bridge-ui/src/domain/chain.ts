import type { Chain as WagmiChain } from "@wagmi/core";
import { BigNumber } from "ethers";
import type { ComponentType } from "svelte";

import Eth from "../components/icons/ETH.svelte";
import Taiko from "../components/icons/TKO.svelte";

export const CHAIN_ID_MAINNET = import.meta.env
  ? BigNumber.from(import.meta.env.VITE_MAINNET_CHAIN_ID).toNumber()
  : 31336;

export const CHAIN_ID_TAIKO = import.meta.env
  ? BigNumber.from(import.meta.env.VITE_TAIKO_CHAIN_ID).toNumber()
  : 167001;

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
  id: CHAIN_ID_MAINNET,
  name: import.meta.env
    ? import.meta.env.VITE_MAINNET_CHAIN_NAME
    : "Ethereum A1",
  rpc: "https://l1rpc.a1.taiko.xyz",
  enabled: true,
  icon: Eth,
  bridgeAddress: import.meta.env
    ? import.meta.env.VITE_MAINNET_BRIDGE_ADDRESS
    : "0x3612E284D763f42f5E4CB72B1602b23DAEC3cA60",
  headerSyncAddress: import.meta.env
    ? import.meta.env.VITE_MAINNET_HEADER_SYNC_ADDRESS
    : "0x7B3AF414448ba906f02a1CA307C56c4ADFF27ce7",
  explorerUrl: "https://l1explorer.a1.taiko.xyz",
};

export const CHAIN_TKO = {
  id: CHAIN_ID_TAIKO,
  name: import.meta.env ? import.meta.env.VITE_TAIKO_CHAIN_NAME : "Taiko A1",
  rpc: "https://l2rpc.a1.taiko.xyz",
  enabled: true,
  icon: Taiko,
  bridgeAddress: import.meta.env
    ? import.meta.env.VITE_TAIKO_BRIDGE_ADDRESS
    : "0x0000777700000000000000000000000000000004",
  headerSyncAddress: import.meta.env
    ? import.meta.env.VITE_TAIKO_HEADER_SYNC_ADDRESS
    : "0x0000777700000000000000000000000000000001",
  explorerUrl: "https://l2explorer.a1.taiko.xyz",
};

export const chains: Record<string, Chain> = {
  [CHAIN_ID_MAINNET]: CHAIN_MAINNET,
  [CHAIN_ID_TAIKO]: CHAIN_TKO,
};

export const mainnet: WagmiChain = {
  id: CHAIN_ID_MAINNET,
  name: "Ethereum A1",
  network: "",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: {
    default: {
      http: ["https://l1rpc.a1.taiko.xyz"],
    },
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
};

export const taiko: WagmiChain = {
  id: CHAIN_ID_TAIKO,
  name: "Taiko A1",
  network: "",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: {
    default: {
      http: ["https://l2rpc.a1.taiko.xyz"],
    },
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
};
