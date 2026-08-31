<script lang="ts">
  import { onDestroy, onMount } from 'svelte';
  import type { Address } from 'viem';

  import {
    calculatingProcessingFee,
    destNetwork,
    enteredAmount,
    recipientAddress,
    selectedNFTs,
    selectedToken,
  } from '$components/Bridge/state';
  import { processingFeeComponent } from '$config';
  import { recommendProcessingFee } from '$libs/fee';
  import { type NFT, type Token, TokenType } from '$libs/token';
  import { account } from '$stores';
  import { connectedSourceChain } from '$stores/network';

  export let amount: bigint;
  export let error = false;

  let interval: ReturnType<typeof setInterval>;

  // Concurrent computations can resolve out of order (reactive re-runs and the refresh
  // interval overlap); only the latest invocation may publish its result
  let computeGeneration = 0;

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

    const generation = ++computeGeneration;
    $calculatingProcessingFee = true;
    error = false;

    try {
      const recommended = await recommendProcessingFee({
        token,
        destChainId,
        srcChainId,
        to,
        tokenIds,
        amounts,
      });
      if (generation !== computeGeneration) return;
      amount = recommended;
    } catch (err) {
      if (generation !== computeGeneration) return;
      console.error(err);
      error = true;
    } finally {
      if (generation === computeGeneration) {
        $calculatingProcessingFee = false;
      }
    }
  }

  $: compute(
    $selectedToken,
    $connectedSourceChain?.id,
    $destNetwork?.id,
    $recipientAddress || $account?.address,
    $selectedNFTs?.map((nft) => nft.tokenId),
    $selectedToken?.type === TokenType.ERC1155 ? [Number($enteredAmount)] : undefined,
  );

  onMount(() => {
    interval = setInterval(() => {
      compute(
        $selectedToken,
        $connectedSourceChain?.id,
        $destNetwork?.id,
        $recipientAddress || $account?.address,
        $selectedNFTs?.map((nft) => nft.tokenId),
        $selectedToken?.type === TokenType.ERC1155 ? [Number($enteredAmount)] : undefined,
      );
    }, processingFeeComponent.intervalComputeRecommendedFee);
  });

  onDestroy(() => {
    clearInterval(interval);
  });
</script>
