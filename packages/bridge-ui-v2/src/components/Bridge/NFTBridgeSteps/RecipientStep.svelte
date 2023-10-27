<script lang="ts">
  import { ProcessingFee } from '../ProcessingFee';
  import Recipient from '../Recipient.svelte';

  let recipientComponent: Recipient;
  let processingFeeComponent: ProcessingFee;
  export let hasEnoughEth: boolean = false;

  export const reset = () => {
    recipientComponent.clearRecipient();
    processingFeeComponent.resetProcessingFee();
  };
</script>

<Recipient bind:this={recipientComponent} />
<ProcessingFee bind:this={processingFeeComponent} bind:hasEnoughEth />

<div class="h-sep" />
