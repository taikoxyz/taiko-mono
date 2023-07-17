<script lang="ts">
  import { recommendProcessingFee } from '$libs/fee';
  import type { Token } from '$libs/token';
  import { network } from '$stores/network';
  import { onDestroy, onMount } from 'svelte';

  import { destNetwork, selectedToken } from '../state';
  import { processingFeeComponent } from '$config';

  export let amount: bigint;
  export let calculating = false;
  export let error = false;

  let interval: ReturnType<typeof setInterval>;

  async function compute(token: Maybe<Token>, srcChainId?: number, destChainId?: number) {
    if (!token) return;

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

  $: compute($selectedToken, $network?.id, $destNetwork?.id);

  onMount(() => {
    interval = setInterval(() => {
      compute($selectedToken, $network?.id, $destNetwork?.id);
    }, processingFeeComponent.intervalComputeRecommendedFee);
  });

  onDestroy(() => {
    clearInterval(interval);
  });
</script>
