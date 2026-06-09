"use client";

/**
 * TanStack React Query hooks co-located with the `util` data fetchers.
 *
 * IMPORTANT: each hook merely WRAPS the corresponding pure async function (which is
 * exported unchanged from its own module) in `useQuery`. Any non-React caller can
 * keep importing the underlying function directly — these hooks add React caching/
 * dedupe without altering behavior. Query keys stringify bigints so they hash safely.
 */
import type { Address, Hash } from "viem";
import { useQuery } from "@tanstack/react-query";

import { geBlockTimestamp } from "./getBlockTimestamp";
import { getBaseFee } from "./getBaseFee";
import { getBlockFromTxHash } from "./getBlockFromTxHash";
import { getLatestBlockTimestamp } from "./getLatestBlockTimestamp";
import { isBlockCached } from "./isBlockCached";
import { isSmartContract } from "./isSmartContract";
import { checkForPausedContracts } from "./checkForPausedContracts";
import { fetchTransactionReceipt } from "./fetchTransactionReceipt";

/** Whether any configured bridge contract is currently paused. */
export function usePausedContracts(enabled = true) {
  return useQuery({
    queryKey: ["pausedContracts"],
    queryFn: () => checkForPausedContracts(),
    enabled,
  });
}

/** Whether `walletAddress` is a smart contract on `chainId`. */
export function useIsSmartContract(walletAddress?: Address, chainId?: number) {
  return useQuery({
    queryKey: ["isSmartContract", walletAddress, chainId],
    queryFn: () => isSmartContract(walletAddress as Address, chainId as number),
    enabled: Boolean(walletAddress) && Boolean(chainId),
  });
}

/** Latest base fee per gas for `chainId`. */
export function useBaseFee(chainId?: bigint) {
  return useQuery({
    queryKey: ["baseFee", chainId?.toString()],
    queryFn: () => getBaseFee(chainId as bigint),
    enabled: chainId !== undefined,
  });
}

/** Latest block timestamp for `srcChainId`. */
export function useLatestBlockTimestamp(srcChainId?: bigint) {
  return useQuery({
    queryKey: ["latestBlockTimestamp", srcChainId?.toString()],
    queryFn: () => getLatestBlockTimestamp(srcChainId as bigint),
    enabled: srcChainId !== undefined,
  });
}

/** Timestamp of a specific block on `srcChainId`. */
export function useBlockTimestamp(srcChainId?: bigint, blockNumber?: bigint) {
  return useQuery({
    queryKey: [
      "blockTimestamp",
      srcChainId?.toString(),
      blockNumber?.toString(),
    ],
    queryFn: () =>
      geBlockTimestamp(srcChainId as bigint, blockNumber as bigint),
    enabled: srcChainId !== undefined && blockNumber !== undefined,
  });
}

/** Block number that included `txHash` on `chainId`. */
export function useBlockFromTxHash(txHash?: Hash, chainId?: bigint) {
  return useQuery({
    queryKey: ["blockFromTxHash", txHash, chainId?.toString()],
    queryFn: () => getBlockFromTxHash(txHash as Hash, chainId as bigint),
    enabled: Boolean(txHash) && chainId !== undefined,
  });
}

/** Whether a block is cached (checkpointed) on the destination signal service. */
export function useIsBlockCached(params?: {
  srcChainId: number;
  destChainId: number;
  blockNumber: bigint;
}) {
  return useQuery({
    queryKey: [
      "isBlockCached",
      params?.srcChainId,
      params?.destChainId,
      params?.blockNumber.toString(),
    ],
    queryFn: () =>
      isBlockCached(
        params as {
          srcChainId: number;
          destChainId: number;
          blockNumber: bigint;
        },
      ),
    enabled: Boolean(params),
  });
}

/** Raw `eth_getTransactionReceipt` for `transactionHash` on `chainId`. */
export function useTransactionReceipt(
  transactionHash?: Hash,
  chainId?: number,
) {
  return useQuery({
    queryKey: ["transactionReceipt", transactionHash, chainId],
    queryFn: () =>
      fetchTransactionReceipt(transactionHash as Hash, chainId as number),
    enabled: Boolean(transactionHash) && chainId !== undefined,
  });
}

// The connected-account ETH balance query lives with its store; re-export for discoverability.
export { useEthBalance } from "$stores/balance";
