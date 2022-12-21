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
  <div class="flex flex-row justify-between">
    <span class="text-left label-text">
      {$_("bridgeForm.processingFeeLabel")}
      <span class="inline-block" on:click={() => (tooltipOpen = true)}>
        <Tooltip />
      </span>
    </span>
  </div>

  {#if $processingFee === ProcessingFeeMethod.CUSTOM}
    <label class="mt-2 input-group relative">
      <input
        type="number"
        step="0.01"
        placeholder="0.01"
        min="0"
        on:input={updateAmount}
        class="input input-primary bg-dark-4 input-md md:input-lg w-full focus:ring-0 !rounded-r-none"
        name="amount"
      />
      <span class="!rounded-r-lg bg-dark-4">ETH</span>
    </label>
  {:else if $processingFee === ProcessingFeeMethod.RECOMMENDED}
    <div class="flex flex-row">
      <span class="mt-2 text-sm">0.01 ETH</span>
    </div>
  {/if}

  <div class="flex mt-2 space-x-2">
    {#each Array.from(PROCESSING_FEE_META) as fee}
      <button
        class="{$processingFee === fee[0]
          ? 'border-accent hover:border-accent'
          : ''} btn btn-sm"
        on:click={() => selectProcessingFee(fee[0])}
        >{fee[1].displayText}</button
      >
    {/each}
  </div>
</div>

<TooltipModal title="Processing Fees" bind:isOpen={tooltipOpen}>
  <span slot="body">
<<<<<<< HEAD
    <p>
      Processing Fees are the amount you pay to have your bridge message
      processed on the destination chain.
      <br /> Use the recommended fee to have a relayer pick it up as soon as they
      can, use a custom fee if you okay with waiting, or no fee if you want to come
      back here and claim it yourself.
    </p>
  </span>
</TooltipModal>
=======
    <div class="text-left">
      The amount you pay the relayer to process your bridge message on the
      destination chain.
      <br /><br />
      <ul class="list-disc ml-4">
        <li>
          <strong>Recommended</strong>: The recommended fee is the lowest fee
          that will get your transaction processed in a reasonable amount of
          time.
        </li>
        <li>
          <strong>Custom</strong>: You can set a custom fee if you want to pay
          less (and wait).
        </li>
        <li>
          <strong>None</strong>: You can select no fee if you want to come back
          here and claim the bridged asset yourself.
        </li>
      </ul>
    </div>
  </span>
</TooltipModal>

<style>
  /* hide number input arrows */
  input[type="number"]::-webkit-outer-spin-button,
  input[type="number"]::-webkit-inner-spin-button {
    -webkit-appearance: none;
    margin: 0;
    -moz-appearance: textfield !important;
  }
</style>
>>>>>>> b90d041172378d710d794d0cd6a576accbdec13e
