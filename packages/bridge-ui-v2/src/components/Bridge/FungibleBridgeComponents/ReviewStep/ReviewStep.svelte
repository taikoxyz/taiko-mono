<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';
  import { formatUnits } from 'viem';

  import { ProcessingFee, Recipient } from '$components/Bridge/SharedBridgeComponents';
  import { destNetwork as destChain, enteredAmount, selectedToken } from '$components/Bridge/state';
  import { network } from '$stores/network';

  export let hasEnoughEth: boolean = false;

  let recipientComponent: Recipient;
  let processingFeeComponent: ProcessingFee;

  $: renderedDisplay = ($selectedToken && formatUnits($enteredAmount, $selectedToken.decimals)) || 0;

  const dispatch = createEventDispatcher();

  const editTransactionDetails = () => {
    dispatch('editTransactionDetails');
  };

  const goBack = () => {
    dispatch('goBack');
  };
</script>

<div class="container mx-auto inline-block align-middle space-y-[25px] w-full">
  <div class="flex justify-between items-center">
    <div class="font-bold text-primary-content">{$t('bridge.nft.step.review.transfer_details')}</div>
    <span role="button" tabindex="0" class="link" on:keydown={goBack} on:click={goBack}>{$t('common.edit')}</span>
  </div>
  <div class="!mt-[10px]">
    <div class="flex justify-between items-center">
      <div class="text-secondary-content">{$t('common.from')}</div>
      <div class="">{$network?.name}</div>
    </div>
    <div class="flex justify-between items-center">
      <div class="text-secondary-content">{$t('common.to')}</div>
      <div class="">{$destChain?.name}</div>
    </div>
    <div class="flex justify-between items-center">
      <div class="text-secondary-content">{$t('common.amount')}</div>
      <div class="">{renderedDisplay}</div>
    </div>

    <div class="flex justify-between items-center">
      <div class="text-secondary-content">{$t('common.name')}</div>
      <div class="">{$selectedToken?.symbol}</div>
    </div>
  </div>
</div>

<div class="h-sep" />
<!-- 
Recipient & Processing Fee
-->
<div class="f-col">
  <div class="f-between-center mb-[10px]">
    <div class="font-bold text-primary-content">{$t('bridge.nft.step.review.recipient_details')}</div>
    <button class="flex justify-start link" on:click={editTransactionDetails}> {$t('common.edit')} </button>
  </div>
  <Recipient bind:this={recipientComponent} small />
  <ProcessingFee bind:this={processingFeeComponent} small bind:hasEnoughEth />
</div>

<div class="h-sep" />
