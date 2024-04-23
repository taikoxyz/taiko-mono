import type { Address, GetContractReturnType, Hash, Hex, TransactionReceipt, WalletClient } from 'viem';

import type { bridgeAbi } from '$abi';
import type { ChainID } from '$libs/chain';
import type { NFT, Token, TokenType } from '$libs/token';

export enum MessageStatus {
  NEW,
  RETRIABLE,
  DONE,
  FAILED,
  PROVEN, // UI ONLY
}

// struct Message {
// Message ID whose value is automatically assigned.
// uint64 id;
// The max processing fee for the relayer. This fee has 3 parts:
// - the fee for message calldata.
// - the minimal fee reserve for general processing, excluding function call.
// - the invocation fee for the function call.
// Any unpaid fee will be refunded to the destOwner on the destination chain.
// Note that fee must be 0 if gasLimit is 0, or large enough to make the invocation fee
// non-zero.
// uint64 fee;
// gasLimit that the processMessage call must have.
// uint32 gasLimit;
// The address, EOA or contract, that interacts with this bridge.
// The value is automatically assigned.
// address from;
// Source chain ID whose value is automatically assigned.
// uint64 srcChainId;
// The owner of the message on the source chain.
// address srcOwner;
// Destination chain ID where the `to` address lives.
// uint64 destChainId;
// The owner of the message on the destination chain.
// address destOwner;
// The destination address on the destination chain.
// address to;
// value to invoke on the destination chain.
// uint256 value;
// callData to invoke on the destination chain.
// bytes data;
// }
export type Message = {
  // Message ID. Will be set in contract
  id: bigint;
  // The address, EOA or contract, that interacts with this bridge.
  from: Address;
  // Source chain ID (auto filled)
  srcChainId: bigint;
  // Destination chain ID where the `to` address lives (auto filled)
  destChainId: bigint;
  // User address of the bridged asset on the source chain.
  srcOwner: Address;
  // The owner of the message on the destination chain.
  destOwner: Address;
  // Destination owner address
  to: Address;
  // value to invoke on the destination chain, for ERC20 transfers.
  value: bigint;
  // Processing fee for the relayer. Zero if owner will process themself.
  fee: bigint;
  // gasLimit to invoke on the destination chain, for ERC20 transfers.
  gasLimit: number;
  // callData to invoke on the destination chain, for ERC20 transfers.
  data: Hex;
};

// Todo: adjust relayer to return same as bridge
// Identical to Message, but relayer uses capitalization
export type RelayerMessage = {
  Id: bigint;
  From: Address;
  SrcChainId: bigint;
  DestChainId: bigint;
  SrcOwner: Address;
  DestOwner: Address;
  To: Address;
  RefundTo: Address;
  Value: bigint;
  Fee: bigint;
  GasLimit: number;
  Data: Hex | string;
  Memo: string;
};

// viem expects a bigint, but the receipt.blockNumber is a hex string
export type ModifiedTransactionReceipt = Omit<TransactionReceipt, 'blockNumber'> & { blockNumber: Hex };

export type BridgeTransaction = {
  hash: Hash;
  from: Address;
  amount: bigint;
  symbol: string;
  decimals: number;
  srcChainId: ChainID;
  destChainId: ChainID;
  tokenType: TokenType;
  blockNumber: Hex;
  msgHash: Hash;
  message?: Message;
  msgStatus?: MessageStatus;

  // Used for sorting local ones
  timestamp?: number;

  status?: MessageStatus;
  receipt?: TransactionReceipt;
};

interface BaseBridgeTransferOp {
  destChainId: bigint;
  destOwner: Address;
  to: Address;
  token: Address;
  gasLimit: number;
  fee: bigint;
}

export interface BridgeTransferOp extends BaseBridgeTransferOp {
  amount: bigint;
}

export interface NFTBridgeTransferOp {
  destChainId: bigint;
  destOwner: Address;
  to: Address;
  token: Address;
  gasLimit: number;
  fee: bigint;
  tokenIds: bigint[];
  amounts: bigint[];
}

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
  tokenObject: Token | NFT;
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
  tokenIds: number[];
  amounts: number[];
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
  bridgeTx: BridgeTransaction;
  wallet: WalletClient;
  lastAttempt?: boolean; // used for retrying
};

export type ProcessMessageType = ClaimArgs & {
  bridgeContract: GetContractReturnType<typeof bridgeAbi, WalletClient>;
  client: WalletClient;
};

export type RetryMessageArgs = ProcessMessageType;

export type ReleaseArgs = ProcessMessageType;

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
  hops?: Array<HopAddressConfig>;
};

export type HopAddressConfig = {
  chainId: number;
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
  tokenType: TokenType;
  contractType: ContractType;
};

export type GetMaxToBridgeArgs = {
  to: Address;
  token: Token;
  balance: bigint;
  fee: bigint;
  srcChainId: number;
  destChainId: number;
};
