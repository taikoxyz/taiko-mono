<script lang="ts">
  import { _ } from "svelte-i18n";
  import { processingFee } from "../../store/fee";
  import { ProcessingFeeMethod, PROCESSING_FEE_META } from "../../domain/fee";

  export let customFee: string;

  function selectProcessingFee(fee) {
    $processingFee = fee;
  }

  function updateAmount(e: any) {
    customFee = (e.data as number).toString();
  }
</script>

<div class="my-10">
  <h4 class="text-sm font-medium text-left mb-4">
    {$_("bridgeForm.processingFeeLabel")}
  </h4>
  <div class="flex items-center justify-around px-8 py-4">
    {#each Array.from(PROCESSING_FEE_META) as fee}
      <button
        class="{$processingFee === fee[0]
          ? 'border-accent hover:border-accent'
          : ''} btn btn-sm md:btn-md"
        on:click={() => selectProcessingFee(fee[0])}
        >{fee[1].displayText}</button
      >
    {/each}
  </div>

  {#if $processingFee === ProcessingFeeMethod.CUSTOM}
    <label
      class="mt-2 input-group relative rounded-lg bg-dark-4 justify-between items-center pr-4"
    >
      <input
        type="number"
        step="0.01"
        placeholder="0.01"
        min="0"
        on:input={updateAmount}
        class="input input-primary bg-dark-4 input-lg flex-1"
        name="amount"
      />
    </label>
  {:else if $processingFee === ProcessingFeeMethod.RECOMMENDED}
    <div class="flex items-left justify-between">
      <span class="mt-2 text-sm">0.01 ETH </span>
    </div>
  {/if}
</div>
