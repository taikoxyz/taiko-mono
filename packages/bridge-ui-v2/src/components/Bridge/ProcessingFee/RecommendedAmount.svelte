<script lang="ts">
  import { recommendProcessingFee } from '$libs/fee';
  import type { Token } from '$libs/token';
  import { onMount } from 'svelte';
  import { network } from '$stores/network';
  import { selectedToken, destNetwork } from '../state';

  export let value: bigint;
  export let calculating = false;
  export let error = false;

  async function compute(token: Token, srcChainId?: number, destChainId?: number) {
    calculating = true;
    error = false;

    try {
      value = await recommendProcessingFee({
        token,
        destChainId,
        srcChainId,
      });
    } catch (error) {
      console.error(error);
      error = true;
    } finally {
      calculating = false;
    }
  }

  $: compute($selectedToken, $network?.id, $destNetwork?.id);
</script>
