<script lang="ts">
  import { _ } from "svelte-i18n";
  import { processingFee } from "../../store/fee";
  import { ProcessingFeeMethod, PROCESSING_FEE_META } from "../../domain/fee";
  import { toChain, fromChain } from "../../store/chain";
  import { token } from "../../store/token";
  import { signer } from "../../store/signer";
  import { recommendProcessingFee } from "../../utils/recommendProcessingFee";
  import Tooltip from "../Tooltip.svelte";
  import TooltipModal from "../modals/TooltipModal.svelte";

  export let customFee: string;
  export let recommendedFee: string = "0";

  let tooltipOpen: boolean = false;

  $: recommendProcessingFee(
    $toChain,
    $fromChain,
    $processingFee,
    $token,
    $signer
  )
    .then((fee) => (recommendedFee = fee))
    .catch((e) => console.error(e));

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
    <div class="flex items-left justify-between">
      <span class="mt-2 text-sm">{recommendedFee} ETH </span>
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
