import {
  PUBLIC_L1_BRIDGE_ADDRESS,
  PUBLIC_L1_CHAIN_ID,
  PUBLIC_L1_CHAIN_NAME,
  PUBLIC_L1_EXPLORER_URL,
  PUBLIC_L1_HEADER_SYNC_ADDRESS,
  PUBLIC_L1_RPC,
  PUBLIC_L1_SIGNAL_SERVICE_ADDRESS,
  PUBLIC_L2_BRIDGE_ADDRESS,
  PUBLIC_L2_CHAIN_ID,
  PUBLIC_L2_CHAIN_NAME,
  PUBLIC_L2_EXPLORER_URL,
  PUBLIC_L2_HEADER_SYNC_ADDRESS,
  PUBLIC_L2_RPC,
  PUBLIC_L2_SIGNAL_SERVICE_ADDRESS,
} from '$env/static/public'

import type { Chain, ChainsRecord } from './types'

export const mainnetChain: Chain = {
  id: PUBLIC_L1_CHAIN_ID,
  name: PUBLIC_L1_CHAIN_NAME,
  rpc: PUBLIC_L1_RPC,
  enabled: true,
  bridgeAddress: PUBLIC_L1_BRIDGE_ADDRESS,
  headerSyncAddress: PUBLIC_L1_HEADER_SYNC_ADDRESS,
  explorerUrl: PUBLIC_L1_EXPLORER_URL,
  signalServiceAddress: PUBLIC_L1_SIGNAL_SERVICE_ADDRESS,
}

export const taikoChain: Chain = {
  id: PUBLIC_L2_CHAIN_ID,
  name: PUBLIC_L2_CHAIN_NAME,
  rpc: PUBLIC_L2_RPC,
  enabled: true,
  bridgeAddress: PUBLIC_L2_BRIDGE_ADDRESS,
  headerSyncAddress: PUBLIC_L2_HEADER_SYNC_ADDRESS,
  explorerUrl: PUBLIC_L2_EXPLORER_URL,
  signalServiceAddress: PUBLIC_L2_SIGNAL_SERVICE_ADDRESS,
}

export const chains: ChainsRecord = {
  [PUBLIC_L1_CHAIN_ID]: mainnetChain,
  [PUBLIC_L2_CHAIN_ID]: taikoChain,
}
