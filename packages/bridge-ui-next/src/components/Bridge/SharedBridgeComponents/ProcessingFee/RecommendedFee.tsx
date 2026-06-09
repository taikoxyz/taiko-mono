"use client";

import { useEffect, useRef } from "react";
import type { Address } from "viem";

import {
  calculatingProcessingFee,
  destNetwork,
  enteredAmount,
  recipientAddress,
  selectedNFTs,
  selectedToken,
  useBridgeState,
} from "@/components/Bridge/state";
import { processingFeeComponent } from "$config";
import { recommendProcessingFee } from "@/libs/fee";
import { type NFT, type Token, TokenType } from "@/libs/token";
import { useAccount, useConnectedSourceChain } from "@/stores";

export interface RecommendedFeeProps {
  /** `bind:amount` write-back. */
  onAmountChange?: (amount: bigint) => void;
  /** `bind:error` write-back. */
  onErrorChange?: (error: boolean) => void;
}

/**
 * Headless side-effect component (the original Svelte file has an empty
 * template). Computes the recommended processing fee whenever the bridge form
 * inputs change and on a fixed interval, writing the result back through
 * `onAmountChange`/`onErrorChange` and toggling the shared
 * `calculatingProcessingFee` store.
 */
export default function RecommendedFee({
  onAmountChange,
  onErrorChange,
}: RecommendedFeeProps) {
  const $selectedToken = useBridgeState(selectedToken);
  const $destNetwork = useBridgeState(destNetwork);
  const $enteredAmount = useBridgeState(enteredAmount);
  const $recipientAddress = useBridgeState(recipientAddress);
  const $selectedNFTs = useBridgeState(selectedNFTs);
  const $account = useAccount((s) => s);
  const $connectedSourceChain = useConnectedSourceChain();

  const onAmountChangeRef = useRef(onAmountChange);
  const onErrorChangeRef = useRef(onErrorChange);
  useEffect(() => {
    onAmountChangeRef.current = onAmountChange;
    onErrorChangeRef.current = onErrorChange;
  });

  // Latest store-derived inputs in a ref so the interval callback uses fresh
  // values without re-creating the interval (mirrors the Svelte onMount closure
  // reading the reactive locals each tick).
  const computeArgsRef = useRef<{
    token: Maybe<Token | NFT>;
    srcChainId?: number;
    destChainId?: number;
    to?: Address;
    tokenIds?: number[];
    amounts?: number[];
  }>({ token: null });

  async function compute(
    token: Maybe<Token | NFT>,
    srcChainId?: number,
    destChainId?: number,
    to?: Address,
    tokenIds?: number[],
    amounts?: number[],
  ) {
    // Without token nor destination chain we cannot compute this fee
    if (!token || !destChainId) return;

    calculatingProcessingFee.setState(() => true, true);
    onErrorChangeRef.current?.(false);

    try {
      const amount = await recommendProcessingFee({
        token,
        destChainId,
        srcChainId,
        to,
        tokenIds,
        amounts,
      });
      onAmountChangeRef.current?.(amount);
    } catch (err) {
      console.error(err);
      onErrorChangeRef.current?.(true);
    } finally {
      calculatingProcessingFee.setState(() => false, true);
    }
  }

  const to = $recipientAddress || $account?.address;
  const tokenIds = $selectedNFTs?.map((nft) => nft.tokenId);
  const amounts =
    $selectedToken?.type === TokenType.ERC1155
      ? [Number($enteredAmount)]
      : undefined;

  // Keep latest args available to the interval tick (committed after render so
  // the ref is never written during render).
  useEffect(() => {
    computeArgsRef.current = {
      token: $selectedToken,
      srcChainId: $connectedSourceChain?.id,
      destChainId: $destNetwork?.id,
      to,
      tokenIds,
      amounts,
    };
  });

  // $: compute(...)
  useEffect(() => {
    compute(
      $selectedToken,
      $connectedSourceChain?.id,
      $destNetwork?.id,
      to,
      tokenIds,
      amounts,
    );
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    $selectedToken,
    $connectedSourceChain?.id,
    $destNetwork?.id,
    $recipientAddress,
    $account?.address,
    $selectedNFTs,
    $enteredAmount,
  ]);

  // onMount: setInterval(...) ; onDestroy: clearInterval(...)
  useEffect(() => {
    const interval = setInterval(() => {
      const args = computeArgsRef.current;
      compute(
        args.token,
        args.srcChainId,
        args.destChainId,
        args.to,
        args.tokenIds,
        args.amounts,
      );
    }, processingFeeComponent.intervalComputeRecommendedFee);

    return () => clearInterval(interval);
  }, []);

  return null;
}
