import type { BigNumber, ethers, Transaction } from 'ethers';
import type { ChainID } from './chain';
import type { Message } from './message';

export enum BridgeType {
  ERC20 = 'ERC20',
  ETH = 'ETH',
  ERC721 = 'ERC721',
  ERC1155 = 'ERC1155',
}

export enum BridgeChainType {
  L1_L2 = 'L1_L2',
  L2_L3 = 'L2_L3',
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
  RequiresAllowance(opts: ApproveOpts): Promise<boolean>;
  Approve(opts: ApproveOpts): Promise<Transaction>;
  Bridge(opts: BridgeOpts): Promise<Transaction>;
  EstimateGas(opts: BridgeOpts): Promise<BigNumber>;
  Claim(opts: ClaimOpts): Promise<Transaction>;
  ReleaseTokens(opts: ReleaseOpts): Promise<Transaction>;
}

// TODO: this should not be here
export interface HTMLBridgeForm extends HTMLFormElement {
  customTokenAddress: HTMLInputElement;
}
