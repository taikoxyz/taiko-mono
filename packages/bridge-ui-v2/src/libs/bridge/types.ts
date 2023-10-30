import type { Hash, WalletClient } from '@wagmi/core';
import type { Address, Hex, TransactionReceipt } from 'viem';

import type { ChainID } from '$libs/chain';
import type { TokenType } from '$libs/token';

export enum MessageStatus {
  NEW,
  RETRIABLE,
  DONE,
  FAILED,
}

// Bridge sendMessage()
// Claim/Retry processMessage()/retryMessage()
// Release releaseEthe()/releaseERC20()
export type Message = {
  // Message ID. Will be set in contract
  id: bigint;
  // Message from address (auto filled)
  from: Address;
  // Source chain ID (auto filled)
  srcChainId: bigint;
  // Destination chain ID where the `to` address lives (auto filled)
  destChainId: bigint;
  // User address of the bridged asset.
  user: Address;
  // Destination owner address
  to: Address;
  // Alternate address to send any refund. If blank, defaults to owner.
  refundTo: Address;
  // value to invoke on the destination chain, for ERC20 transfers.
  value: bigint;
  // Processing fee for the relayer. Zero if owner will process themself.
  fee: bigint;
  // gasLimit to invoke on the destination chain, for ERC20 transfers.
  gasLimit: bigint;
  // callData to invoke on the destination chain, for ERC20 transfers.
  data: Hex;
  // Optional memo.
  memo: string;
};

// Todo: adjust relayer to return same as bridge
// Identical to Message, but relayer uses capitalization
export type RelayerMessage = {
  Id: bigint;
  From: Address;
  SrcChainId: number | string | bigint;
  DestChainId: number | string | bigint;
  User: Address;
  To: Address;
  RefundTo: Address;
  Value: bigint;
  Fee: bigint;
  GasLimit: bigint;
  Data: Hex;
  Memo: string;
};

export type BridgeTransaction = {
  hash: Hash;
  from: Address;
  amount: bigint;
  symbol: string;
  decimals: number;
  srcChainId: ChainID;
  destChainId: ChainID;
  tokenType: TokenType;

  // Used for sorting local ones
  timestamp?: number;

  status?: MessageStatus;
  receipt?: TransactionReceipt;
  msgHash?: Hash;
  message?: Message;
};

export type BridgeTransferOp = {
  destChainId: bigint;
  to: Address;
  token: Address;
  amount: bigint;
  gasLimit: bigint;
  fee: bigint;
  refundTo: Address;
  memo: string;
};

export type NFTBridgeTransferOp = {
  destChainId: bigint;
  to: Address;
  token: Address;
  gasLimit: bigint;
  fee: bigint;
  refundTo: Address;
  memo: string;
  tokenIds: bigint[];
  amounts: bigint[];
};

export type ApproveArgs = {
  amount: bigint;
  tokenAddress: Address;
  spenderAddress: Address;
  wallet: WalletClient;
};

export type NFTApproveArgs = {
  amount?: bigint;
  tokenAddress: Address;
  spenderAddress: Address;
  wallet: WalletClient;
  tokenIds: bigint[];
};

export type BridgeArgs = {
  to: Address;
  wallet: WalletClient;
  srcChainId: number;
  destChainId: number;
  fee: bigint;
  memo?: string;
};

export type ETHBridgeArgs = BridgeArgs & {
  amount: bigint;
  bridgeAddress: Address;
};

export type ERC20BridgeArgs = BridgeArgs & {
  amount: bigint;
  token: Address;
  tokenVaultAddress: Address;
  isTokenAlreadyDeployed?: boolean;
};

export type ERC721BridgeArgs = BridgeArgs & {
  token: Address;
  tokenVaultAddress: Address;
  isTokenAlreadyDeployed?: boolean;
  tokenIds: bigint[];
  amounts: bigint[];
};

export type ERC1155BridgeArgs = ERC721BridgeArgs;

export type BridgeArgsMap = {
  [TokenType.ETH]: ETHBridgeArgs;
  [TokenType.ERC20]: ERC20BridgeArgs;
  [TokenType.ERC721]: ERC721BridgeArgs;
  [TokenType.ERC1155]: ERC1155BridgeArgs;
};

export type RequireAllowanceArgs = {
  tokenAddress: Address;
  ownerAddress: Address;
  spenderAddress: Address;
  amount: bigint;
};

export type RequireApprovalArgs = {
  tokenAddress: Address;
  spenderAddress: Address;
  tokenId: bigint;
  chainId: number;
  owner?: Address;
};

export type ClaimArgs = {
  msgHash: Hash;
  message: Message;
  wallet: WalletClient;
};

export type ReleaseArgs = ClaimArgs;
export interface Bridge {
  estimateGas(args: BridgeArgs): Promise<bigint>;
  bridge(args: BridgeArgs): Promise<Hex>;
}

export type ConfiguredBridgesType = {
  configuredBridges: Array<BridgeConfig>;
};

export type BridgeConfig = {
  source: string;
  destination: string;
  addresses: AddressConfig;
};

export type RoutingMap = Record<string, Record<string, AddressConfig>>;

export type AddressConfig = {
  bridgeAddress: Address;
  erc20VaultAddress: Address;
  etherVaultAddress?: Address;
  erc721VaultAddress: Address;
  erc1155VaultAddress: Address;
  crossChainSyncAddress: Address;
  signalServiceAddress: Address;
};

export enum ContractType {
  BRIDGE,
  VAULT,
  SIGNALSERVICE,
  CROSSCHAINSYNC,
}

export type GetContractAddressType = {
  srcChainId: number;
  destChainId: number;
  tokenType?: TokenType;
  contractType: ContractType;
};
