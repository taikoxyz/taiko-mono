import type { WalletClient } from '@wagmi/core';
import type { Address } from 'abitype';

export enum BridgeType {
  ETH = 'ETH',

  // https://ethereum.org/en/developers/docs/standards/tokens/erc-20/
  ERC20 = 'ERC20',

  // https://ethereum.org/en/developers/docs/standards/tokens/erc-721/
  ERC721 = 'ERC721',

  // https://ethereum.org/en/developers/docs/standards/tokens/erc-1155/
  ERC1155 = 'ERC1155',
}

export type Message = {
  // Message sender address (auto filled)
  sender: Address;
  // Source chain ID (auto filled)
  srcChainId: number;
  // Destination chain ID where the `to` address lives (auto filled)
  destChainId: number;
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
  // Message ID. Will be set in contract
  id?: number;
  // callData to invoke on the destination chain, for ERC20 transfers.
  data?: string;
  // Optional memo.
  memo?: string;
};

export type ApproveArgs = {
  amount: bigint;
  tokenAddress: Address;
  spenderAddress: Address;
  walletClient: WalletClient;
};

export type BridgeArgs = {
  to: Address;
  srcChainId: number;
  destChainId: number;
  amount: bigint;
  walletClient: WalletClient;
  processingFee: bigint;
  memo?: string;
};

export type ETHBridgeArgs = BridgeArgs & {
  bridgeAddress: Address;
};

export type ERC20BridgeArgs = BridgeArgs & {
  tokenAddress: Address;
  tokenVaultAddress: Address;
  isBridgedTokenAlreadyDeployed?: boolean;
};
