import type { ComponentType } from 'svelte'

export type Chain = {
  id: string
  name: string
  rpc: string
  enabled?: boolean
  icon?: ComponentType
  bridgeAddress: string
  headerSyncAddress: string
  explorerUrl: string
  signalServiceAddress: string
}

export type ChainsRecord = Record<string, Chain>
