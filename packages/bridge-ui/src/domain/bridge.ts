import type { BigNumber, ethers, Transaction } from 'ethers';
import type { ChainID } from './chain';
import type { Message } from './message';

export enum BridgeType {
  ERC20 = 'ERC20',
  ETH = 'ETH',
  ERC721 = 'ERC721',
  ERC1155 = 'ERC1155',
}

export type ApproveOpts = {
  amountInWei: BigNumber;
  contractAddress: string;
  signer: ethers.Signer;
  spenderAddress: string;
};

export type BridgeOpts = {
  amountInWei: BigNumber;
  signer: ethers.Signer;
  tokenAddress: string;
  fromChainId: ChainID;
  toChainId: ChainID;
  tokenVaultAddress?: string;
  bridgeAddress?: string;
  processingFeeInWei?: BigNumber;
  tokenId?: string;
  memo?: string;
  isBridgedTokenAlreadyDeployed?: boolean;
  to: string;
};

export type ClaimOpts = {
  message: Message;
  msgHash: string;
  signer: ethers.Signer;
  destBridgeAddress: string;
  srcBridgeAddress: string;
};

export type ReleaseOpts = {
  message: Message;
  msgHash: string;
  signer: ethers.Signer;
  destBridgeAddress: string;
  srcBridgeAddress: string;
  destProvider: ethers.providers.JsonRpcProvider;
  srcTokenVaultAddress: string;
};

export interface Bridge {
  requiresAllowance(opts: ApproveOpts): Promise<boolean>;
  approve(opts: ApproveOpts): Promise<Transaction>;
  bridge(opts: BridgeOpts): Promise<Transaction>;
  estimateGas(opts: BridgeOpts): Promise<BigNumber>;
  claim(opts: ClaimOpts): Promise<Transaction>;
  releaseToken(opts: ReleaseOpts): Promise<Transaction>;
}
