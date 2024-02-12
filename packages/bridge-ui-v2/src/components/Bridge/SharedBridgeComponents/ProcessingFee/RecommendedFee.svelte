<script lang="ts">
  import { onDestroy, onMount } from 'svelte';

  import { destNetwork, selectedToken } from '$components/Bridge/state';
  import { processingFeeComponent } from '$config';
  import { recommendProcessingFee } from '$libs/fee';
  import type { Token } from '$libs/token';
  import { connectedSourceChain } from '$stores/network';

  export let amount: bigint;
  export let calculating = false;
  export let error = false;

  let interval: ReturnType<typeof setInterval>;

  async function compute(token: Maybe<Token>, srcChainId?: number, destChainId?: number) {
    // Without token nor destination chain we cannot compute this fee
    if (!token || !destChainId) return;

    calculating = true;
    error = false;

    try {
      amount = await recommendProcessingFee({
        token,
        destChainId,
        srcChainId,
      });
    } catch (err) {
      console.error(err);
      error = true;
    } finally {
      calculating = false;
    }
  }

  $: compute($selectedToken, $connectedSourceChain?.id, $destNetwork?.id);

  onMount(() => {
    interval = setInterval(() => {
      compute($selectedToken, $connectedSourceChain?.id, $destNetwork?.id);
    }, processingFeeComponent.intervalComputeRecommendedFee);
  });

  onDestroy(() => {
    clearInterval(interval);
  });
</script>
