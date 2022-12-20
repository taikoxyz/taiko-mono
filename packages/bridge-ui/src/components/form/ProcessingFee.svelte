<script lang="ts">
  import { _ } from "svelte-i18n";
  import { processingFee } from "../../store/fee";
  import { ProcessingFeeMethod, PROCESSING_FEE_META } from "../../domain/fee";
  import TooltipModal from "../modals/TooltipModal.svelte";
  import Tooltip from "../Tooltip.svelte";

  export let customFee: string;
  let tooltipOpen: boolean = false;

  function selectProcessingFee(fee) {
    $processingFee = fee;
  }

  function updateAmount(e: any) {
    customFee = (e.target.value as number).toString();
  }
</script>

<div class="my-10 w-full">
  <h4 class="text-sm font-medium text-left mb-4">
    {$_("bridgeForm.processingFeeLabel")}
    <span class="inline-block" on:click={() => (tooltipOpen = true)}>
      <Tooltip />
    </span>
  </h4>
  <div class="flex items-center justify-around">
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
    <label class="mt-2 input-group relative">
      <input
        type="number"
        step="0.01"
        placeholder="0.01"
        min="0"
        on:input={updateAmount}
        class="input input-primary md:input-lg flex-1 rounded-l-lg !rounded-r-none bg-dark-4"
        name="amount"
      />
      <span class="!rounded-r-lg bg-dark-4">ETH</span>
    </label>
  {:else if $processingFee === ProcessingFeeMethod.RECOMMENDED}
    <div class="flex items-left justify-between">
      <span class="mt-2 text-sm">0.01 ETH </span>
    </div>
  {/if}
</div>

<TooltipModal title="Processing Fees" bind:isOpen={tooltipOpen}>
  <span slot="body">
    <p>
      Processing Fees are the amount you pay to have your bridge message
      processed on the destination chain.
      <br /> Use the recommended fee to have a relayer pick it up as soon as they
      can, use a custom fee if you okay with waiting, or no fee if you want to come
      back here and claim it yourself.
    </p>
  </span>
</TooltipModal>
