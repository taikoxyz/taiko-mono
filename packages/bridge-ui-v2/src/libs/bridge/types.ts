import type { WalletClient } from '@wagmi/core';
import type { Address, Hex } from 'viem';

// Bridge sendMessage(message: Message)
export type Message = {
  // Message ID. Will be set in contract
  id: bigint;
  // Message sender address (auto filled)
  sender: Address;
  // Source chain ID (auto filled)
  srcChainId: bigint;
  // Destination chain ID where the `to` address lives (auto filled)
  destChainId: bigint;
  // Owner address of the bridged asset.
  owner: Address;
  // Destination owner address
  to: Address;
  // Alternate address to send any refund. If blank, defaults to owner.
  refundAddress: Address;
  // Deposited Ether minus the processingFee.
  depositValue: bigint;
  // callValue to invoke on the destination chain, for ERC20 transfers.
  callValue: bigint;
  // Processing fee for the relayer. Zero if owner will process themself.
  processingFee: bigint;
  // gasLimit to invoke on the destination chain, for ERC20 transfers.
  gasLimit: bigint;
  // callData to invoke on the destination chain, for ERC20 transfers.
  data: Hex;
  // Optional memo.
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
