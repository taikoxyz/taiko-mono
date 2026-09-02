<script lang="ts" context="module">
  /**
   * Instances with a fee read in flight. `$calculatingProcessingFee` is one store shared by
   * every instance, and the fungible wizard mounts a fresh instance on each step, so the
   * flag has to follow all of them: with each instance clearing it on its own schedule, an
   * instance destroyed by a step change still cleared the flag when its read came back,
   * while the next step's instance was computing - and that step's Continue came alive on
   * a 0 ETH placeholder fee.
   */
  const computing = new Set<symbol>();
</script>

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
  let inFlight = false;

  const instance = Symbol('RecommendedFee');

  /** @dev Raises the shared flag on this instance's behalf. */
  const startComputing = () => {
    computing.add(instance);
    $calculatingProcessingFee = true;
  };

  /** @dev Withdraws this instance; the flag stays up while any other instance is still computing. */
  const stopComputing = () => {
    computing.delete(instance);
    $calculatingProcessingFee = computing.size > 0;
  };

  async function compute(
    token: Maybe<Token | NFT>,
    srcChainId?: number,
    destChainId?: number,
    to?: Address,
    tokenIds?: number[],
    amounts?: bigint[],
    periodicRefresh = false,
  ) {
    // A periodic refresh re-runs identical inputs, so it must not supersede a slower
    // in-flight computation — doing so would discard every result and never clear the
    // calculating flag; only input changes may take over
    if (periodicRefresh && inFlight) return;

    const generation = ++computeGeneration;

    // Without token nor destination chain we cannot compute this fee. The bump above
    // stops an in-flight result for the old inputs from publishing, so the flags it
    // can no longer clear are reset here
    if (!token || !destChainId) {
      stopComputing();
      inFlight = false;
      return;
    }

    inFlight = true;
    startComputing();
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
        stopComputing();
        inFlight = false;
      }
    }
  }

  $: compute(
    $selectedToken,
    $connectedSourceChain?.id,
    $destNetwork?.id,
    $recipientAddress || $account?.address,
    $selectedNFTs?.map((nft) => nft.tokenId),
    $selectedToken?.type === TokenType.ERC1155 ? [$enteredAmount] : undefined,
  );

  onMount(() => {
    interval = setInterval(() => {
      compute(
        $selectedToken,
        $connectedSourceChain?.id,
        $destNetwork?.id,
        $recipientAddress || $account?.address,
        $selectedNFTs?.map((nft) => nft.tokenId),
        $selectedToken?.type === TokenType.ERC1155 ? [$enteredAmount] : undefined,
        true,
      );
    }, processingFeeComponent.intervalComputeRecommendedFee);
  });

  onDestroy(() => {
    clearInterval(interval);
    // Nothing will show this instance's result any more, so it must not keep the flag up
    // either; the late read finds the instance withdrawn and leaves the flag alone
    stopComputing();
  });
</script>
