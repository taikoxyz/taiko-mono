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

<div class="mt-[30px] space-y-[16px]">
  <Recipient bind:this={recipientComponent} />
  <ProcessingFee bind:this={processingFeeComponent} bind:hasEnoughEth />
</div>
<div class="h-sep my-[30px]" />
