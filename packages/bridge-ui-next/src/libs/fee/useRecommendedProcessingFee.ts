"use client";

import {
  useQuery,
  type UseQueryOptions,
  type UseQueryResult,
} from "@tanstack/react-query";
import { type Address } from "viem";

import { type NFT, type Token } from "$libs/token/types";

import { recommendProcessingFee } from "./recommendProcessingFee";

export type UseRecommendedProcessingFeeArgs = {
  token: Token | NFT;
  destChainId: number;
  srcChainId?: number;
  to?: Address;
  tokenIds?: number[];
  amounts?: number[];
};

/**
 * Deterministic, bigint-safe query key for the recommended processing fee.
 *
 * Mirrors the structured-array key convention from the data migration plan
 * (`['recommendedFee', destChainId, srcChainId, token, tokenIds]`). The token
 * is reduced to its stable identity (type + symbol + address per chain) so the
 * key stays serializable and stable across renders.
 */
function getRecommendedProcessingFeeQueryKey({
  token,
  destChainId,
  srcChainId,
  to,
  tokenIds,
  amounts,
}: UseRecommendedProcessingFeeArgs) {
  return [
    "recommendedFee",
    destChainId,
    srcChainId ?? null,
    {
      type: token.type,
      symbol: token.symbol,
      addresses: token.addresses,
    },
    to ?? null,
    tokenIds ?? null,
    amounts ?? null,
  ] as const;
}

/**
 * React Query wrapper around the pure `recommendProcessingFee` fetcher.
 *
 * The underlying async function is left untouched so non-React callers can keep
 * invoking it directly. This hook only adds caching/deduplication for the UI.
 */
export function useRecommendedProcessingFee(
  args: UseRecommendedProcessingFeeArgs,
  options?: Omit<
    UseQueryOptions<
      bigint,
      Error,
      bigint,
      ReturnType<typeof getRecommendedProcessingFeeQueryKey>
    >,
    "queryKey" | "queryFn"
  >,
): UseQueryResult<bigint, Error> {
  return useQuery({
    queryKey: getRecommendedProcessingFeeQueryKey(args),
    queryFn: () => recommendProcessingFee(args),
    ...options,
  });
}
