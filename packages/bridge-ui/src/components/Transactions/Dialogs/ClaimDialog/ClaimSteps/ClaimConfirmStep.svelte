<script lang="ts">
  import { createEventDispatcher } from 'svelte';

  import type { BridgeTransaction } from '$libs/bridge';
  import { getInvoationDelayForTx } from '$libs/bridge/getInvocationDelayForTx';

  export let tx: BridgeTransaction;

  const dispatch = createEventDispatcher();

  const handleClaimClick = async () => {
    dispatch('claim');
  };
</script>

<h1>Confirm! TODO</h1>
<button class="btn" on:click={() => handleClaimClick()}>Test claim</button>
<button class="btn" on:click={() => getInvoationDelayForTx(tx)}>Get delays</button>
