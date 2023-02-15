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

const L1_RPC = import.meta?.env?.VITE_L1_RPC_URL ?? "https://l1rpc.internal.taiko.xyz/";

const L2_RPC = import.meta?.env?.VITE_L2_RPC_URL ?? "https://l2rpc.internal.taiko.xyz/";

const L1_BRIDGE_ADDRESS = import.meta?.env?.VITE_MAINNET_BRIDGE_ADDRESS ?? "0x0237443359aB0b11EcDC41A7aF1C90226a88c70f";

const L2_BRIDGE_ADDRESS = import.meta?.env?.VITE_TAIKO_BRIDGE_ADDRESS ?? "0x0000777700000000000000000000000000000004";

const L1_HEADER_SYNC_ADDRESS = import.meta?.env?.VITE_MAINNET_HEADER_SYNC_ADDRESS ?? "0xa6421A7f48498cee3aEb6428a8A2DD5fAA3AcE2f";

const L2_HEADER_SYNC_ADDRESS = import.meta?.env?.VITE_TAIKO_HEADER_SYNC_ADDRESS ?? "0x0000777700000000000000000000000000000001";

const L1_SIGNAL_SERVICE_ADDRESS = import.meta?.env?.VITE_MAINNET_SIGNAL_SERVICE_ADDRESS ?? "0x403cc7802725928652a3d116Bb1781005e2e76d3";

const L2_SIGNAL_SERVICE_ADDRESS = import.meta?.env?.VITE_TAIKO_SIGNAL_SERVICE_ADDRESS ?? "0x0000777700000000000000000000000000000007";

const L1_EXPLORER_URL = import.meta?.env?.VITE_L1_EXPLORER_URL ?? "https://l1explorer.internal.taiko.xyz/";

const L2_EXPLORER_URL = import.meta?.env?.VITE_L2_EXPLORER_URL ?? "https://l2explorer.internal.taiko.xyz/";

export type Chain = {
  id: number;
  name: string;
  rpc: string;
  enabled?: boolean;
  icon?: ComponentType;
  bridgeAddress: string;
  headerSyncAddress: string;
  explorerUrl: string;
  signalServiceAddress: string,
};

export const CHAIN_MAINNET = {
  id: CHAIN_ID_MAINNET,
  name: import.meta.env
    ? import.meta.env.VITE_MAINNET_CHAIN_NAME
    : "Ethereum A1",
  rpc: L1_RPC,
  enabled: true,
  icon: Eth,
  bridgeAddress: L1_BRIDGE_ADDRESS,
  headerSyncAddress: L1_HEADER_SYNC_ADDRESS,
  explorerUrl: L1_EXPLORER_URL,
  signalServiceAddress: L1_SIGNAL_SERVICE_ADDRESS
};

export const CHAIN_TKO = {
  id: CHAIN_ID_TAIKO,
  name: import.meta.env ? import.meta.env.VITE_TAIKO_CHAIN_NAME : "Taiko A2",
  rpc: L2_RPC,
  enabled: true,
  icon: Taiko,
  bridgeAddress: L2_BRIDGE_ADDRESS,
  headerSyncAddress: L2_HEADER_SYNC_ADDRESS,
  explorerUrl: L2_EXPLORER_URL,
  signalServiceAddress: L2_SIGNAL_SERVICE_ADDRESS,
};

export const chains: Record<string, Chain> = {
  [CHAIN_ID_MAINNET]: CHAIN_MAINNET,
  [CHAIN_ID_TAIKO]: CHAIN_TKO,
};

export const mainnet: WagmiChain = {
  id: CHAIN_ID_MAINNET,
  name: import.meta.env
  ? import.meta.env.VITE_MAINNET_CHAIN_NAME
  : "Ethereum A2",
  network: "",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: {
    default: {
      http: [L1_RPC],
    },
  },
  blockExplorers: {
    default: {
      name: "Main",
      url: L1_EXPLORER_URL,
    },
  },
  // ens: {
  //   address: "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e",
  // },
};

export const taiko: WagmiChain = {
  id: CHAIN_ID_TAIKO,
  name: import.meta.env ? import.meta.env.VITE_TAIKO_CHAIN_NAME : "Taiko A2",
  network: "",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: {
    default: {
      http: [L2_RPC],
    },
  },
  blockExplorers: {
    default: {
      name: "Main",
      url: L2_EXPLORER_URL,
    },
  },
  // ens: {
  //   address: "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e",
  // },
};
