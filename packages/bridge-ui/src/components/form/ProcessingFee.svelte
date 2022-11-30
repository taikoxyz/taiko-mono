<script>
  import { processingFee, processingFeeDetails, currentSelectedProcessingFee } from '../../store/fee';;

  function selectProcessingFee (fee) {
    $processingFee = fee;
  }
</script>
<div class="mt-10">
  <h4 class="text-sm font-medium text-left mb-4">Processing Fees</h4>
  <div class="flex items-center justify-between">

    {#each Array.from($processingFeeDetails) as fee}
      <button class="{$processingFee === fee[0] ? 'border-accent' : ''} btn btn-md" on:click={() => selectProcessingFee(fee[0])}>{fee[1].displayText}</button>
    {/each}
  </div>
</div>