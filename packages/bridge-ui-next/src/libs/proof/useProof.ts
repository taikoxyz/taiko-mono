"use client";

import {
  useMutation,
  useQuery,
  type UseMutationResult,
  type UseQueryResult,
} from "@tanstack/react-query";
import type { Hex } from "viem";

import type { BridgeTransaction } from "$libs/bridge";

import { BridgeProver } from "./BridgeProver";

/**
 * TanStack React Query wrappers around {@link BridgeProver}.
 *
 * The underlying async methods on BridgeProver are intentionally left untouched so
 * that any caller (React or non-React) can keep using `new BridgeProver()` directly.
 * These hooks merely give the React layer caching/dedupe + loading/error state.
 */

const prover = new BridgeProver();

/**
 * Deterministic query key for a bridge transaction's proof.
 * bigints are stringified so the key is serializable (devtools/persistence safe).
 */
function proofQueryKey(
  kind: "signal" | "recall",
  bridgeTx: BridgeTransaction | undefined,
) {
  const message = bridgeTx?.message;
  return [
    "proof",
    kind,
    message?.srcChainId?.toString(),
    message?.destChainId?.toString(),
    bridgeTx?.msgHash,
    bridgeTx?.blockNumber,
  ] as const;
}

/**
 * Generates the encoded signal proof used to claim/process a message on the destination chain.
 *
 * Proof generation involves read-only on-chain reads (eth_getProof, getBlock, readContract),
 * so it maps to a query. Disabled until a bridgeTx is provided (and can be further gated by
 * the caller via `enabled`).
 */
export function useEncodedSignalProof(
  bridgeTx: BridgeTransaction | undefined,
  options?: { enabled?: boolean },
): UseQueryResult<Hex, Error> {
  return useQuery({
    queryKey: proofQueryKey("signal", bridgeTx),
    queryFn: () =>
      prover.getEncodedSignalProof({ bridgeTx: bridgeTx as BridgeTransaction }),
    enabled: (options?.enabled ?? true) && Boolean(bridgeTx),
    // Proofs are deterministic for a synced block; avoid refetching aggressively.
    staleTime: Infinity,
    retry: false,
  });
}

/**
 * Generates the encoded signal proof used to release/recall a failed message on the source chain.
 */
export function useEncodedSignalProofForRecall(
  bridgeTx: BridgeTransaction | undefined,
  options?: { enabled?: boolean },
): UseQueryResult<Hex, Error> {
  return useQuery({
    queryKey: proofQueryKey("recall", bridgeTx),
    queryFn: () =>
      prover.getEncodedSignalProofForRecall({
        bridgeTx: bridgeTx as BridgeTransaction,
      }),
    enabled: (options?.enabled ?? true) && Boolean(bridgeTx),
    staleTime: Infinity,
    retry: false,
  });
}

/**
 * On-demand variant: generate the encoded signal proof imperatively (e.g. when the user
 * clicks "Claim"). Use `mutateAsync` to await the encoded proof inline in a submit handler.
 */
export function useGenerateEncodedSignalProof(): UseMutationResult<
  Hex,
  Error,
  { bridgeTx: BridgeTransaction }
> {
  return useMutation({
    mutationFn: ({ bridgeTx }) => prover.getEncodedSignalProof({ bridgeTx }),
  });
}

/**
 * On-demand variant for recall/release proofs (e.g. when the user clicks "Release").
 */
export function useGenerateEncodedSignalProofForRecall(): UseMutationResult<
  Hex,
  Error,
  { bridgeTx: BridgeTransaction }
> {
  return useMutation({
    mutationFn: ({ bridgeTx }) =>
      prover.getEncodedSignalProofForRecall({ bridgeTx }),
  });
}
