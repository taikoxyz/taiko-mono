import type { BigNumber, providers } from 'ethers'

import type { Message, MessageStatus } from '../message/types'

export type BridgeTransaction = {
  hash: string
  from: string
  receipt?: providers.TransactionReceipt
  status: MessageStatus
  msgHash?: string
  message?: Message
  amountInWei?: BigNumber
  symbol?: string
  srcChainId: string
  destChainId: string
}
