import type { TransactionReceipt } from 'ethers'

import type { Message, MessageStatus } from '../message/types'

export type BridgeTransaction = {
  hash: string
  from: string
  receipt?: TransactionReceipt
  status: MessageStatus
  msgHash?: string
  message?: Message
  interval?: NodeJS.Timer
  amountInWei?: bigint
  symbol?: string
  fromChainId: string
  toChainId: string
}
