import type { WalletClient } from '@wagmi/core';
import type { Address, Hex } from 'viem';

export enum MessageStatus {
  New,
  Retriable,
  Done,
  Failed,
}

// Bridge sendMessage(message: Message)
export type BridgeMessage = {
  // Message ID. Will be set in contract
  Id: bigint;
  // Message sender address (auto filled)
  Sender: Address;
  // Source chain ID (auto filled)
  SrcChainId: bigint;
  // Destination chain ID where the `to` address lives (auto filled)
  DestChainId: bigint;
  // Owner address of the bridged asset.
  Owner: Address;
  // Destination owner address
  To: Address;
  // Alternate address to send any refund. If blank, defaults to owner.
  RefundAddress: Address;
  // Deposited Ether minus the processingFee.
  DepositValue: bigint;
  // callValue to invoke on the destination chain, for ERC20 transfers.
  CallValue: bigint;
  // Processing fee for the relayer. Zero if owner will process themself.
  ProcessingFee: bigint;
  // gasLimit to invoke on the destination chain, for ERC20 transfers.
  GasLimit: bigint;
  // callData to invoke on the destination chain, for ERC20 transfers.
  Data: Hex;
  // Optional memo.
  Memo: string;
};

// todo: relayer returns with capital letters, switch to lowercase
export type Message = {
  id: bigint;
  sender: Address;
  srcChainId: bigint;
  destChainId: bigint;
  owner: Address;
  to: Address;
  refundAddress: Address;
  depositValue: bigint;
  callValue: bigint;
  processingFee: bigint;
  gasLimit: bigint;
  data: Hex;
  memo: string;
};

// TokenVault sendERC20(...args)
export type SendERC20Args = [
  bigint, // destChainId
  Address, // to
  Address, // token
  bigint, // amount
  bigint, // gasLimit
  bigint, // processingFee
  Address, // refundAddress
  string, // memo
];

// TODO: future sendToken(op: BridgeTransferOp)
export type BridgeTransferOp = {
  destChainId: bigint;
  to: Address;
  token: Address;
  amount: bigint;
  gasLimit: bigint;
  processingFee: bigint;
  refundAddress: Address;
  memo: string;
};

export type ApproveArgs = {
  amount: bigint;
  tokenAddress: Address;
  spenderAddress: Address;
  wallet: WalletClient;
};

export type BridgeArgs = {
  to: Address;
  wallet: WalletClient;
  srcChainId: number;
  destChainId: number;
  amount: bigint;
  processingFee: bigint;
  memo?: string;
};

export type ETHBridgeArgs = BridgeArgs & {
  bridgeAddress: Address;
};

export type ERC20BridgeArgs = BridgeArgs & {
  tokenAddress: Address;
  tokenVaultAddress: Address;
  isTokenAlreadyDeployed?: boolean;
};

export type RequireAllowanceArgs = {
  tokenAddress: Address;
  ownerAddress: Address;
  spenderAddress: Address;
  amount: bigint;
};

export interface Bridge {
  estimateGas(args: BridgeArgs): Promise<bigint>;
  bridge(args: BridgeArgs): Promise<Hex>;
}
