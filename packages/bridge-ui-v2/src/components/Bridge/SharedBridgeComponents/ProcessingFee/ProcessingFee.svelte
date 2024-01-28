<script lang="ts">
  import { tick } from 'svelte';
  import { t } from 'svelte-i18n';
  import { formatEther } from 'viem';

  import FlatAlert from '$components/Alert/FlatAlert.svelte';
  import { processingFee, processingFeeMethod } from '$components/Bridge/state';
  import { ActionButton, CloseButton } from '$components/Button';
  import { InputBox } from '$components/InputBox';
  import { LoadingText } from '$components/LoadingText';
  import { Tooltip } from '$components/Tooltip';
  import { closeOnEscapeOrOutsideClick } from '$libs/customActions';
  import { ProcessingFeeMethod } from '$libs/fee';
  import { parseToWei } from '$libs/util/parseToWei';
  import { uid } from '$libs/util/uid';

  import NoneOption from './NoneOption.svelte';
  import RecommendedFee from './RecommendedFee.svelte';

  export let small = false;
  export let textOnly = false;
  export let hasEnoughEth = false;
  export let disabled = false;

  let dialogId = `dialog-${uid()}`;
  let prevOptionSelected = ProcessingFeeMethod.RECOMMENDED;

  let recommendedAmount = BigInt(0);
  let calculatingRecommendedAmount = false;
  let errorCalculatingRecommendedAmount = false;

  let calculatingEnoughEth = false;
  let errorCalculatingEnoughEth = false;

  let modalOpen = false;
  let inputBox: InputBox | undefined;

  // Public API
  export function resetProcessingFee() {
    inputBox?.clear();
    $processingFeeMethod = ProcessingFeeMethod.RECOMMENDED;
  }

  function closeModal() {
    // Let's check if we are closing with CUSTOM method selected and zero amount entered
    if ($processingFeeMethod === ProcessingFeeMethod.CUSTOM && $processingFee === BigInt(0)) {
      // If so, let's switch to RECOMMENDED method
      $processingFeeMethod = ProcessingFeeMethod.RECOMMENDED;
    }
    modalOpen = false;
  }

  function openModal() {
    // Keep track of the selected method before opening the modal
    // so if we cancel we can go back to the previous method
    prevOptionSelected = $processingFeeMethod;
    modalOpen = true;
  }

  function cancelModal() {
    inputBox?.clear();
    $processingFeeMethod = prevOptionSelected;
    closeModal();
  }

  function focusInputBox() {
    inputBox?.focus();
  }

  function inputProcessFee(event: Event) {
    if ($processingFeeMethod !== ProcessingFeeMethod.CUSTOM) return;

    const { value } = event.target as HTMLInputElement;
    $processingFee = parseToWei(value);
  }

  async function updateProcessingFee(method: ProcessingFeeMethod, recommendedAmount: bigint) {
    switch (method) {
      case ProcessingFeeMethod.RECOMMENDED:
        $processingFee = recommendedAmount;
        inputBox?.clear();

        break;
      case ProcessingFeeMethod.CUSTOM:
        // Get a previous value entered if exists, otherwise default to 0
        $processingFee = parseToWei(inputBox?.getValue());

        // We need to wait for Svelte to set the attribute `disabled` on the input
        // to false to be able to focus it
        tick().then(focusInputBox);
        break;
      case ProcessingFeeMethod.NONE:
        $processingFee = BigInt(0);
        inputBox?.clear();

        break;
    }
  }

  function unselectNoneIfNotEnoughETH(method: ProcessingFeeMethod, enoughEth: boolean) {
    if (method === ProcessingFeeMethod.NONE && !enoughEth) {
      $processingFeeMethod = ProcessingFeeMethod.RECOMMENDED;

      // We need to manually trigger this update because we are already in an update
      // cicle, meaning the change above will not start a new one. This is how Svelte
      // works, batching all the changes and kicking off an update cicle. This could
      // also prevent infinite loops. It's safe though to call this function because
      // we're not changing state that could potentially end up in such situation.
      updateProcessingFee($processingFeeMethod, recommendedAmount);
    }
  }

  $: {
    updateProcessingFee($processingFeeMethod, recommendedAmount);
  }
  $: unselectNoneIfNotEnoughETH($processingFeeMethod, hasEnoughEth);
</script>

{#if small}
  <div class="ProcessingFee">
    <div class="f-between-center">
      <span class="text-secondary-content">{$t('processing_fee.title')}</span>
      <span class=" text-primary-content mt-[4px]">
        {#if calculatingRecommendedAmount}
          <LoadingText mask="0.0017730224073" />
        {:else if errorCalculatingRecommendedAmount}
          {$t('processing_fee.recommended.error')}
        {:else}
          {formatEther($processingFee ?? BigInt(0))} ETH {#if $processingFee !== recommendedAmount}
            <span class="text-primary-link">| {$t('common.customized')}</span>
          {/if}
        {/if}
      </span>
    </div>
  </div>
{:else if textOnly}
  <span class="text-primary-content mt-[4px] {$$props.class}">
    {#if calculatingRecommendedAmount}
      <LoadingText mask="0.0017730224073" />
    {:else if errorCalculatingRecommendedAmount}
      {$t('processing_fee.recommended.error')}
    {:else}
      {formatEther($processingFee ?? BigInt(0))} ETH {#if $processingFee !== recommendedAmount}
        <span class="text-primary-link">| {$t('common.customized')}</span>
      {/if}
    {/if}
  </span>
{:else}
  <div class="ProcessingFee">
    <div class="f-between-center">
      <div class="flex space-x-2">
        <span class="body-small-bold text-primary-content">{$t('processing_fee.title')}</span>
        <Tooltip>
          <h2>{$t('processing_fee.tooltip_title')}</h2>
          {$t('processing_fee.tooltip')}
        </Tooltip>
      </div>
      {#if !disabled}
        <button class="link" on:click={openModal} on:focus={openModal}>{$t('common.edit')}</button>
      {/if}
    </div>

    <span class="body-small-regular text-secondary-content mt-[4px]">
      {#if calculatingRecommendedAmount}
        <LoadingText mask="0.0001" /> ETH
      {:else if errorCalculatingRecommendedAmount}
        {$t('processing_fee.recommended.error')}
      {:else}
        {formatEther($processingFee ?? BigInt(0))} ETH {#if $processingFee !== recommendedAmount}
          <span class="text-primary-link">| {$t('common.customized')}</span>
        {/if}
      {/if}
    </span>

    <dialog
      id={dialogId}
      class="modal"
      class:modal-open={modalOpen}
      use:closeOnEscapeOrOutsideClick={{ enabled: modalOpen, callback: () => (modalOpen = false), uuid: dialogId }}>
      <div class="modal-box relative px-6 py-[35px] md:rounded-[20px] bg-neutral-background">
        <CloseButton onClick={cancelModal} />

        <div class="w-full">
          <h3 class="title-body-bold mb-7">{$t('processing_fee.title')}</h3>

          <p class="body-regular text-secondary-content mb-3">{$t('processing_fee.description')}</p>

          <ul class="space-y-7">
            <!-- RECOMMENDED -->
            <li class="f-between-center">
              <div class="f-col">
                <label for="input-recommended" class="body-bold">
                  {$t('processing_fee.recommended.label')}
                </label>
                <span class="body-small-regular text-secondary-content">
                  <!-- TODO: think about the UI for this part. Talk to Jane -->
                  {#if calculatingRecommendedAmount}
                    <LoadingText mask="0.0001" /> ETH
                  {:else if errorCalculatingRecommendedAmount}
                    {$t('processing_fee.recommended.error')}
                  {:else}
                    {formatEther(recommendedAmount)} ETH
                  {/if}
                </span>
              </div>
              <input
                id="input-recommended"
                class="radio w-6 h-6 checked:bg-primary-interactive-accent hover:border-primary-interactive-hover"
                type="radio"
                value={ProcessingFeeMethod.RECOMMENDED}
                name="processingFeeMethod"
                bind:group={$processingFeeMethod} />
            </li>

            <!-- NONE -->
            <li class="space-y-2">
              <div class="f-between-center">
                <div class="f-col">
                  <label for="input-none" class="body-bold">
                    {$t('processing_fee.none.label')}
                  </label>
                  <span class="body-small-regular text-secondary-content">
                    {$t('processing_fee.none.text')}
                  </span>
                </div>
                <input
                  id="input-none"
                  class="radio w-6 h-6 checked:bg-primary-interactive-accent hover:border-primary-interactive-hover"
                  type="radio"
                  disabled={!hasEnoughEth}
                  value={ProcessingFeeMethod.NONE}
                  name="processingFeeMethod"
                  bind:group={$processingFeeMethod} />
              </div>

              {#if !hasEnoughEth}
                <FlatAlert type="error" message={$t('processing_fee.none.warning')} />
              {/if}
            </li>

            <!-- CUSTOM -->
            <li class="f-between-center">
              <div class="f-col">
                <label for="input-custom" class="body-bold">
                  {$t('processing_fee.custom.label')}
                </label>
                <span class="body-small-regular text-secondary-content">
                  {$t('processing_fee.custom.text')}
                </span>
              </div>
              <input
                id="input-custom"
                class="radio w-6 h-6 checked:bg-primary-interactive-accent hover:border-primary-interactive-hover"
                type="radio"
                value={ProcessingFeeMethod.CUSTOM}
                name="processingFeeMethod"
                bind:group={$processingFeeMethod} />
            </li>
          </ul>
          <div class="relative f-items-center my-[20px]">
            {#if $processingFeeMethod === ProcessingFeeMethod.CUSTOM}
              <InputBox
                type="number"
                min="0"
                placeholder="0.01"
                disabled={$processingFeeMethod !== ProcessingFeeMethod.CUSTOM}
                class="w-full input-box p-6 pr-16"
                on:input={inputProcessFee}
                bind:this={inputBox} />
              <span class="absolute right-6 uppercase body-bold text-secondary-content">ETH</span>
            {/if}
          </div>
          <div class="grid grid-cols-2 gap-[20px]">
            <ActionButton on:click={cancelModal} priority="secondary">
              <span class="body-bold">{$t('common.cancel')}</span>
            </ActionButton>
            <ActionButton priority="primary" on:click={closeModal}>
              <span class="body-bold">{$t('common.confirm')}</span>
            </ActionButton>
          </div>
        </div>
      </div>
    </dialog>
  </div>
{/if}

<RecommendedFee bind:amount={recommendedAmount} bind:calculating={calculatingRecommendedAmount} />

<NoneOption
  bind:enoughEth={hasEnoughEth}
  bind:calculating={calculatingEnoughEth}
  bind:error={errorCalculatingEnoughEth} />
