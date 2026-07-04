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

    $calculatingProcessingFee = true;
    error = false;

    try {
      amount = await recommendProcessingFee({
        token,
        destChainId,
        srcChainId,
        to,
        tokenIds,
        amounts,
      });
    } catch (err) {
      console.error(err);
      error = true;
    } finally {
      $calculatingProcessingFee = false;
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
