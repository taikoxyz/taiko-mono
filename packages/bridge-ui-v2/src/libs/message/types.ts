export enum MessageStatus {
  New,
  Retriable,
  Done,
  Failed,
  FailedReleased,
}

export type Message = {
  id: number
  sender: string
  srcChainId: string
  destChainId: string
  owner: string
  to: string
  refundAddress: string
  depositValue: bigint
  callValue: bigint
  processingFee: bigint
  gasLimit: bigint
  data: string
  memo: string
}
