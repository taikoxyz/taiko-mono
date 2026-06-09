"use client";

import { useQuery, type UseQueryOptions } from "@tanstack/react-query";
import type { Address } from "viem";

import type { ChainID } from "$libs/chain";

import type { EventIndexerAPIService } from "./EventIndexerAPIService";
import { eventIndexerApiServices } from "./initEventIndexer";
import type { EventIndexerAPIResponse, PaginationParams } from "./types";

/**
 * Resolve the configured EventIndexer service for a given chain id.
 *
 * The underlying `eventIndexerApiServices` array is built from `$eventIndexerConfig`
 * (one service per `url`); the config retains the `chainIds` array so callers can
 * pick the right indexer. We match by service index against the configured list.
 *
 * NOTE: the original SvelteKit app instantiated services purely from `url` and did
 * not expose a chain->service lookup; consumers (e.g. bridge/fetchNFTs.ts) selected
 * the service externally. We keep that behavior: by default the hook uses the first
 * configured service unless an explicit `service` is provided.
 */

export type UseEventIndexerNftsParams = {
  address: Address | undefined;
  chainID: ChainID | undefined;
  paginationParams: PaginationParams;
  /** Explicit service override; defaults to the first configured EventIndexer service. */
  service?: EventIndexerAPIService;
};

/**
 * React Query wrapper around `EventIndexerAPIService.getAllNftsByAddressFromAPI`.
 * The underlying async fetcher is unchanged; this only adds caching/dedup.
 *
 * Query key serializes the bigint `chainID` to a string to keep keys hashable.
 */
export function useEventIndexerNfts(
  { address, chainID, paginationParams, service }: UseEventIndexerNftsParams,
  options?: Partial<UseQueryOptions<EventIndexerAPIResponse, Error>>,
) {
  const indexer = service ?? eventIndexerApiServices[0];

  return useQuery<EventIndexerAPIResponse, Error>({
    queryKey: [
      "eventIndexerNfts",
      chainID !== undefined ? chainID.toString() : null,
      address ?? null,
      paginationParams.page,
      paginationParams.size,
    ],
    queryFn: () => {
      if (!indexer) throw new Error("no configured EventIndexer service");
      if (!address || chainID === undefined)
        throw new Error("address and chainID are required");
      return indexer.getAllNftsByAddressFromAPI(
        address,
        chainID,
        paginationParams,
      );
    },
    enabled:
      Boolean(indexer) &&
      Boolean(address) &&
      chainID !== undefined &&
      (options?.enabled ?? true),
    ...options,
  });
}
