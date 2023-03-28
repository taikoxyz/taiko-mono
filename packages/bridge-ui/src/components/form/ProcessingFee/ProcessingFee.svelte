<script lang="ts">
  import { _ } from 'svelte-i18n';
  import { ProcessingFeeMethod } from '../../../domain/fee';
  import { toChain, fromChain } from '../../../store/chain';
  import { token } from '../../../store/token';
  import { signer } from '../../../store/signer';
  import { recommendProcessingFee } from '../../../utils/recommendProcessingFee';
  import ButtonWithTooltip from '../../ButtonWithTooltip.svelte';
  import { processingFees } from '../../../fee/processingFees';
  import GeneralTooltip from './ProcessingFeeTooltip.svelte';
  import OptInOutTooltip from '../../../components/OptInOutTooltip.svelte';

  export let method: ProcessingFeeMethod = ProcessingFeeMethod.RECOMMENDED;
  export let amount: string = '0';

  let showProcessingFeeTooltip: boolean = false;
  let showNoneFeeTooltip: boolean = false;

  $: recommendProcessingFee($toChain, $fromChain, method, $token, $signer)
    .then((recommendedFee) => (amount = recommendedFee))
    .catch((e) => console.error(e));

  function updateAmount(event: Event) {
    const target = event.target as HTMLInputElement;
    amount = target.value.toString();
  }

  function focus(input: HTMLInputElement) {
    input.select();
  }

  function selectFee(selectedMethod: ProcessingFeeMethod) {
    return () => {
      method = selectedMethod;
      if (selectedMethod === ProcessingFeeMethod.NONE) {
        showNoneFeeTooltip = true;
      }
    };
  }
</script>

<div class="my-10">
  <div class="flex flex-row justify-between">
    <ButtonWithTooltip onClick={() => (showProcessingFeeTooltip = true)}>
      <span slot="buttonText">{$_('bridgeForm.processingFeeLabel')}</span>
    </ButtonWithTooltip>
  </div>

  <!-- 
    TODO: how about showing recommended also in a readonly input
          and when clicking on Custom it becomes editable?
    
    TODO: transition between options
   -->
  {#if method === ProcessingFeeMethod.CUSTOM}
    <label class="mt-2 input-group relative">
      <input
        use:focus
        type="number"
        step="0.01"
        placeholder="0.01"
        min="0"
        on:input={updateAmount}
        class="input input-primary bg-dark-2 border-dark-2 input-md md:input-lg w-full focus:ring-0 !rounded-r-none"
        name="amount" />
      <span class="!rounded-r-lg bg-dark-2">ETH</span>
    </label>
  {:else if method === ProcessingFeeMethod.RECOMMENDED}
    <div class="flex flex-row">
      <span class="mt-2 text-sm">{amount} ETH</span>
    </div>
  {/if}

  <div class="flex mt-2 space-x-2">
    {#each Array.from(processingFees) as fee}
      {@const [feeMethod, { displayText }] = fee}
      {@const selected = method === feeMethod}

      <button
        class="{selected
          ? 'border-accent hover:border-accent'
          : ''} btn btn-md text-xs font-semibold md:w-32 dark:bg-dark-5"
        on:click={selectFee(feeMethod)}>{displayText}</button>
    {/each}
  </div>
</div>

<GeneralTooltip bind:show={showProcessingFeeTooltip} />

<OptInOutTooltip bind:show={showNoneFeeTooltip} name="NoneFeeTooltip">
  <!-- TODO: translations? -->
  <div class="text-center">
    Selecting <strong>None</strong> means that you'll require ETH on the receiving
    chain in otder to claim the bridged token. Pleas, come back later to manually
    claim.
  </div>
</OptInOutTooltip>

<style>
  /* hide number input arrows */
  input[type='number']::-webkit-outer-spin-button,
  input[type='number']::-webkit-inner-spin-button {
    -webkit-appearance: none;
    margin: 0;
    -moz-appearance: textfield !important;
  }
</style>
