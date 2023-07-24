import type { WalletClient } from '@wagmi/core';
import type { Address, Hash, Hex } from 'viem';

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

export type GenerateProofArgs = {
  msgHash: Hash;
  chainId: number;
  sender: Address;
  srcChainId: number;
  destChainId: number;
};

export type GenerateProofClaimArgs = GenerateProofArgs & {
  destCrossChainSyncAddress: Address;
  srcSignalServiceAddress: Address;
};

export type GenerateProofReleaseArgs = GenerateProofArgs & {
  srcCrossChainSyncAddress: Address;
  destBridgeAddress: Address;
};

export type StorageEntry = {
  key: string;
  value: string;

  // Array of rlp-serialized MerkleTree-Nodes, starting with the storageHash-Node, following the path of the SHA3 (key) as path.
  proof: Hex[];
};

export type EthGetProofResponse = {
  balance: bigint;
  codeHash: Hash;
  nonce: number;
  storageHash: Hash;

  // Array of rlp-serialized MerkleTree-Nodes, starting with the stateRoot-Node, following the path of the SHA3 (address) as key.
  accountProof: Hex[];

  // Array of storage-entries as requested
  storageProof: StorageEntry[];
};

export type ClientWithEthProofRequest = {
  request(getProofArgs: {
    method: 'eth_getProof';
    params: [Address, Hex[], number | Hash | 'latest' | 'earliest'];
  }): Promise<EthGetProofResponse>;
};
