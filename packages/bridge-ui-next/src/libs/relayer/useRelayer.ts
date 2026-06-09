"use client";

import {
  useQuery,
  type UseQueryOptions,
  type UseQueryResult,
} from "@tanstack/react-query";
import { type Address } from "viem";

import { getFirstAvailableBlockInfo } from "./getFirstAvailableBlockInfo";
import { relayerApiServices } from "./initRelayers";
import type {
  Fee,
  FeeType,
  GetAllByAddressResponse,
  PaginationParams,
  RelayerBlockInfo,
} from "./types";

/**
 * React Query wrappers around the read-only relayer fetchers.
 *
 * The underlying `RelayerAPIService` methods and the module-level
 * `getFirstAvailableBlockInfo` are left untouched so non-React callers can keep
 * invoking them directly. These hooks only add caching/deduplication for the UI.
 *
 * Query keys follow the structured-array, bigint-safe convention from the data
 * migration plan. Chain ids and addresses are inlined; no bigints appear in
 * relayer keys, so no special serialization is required here.
 */

// -------- getFirstAvailableBlockInfo --------

function getFirstAvailableBlockInfoQueryKey(srcChainId: number) {
  return ["relayerFirstAvailableBlockInfo", srcChainId] as const;
}

export function useFirstAvailableBlockInfo(
  srcChainId: number,
  options?: Omit<
    UseQueryOptions<
      RelayerBlockInfo | undefined,
      Error,
      RelayerBlockInfo | undefined,
      ReturnType<typeof getFirstAvailableBlockInfoQueryKey>
    >,
    "queryKey" | "queryFn"
  >,
): UseQueryResult<RelayerBlockInfo | undefined, Error> {
  return useQuery({
    queryKey: getFirstAvailableBlockInfoQueryKey(srcChainId),
    queryFn: () => getFirstAvailableBlockInfo(srcChainId),
    ...options,
  });
}

// -------- getAllBridgeTransactionByAddress --------

export type UseRelayerTransactionsArgs = {
  address: Address;
  paginationParams: PaginationParams;
  chainId?: number;
};

function getRelayerTransactionsQueryKey({
  address,
  paginationParams,
  chainId,
}: UseRelayerTransactionsArgs) {
  return [
    "relayerTransactions",
    address,
    chainId ?? null,
    paginationParams.page,
    paginationParams.size,
  ] as const;
}

/**
 * Fetches and enriches all bridge transactions for an address across every
 * configured relayer, merging the results. Mirrors the
 * `getAllBridgeTransactionByAddress` fan-out: one request per relayer service,
 * concatenating their `txs` and returning the last `paginationInfo`.
 */
export function useRelayerTransactions(
  args: UseRelayerTransactionsArgs,
  options?: Omit<
    UseQueryOptions<
      GetAllByAddressResponse,
      Error,
      GetAllByAddressResponse,
      ReturnType<typeof getRelayerTransactionsQueryKey>
    >,
    "queryKey" | "queryFn"
  >,
): UseQueryResult<GetAllByAddressResponse, Error> {
  return useQuery({
    queryKey: getRelayerTransactionsQueryKey(args),
    queryFn: async () => {
      const results = await Promise.all(
        relayerApiServices.map((service) =>
          service.getAllBridgeTransactionByAddress(
            args.address,
            args.paginationParams,
            args.chainId,
          ),
        ),
      );
      return results.reduce<GetAllByAddressResponse>(
        (acc, { txs, paginationInfo }) => ({
          txs: [...acc.txs, ...txs],
          paginationInfo,
        }),
        { txs: [], paginationInfo: acc0PaginationInfo() },
      );
    },
    ...options,
  });
}

function acc0PaginationInfo() {
  return {
    page: 0,
    size: 0,
    max_page: 0,
    total_pages: 0,
    total: 0,
    last: true,
    first: true,
  };
}

// -------- getBlockInfo --------

function getRelayerBlockInfoQueryKey() {
  return ["relayerBlockInfo"] as const;
}

/**
 * Fetches block info from every configured relayer and merges them into a
 * single chainID -> RelayerBlockInfo record (later relayers win on conflict).
 */
export function useRelayerBlockInfo(
  options?: Omit<
    UseQueryOptions<
      Record<number, RelayerBlockInfo>,
      Error,
      Record<number, RelayerBlockInfo>,
      ReturnType<typeof getRelayerBlockInfoQueryKey>
    >,
    "queryKey" | "queryFn"
  >,
): UseQueryResult<Record<number, RelayerBlockInfo>, Error> {
  return useQuery({
    queryKey: getRelayerBlockInfoQueryKey(),
    queryFn: async () => {
      const records = await Promise.all(
        relayerApiServices.map((service) => service.getBlockInfo()),
      );
      return records.reduce<Record<number, RelayerBlockInfo>>(
        (acc, record) => ({ ...acc, ...record }),
        {},
      );
    },
    ...options,
  });
}

// -------- recommendedProcessingFees --------

export type UseRelayerRecommendedFeesArgs = {
  typeFilter?: FeeType;
  destChainIDFilter?: number;
};

function getRelayerRecommendedFeesQueryKey({
  typeFilter,
  destChainIDFilter,
}: UseRelayerRecommendedFeesArgs) {
  return [
    "relayerRecommendedFees",
    typeFilter ?? null,
    destChainIDFilter ?? null,
  ] as const;
}

/**
 * Fetches recommended processing fees from every configured relayer and merges
 * the filtered results into a single list.
 */
export function useRelayerRecommendedFees(
  args: UseRelayerRecommendedFeesArgs = {},
  options?: Omit<
    UseQueryOptions<
      Fee[],
      Error,
      Fee[],
      ReturnType<typeof getRelayerRecommendedFeesQueryKey>
    >,
    "queryKey" | "queryFn"
  >,
): UseQueryResult<Fee[], Error> {
  return useQuery({
    queryKey: getRelayerRecommendedFeesQueryKey(args),
    queryFn: async () => {
      const feeLists = await Promise.all(
        relayerApiServices.map((service) =>
          service.recommendedProcessingFees(args),
        ),
      );
      return feeLists.flat();
    },
    ...options,
  });
}
