"use client";

import { QueryClient } from "@tanstack/react-query";

/**
 * Shared singleton QueryClient.
 *
 * Library (non-React) callers use this directly for imperative cache access
 * (getQueryData / setQueryData / invalidateQueries) — e.g. the balance refresh
 * and token-info caches described in the state migration plan.
 *
 * A module-level singleton (not per-render) so server-derived state survives
 * Fast Refresh and is reachable from outside the React tree.
 */
export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      // The original app is wallet/chain driven; avoid aggressive refetching.
      refetchOnWindowFocus: false,
      retry: 1,
      staleTime: 30_000,
      // Keep unused query data in cache for 5 minutes so navigating between the
      // bridge/transactions/faucet routes (and remounting wallet-driven views)
      // reuses recent on-chain reads instead of immediately re-fetching. Purely
      // additive caching — does not change when data is considered fresh.
      gcTime: 5 * 60_000,
    },
  },
});
