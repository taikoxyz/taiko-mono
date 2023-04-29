import type { BigNumber, providers, Signer, Transaction } from 'ethers'

import type { Message } from '../message/types'

export enum BridgeType {
  ETH = 'ETH',

  // https://ethereum.org/en/developers/docs/standards/tokens/erc-20/
  ERC20 = 'ERC20',

  // https://ethereum.org/en/developers/docs/standards/tokens/erc-721/
  ERC721 = 'ERC721',

  // https://ethereum.org/en/developers/docs/standards/tokens/erc-1155/
  ERC1155 = 'ERC1155',
}

export type ApproveArgs = {
  amountInWei: BigNumber
  tokenAddress: string
  signer: Signer
  spenderAddress: string
}

export type BridgeArgs = {
  to: string
  signer: Signer
  srcChainId: string
  destChainId: string
  amountInWei: BigNumber
  memo?: string
  processingFeeInWei?: BigNumber
}

export type ETHBridgeArgs = BridgeArgs & {
  bridgeAddress: string
}

export type ERC20BridgeArgs = BridgeArgs & {
  tokenAddress: string
  tokenVaultAddress: string
  isBridgedTokenAlreadyDeployed?: boolean
}

export type ClaimArgs = {
  message: Message
  msgHash: string
  signer: Signer
  destBridgeAddress: string
  srcBridgeAddress: string
}

export type ReleaseArgs = ClaimArgs & {
  destProvider: providers.JsonRpcProvider
  srcTokenVaultAddress: string
}

export interface Bridge {
  // estimateGas(args: BridgeArgs): Promise<BigNumber>
  // bridge(args: BridgeArgs): Promise<Transaction>
  claim(args: ClaimArgs): Promise<Transaction>
  releaseTokens(args: ReleaseArgs): Promise<Transaction | undefined>
}
