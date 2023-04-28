import type { BigNumber } from 'ethers'

export enum MessageStatus {
  New,
  Retriable,
  Done,
  Failed,
  FailedReleased,
}

export type Message = {
  id?: number // it's set in contract
  data?: string // for ERC20 transfer
  sender: string
  srcChainId: string
  destChainId: string
  owner: string
  to: string
  refundAddress: string
  depositValue: BigNumber
  callValue: BigNumber
  processingFee: BigNumber
  gasLimit: BigNumber
  memo: string
}
