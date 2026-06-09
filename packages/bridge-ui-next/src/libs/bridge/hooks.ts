"use client";

import {
  useMutation,
  type UseMutationOptions,
  type UseMutationResult,
  useQuery,
  type UseQueryOptions,
  type UseQueryResult,
} from "@tanstack/react-query";
import type { Address, Hash, Hex } from "viem";

import type { NFT } from "$libs/token";
import type { FetchNftArgs } from "$nftAPI/infrastructure/types/common";

import type { Bridge } from "./Bridge";
import { estimateCostOfBridging } from "./estimateCostOfBridging";
import { fetchNFTs } from "./fetchNFTs";
import { fetchTransactions } from "./fetchTransactions";
import { getMaxAmountToBridge } from "./getMaxAmountToBridge";
import { getMessageStatusForMsgHash } from "./getMessageStatusForMsgHash";
import { isTransactionProcessable } from "./isTransactionProcessable";
import type {
  BridgeArgs,
  BridgeTransaction,
  ClaimArgs,
  GetMaxToBridgeArgs,
  MessageStatus,
} from "./types";

/**
 * React Query wrappers around the read-only bridge fetchers, plus a mutation for
 * the bridge/claim write actions.
 *
 * The underlying pure async functions (fetchTransactions, fetchNFTs,
 * getMessageStatusForMsgHash, isTransactionProcessable, getMaxAmountToBridge,
 * estimateCostOfBridging) and the `bridges` map are left UNTOUCHED so non-React
 * callers can keep invoking them directly. These hooks only add
 * caching/deduplication (queries) and lifecycle (mutations) for the UI.
 *
 * Query keys follow the structured-array, bigint-safe convention: chain ids and
 * addresses inline; any bigint is stringified before it enters a key.
 */

// -------- fetchTransactions --------

export type UseBridgeTransactionsArgs = {
  userAddress: Address;
  chainId?: number;
};

function getBridgeTransactionsQueryKey({
  userAddress,
  chainId,
}: UseBridgeTransactionsArgs) {
  return ["bridgeTransactions", userAddress, chainId ?? null] as const;
}

export function useBridgeTransactions(
  args: UseBridgeTransactionsArgs,
  options?: Omit<
    UseQueryOptions<
      Awaited<ReturnType<typeof fetchTransactions>>,
      Error,
      Awaited<ReturnType<typeof fetchTransactions>>,
      ReturnType<typeof getBridgeTransactionsQueryKey>
    >,
    "queryKey" | "queryFn"
  >,
): UseQueryResult<Awaited<ReturnType<typeof fetchTransactions>>, Error> {
  return useQuery({
    queryKey: getBridgeTransactionsQueryKey(args),
    queryFn: () => fetchTransactions(args.userAddress, args.chainId),
    ...options,
  });
}

// -------- fetchNFTs --------

function getBridgeNFTsQueryKey({ address, chainId, refresh }: FetchNftArgs) {
  return ["bridgeNfts", chainId, address, refresh] as const;
}

export function useBridgeNFTs(
  args: FetchNftArgs,
  options?: Omit<
    UseQueryOptions<
      { nfts: NFT[]; error: Error | null },
      Error,
      { nfts: NFT[]; error: Error | null },
      ReturnType<typeof getBridgeNFTsQueryKey>
    >,
    "queryKey" | "queryFn"
  >,
): UseQueryResult<{ nfts: NFT[]; error: Error | null }, Error> {
  return useQuery({
    queryKey: getBridgeNFTsQueryKey(args),
    queryFn: () => fetchNFTs(args),
    ...options,
  });
}

// -------- getMessageStatusForMsgHash --------

export type UseMessageStatusArgs = {
  msgHash: Hash;
  srcChainId: number;
  destChainId: number;
};

function getMessageStatusQueryKey({
  msgHash,
  srcChainId,
  destChainId,
}: UseMessageStatusArgs) {
  return ["messageStatus", destChainId, srcChainId, msgHash] as const;
}

/**
 * Polls the destination bridge for a message status. Supply `refetchInterval`
 * via `options` to poll until DONE/RECALLED (replaces the old messageStatusPoller).
 */
export function useMessageStatus(
  args: UseMessageStatusArgs,
  options?: Omit<
    UseQueryOptions<
      MessageStatus,
      Error,
      MessageStatus,
      ReturnType<typeof getMessageStatusQueryKey>
    >,
    "queryKey" | "queryFn"
  >,
): UseQueryResult<MessageStatus, Error> {
  return useQuery({
    queryKey: getMessageStatusQueryKey(args),
    queryFn: () => getMessageStatusForMsgHash(args),
    ...options,
  });
}

// -------- isTransactionProcessable --------

function getIsTransactionProcessableQueryKey(bridgeTx: BridgeTransaction) {
  return [
    "isTransactionProcessable",
    bridgeTx.srcChainId.toString(),
    bridgeTx.destChainId.toString(),
    bridgeTx.srcTxHash,
    bridgeTx.msgHash,
    bridgeTx.msgStatus ?? null,
  ] as const;
}

export function useIsTransactionProcessable(
  bridgeTx: BridgeTransaction,
  options?: Omit<
    UseQueryOptions<
      boolean,
      Error,
      boolean,
      ReturnType<typeof getIsTransactionProcessableQueryKey>
    >,
    "queryKey" | "queryFn"
  >,
): UseQueryResult<boolean, Error> {
  return useQuery({
    queryKey: getIsTransactionProcessableQueryKey(bridgeTx),
    queryFn: () => isTransactionProcessable(bridgeTx),
    ...options,
  });
}

// -------- getMaxAmountToBridge --------

function getMaxAmountToBridgeQueryKey(args: GetMaxToBridgeArgs) {
  return [
    "maxAmountToBridge",
    args.srcChainId,
    args.destChainId,
    args.to,
    args.token.symbol,
    args.balance.toString(),
    args.fee.toString(),
  ] as const;
}

export function useMaxAmountToBridge(
  args: GetMaxToBridgeArgs,
  options?: Omit<
    UseQueryOptions<
      bigint,
      Error,
      bigint,
      ReturnType<typeof getMaxAmountToBridgeQueryKey>
    >,
    "queryKey" | "queryFn"
  >,
): UseQueryResult<bigint, Error> {
  return useQuery({
    queryKey: getMaxAmountToBridgeQueryKey(args),
    queryFn: () => getMaxAmountToBridge(args),
    ...options,
  });
}

// -------- estimateCostOfBridging --------

/**
 * Estimates the cost of bridging for a given bridge instance + args. Kept generic
 * over the bridge args union; gate the query on a connected wallet via `enabled`.
 */
export function useEstimateCostOfBridging(
  bridge: Bridge,
  bridgeArgs: Parameters<typeof estimateCostOfBridging>[1],
  queryKey: readonly unknown[],
  options?: Omit<
    UseQueryOptions<bigint, Error, bigint, readonly unknown[]>,
    "queryKey" | "queryFn"
  >,
): UseQueryResult<bigint, Error> {
  return useQuery({
    queryKey: ["estimateCostOfBridging", ...queryKey] as const,
    queryFn: () => estimateCostOfBridging(bridge, bridgeArgs),
    ...options,
  });
}

// -------- bridge (write) --------

/**
 * Mutation wrapping a bridge `bridge()` write action. The matching bridge
 * instance is selected from `bridges[tokenType]` by the caller and passed in.
 * Returns the tx hash, exactly as `Bridge.bridge`.
 */
export function useBridge(
  options?: UseMutationOptions<
    Hex,
    Error,
    { bridge: Bridge; args: BridgeArgs }
  >,
): UseMutationResult<Hex, Error, { bridge: Bridge; args: BridgeArgs }> {
  return useMutation({
    mutationFn: ({ bridge, args }) => bridge.bridge(args),
    ...options,
  });
}

// -------- processMessage (write: claim / retry / release) --------

export type ProcessMessageVariables = {
  bridge: Bridge;
  args: ClaimArgs;
  force?: boolean;
  skipMessageStatusCheck?: boolean;
};

/**
 * Mutation wrapping `Bridge.processMessage` (claim / retry / release flow).
 * The `bridges` map is consulted by the caller to pick the right bridge instance
 * for the transaction's token type.
 */
export function useProcessMessage(
  options?: UseMutationOptions<Hash, Error, ProcessMessageVariables>,
): UseMutationResult<Hash, Error, ProcessMessageVariables> {
  return useMutation({
    mutationFn: ({ bridge, args, force, skipMessageStatusCheck }) =>
      bridge.processMessage(args, force, skipMessageStatusCheck),
    ...options,
  });
}
