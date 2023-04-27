export type Chain = {
  id: string
  name: string
  rpc: string
  enabled?: boolean
  bridgeAddress: string
  xChainSyncAddress: string
  explorerUrl: string
  signalServiceAddress: string
}

export type ChainsRecord = Record<string, Chain>
