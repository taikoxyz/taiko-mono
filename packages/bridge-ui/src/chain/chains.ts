import {
  L1_BRIDGE_ADDRESS,
  L1_CHAIN_ID,
  L1_CHAIN_NAME,
  L1_EXPLORER_URL,
  L1_CROSS_CHAIN_SYNC_ADDRESS,
  L1_RPC,
  L1_SIGNAL_SERVICE_ADDRESS,
  L2_BRIDGE_ADDRESS,
  L2_CHAIN_ID,
  L2_CHAIN_NAME,
  L2_EXPLORER_URL,
  L2_CROSS_CHAIN_SYNC_ADDRESS,
  L2_RPC,
  L2_SIGNAL_SERVICE_ADDRESS,
  L3_CHAIN_ID,
  L3_CHAIN_NAME,
  L3_RPC,
  L3_BRIDGE_ADDRESS,
  L3_CROSS_CHAIN_SYNC_ADDRESS,
  L3_EXPLORER_URL,
  L3_SIGNAL_SERVICE_ADDRESS,
} from '../constants/envVars';
import type { Chain, ChainID } from '../domain/chain';
import Eth from '../components/icons/ETH.svelte';
import Taiko from '../components/icons/TKO.svelte';

export const mainnetChain: Chain = {
  id: L1_CHAIN_ID,
  name: L1_CHAIN_NAME,
  rpc: L1_RPC,
  enabled: true,
  icon: Eth,
  bridgeAddress: L1_BRIDGE_ADDRESS,
  crossChainSyncAddress: L1_CROSS_CHAIN_SYNC_ADDRESS,
  explorerUrl: L1_EXPLORER_URL,
  signalServiceAddress: L1_SIGNAL_SERVICE_ADDRESS,
};

export const taikoChain: Chain = {
  id: L2_CHAIN_ID,
  name: L2_CHAIN_NAME,
  rpc: L2_RPC,
  enabled: true,
  icon: Taiko,
  bridgeAddress: L2_BRIDGE_ADDRESS,
  crossChainSyncAddress: L2_CROSS_CHAIN_SYNC_ADDRESS,
  explorerUrl: L2_EXPLORER_URL,
  signalServiceAddress: L2_SIGNAL_SERVICE_ADDRESS,
};

export const l3Chain: Chain = {
  id: L3_CHAIN_ID,
  name: L3_CHAIN_NAME,
  rpc: L3_RPC,
  enabled: true,
  icon: Taiko,
  bridgeAddress: L3_BRIDGE_ADDRESS,
  crossChainSyncAddress: L3_CROSS_CHAIN_SYNC_ADDRESS,
  explorerUrl: L3_EXPLORER_URL,
  signalServiceAddress: L3_SIGNAL_SERVICE_ADDRESS,
};

export const chains: Record<ChainID, Chain> = {
  [L1_CHAIN_ID]: mainnetChain,
  [L2_CHAIN_ID]: taikoChain,
  [L3_CHAIN_ID]: l3Chain,
};
