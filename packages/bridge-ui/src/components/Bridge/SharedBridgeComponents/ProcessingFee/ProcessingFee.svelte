<script lang="ts">
  import { tick } from 'svelte';
  import { t } from 'svelte-i18n';
  import { formatEther } from 'viem';

  import Alert from '$components/Alert/Alert.svelte';
  import FlatAlert from '$components/Alert/FlatAlert.svelte';
  import { calculatingProcessingFee, gasLimitZero, processingFee, processingFeeMethod } from '$components/Bridge/state';
  import { ActionButton, CloseButton } from '$components/Button';
  import { InputBox } from '$components/InputBox';
  import { LoadingText } from '$components/LoadingText';
  import { Tooltip } from '$components/Tooltip';
  import { closeOnEscapeOrOutsideClick } from '$libs/customActions';
  import { ProcessingFeeMethod } from '$libs/fee';
  import { parseToWei } from '$libs/util/parseToWei';

  import NoneOption from './NoneOption.svelte';
  import RecommendedFee from './RecommendedFee.svelte';

  export let small = false;
  export let textOnly = false;
  export let hasEnoughEth: boolean = false;
  export let disabled = false;

  let dialogId = `dialog-${crypto.randomUUID()}`;

  let recommendedAmount = BigInt(0);
  let errorCalculatingRecommendedAmount = false;

  let calculatingEnoughEth = false;
  let errorCalculatingEnoughEth = false;

  let modalOpen = false;
  let inputBox: InputBox | undefined;

  let tempProcessingFeeMethod = $processingFeeMethod;

  let tempprocessingFee = $processingFee;

  // Public API
  export function resetProcessingFee() {
    inputBox?.clear();
    $processingFeeMethod = ProcessingFeeMethod.RECOMMENDED;
  }

  function confirmChanges() {
    if (tempProcessingFeeMethod === ProcessingFeeMethod.CUSTOM) {
      // Let's check if we are closing with CUSTOM method selected and the input box is empty
      if (inputBox?.getValue() == '') {
        // If so, let's switch to RECOMMENDED method
        $processingFeeMethod = ProcessingFeeMethod.RECOMMENDED;
      } else {
        if ($processingFeeMethod === tempProcessingFeeMethod) {
          updateProcessingFee($processingFeeMethod, recommendedAmount);
        } else {
          $processingFeeMethod = tempProcessingFeeMethod;
        }
      }
    } else {
      inputBox?.clear();
      $processingFeeMethod = tempProcessingFeeMethod;
    }
    closeModal();
  }

  function closeModal() {
    modalOpen = false;
    manuallyConfirmed = false;
  }

  function openModal() {
    tempProcessingFeeMethod = $processingFeeMethod;
    modalOpen = true;
    $gasLimitZero = false;
    manuallyConfirmed = false;
  }

  function cancelModal() {
    inputBox?.clear();
    $gasLimitZero = false;

    if (tempProcessingFeeMethod === ProcessingFeeMethod.CUSTOM) {
      tempprocessingFee = $processingFee;
    }
    closeModal();
  }

  function focusInputBox() {
    inputBox?.focus();
  }

  function inputProcessFee(event: Event) {
    if (tempProcessingFeeMethod !== ProcessingFeeMethod.CUSTOM) return;
    const { value: finalValue } = event.target as HTMLInputElement;
    tempprocessingFee = parseToWei(finalValue);
  }

  async function updateProcessingFee(method: ProcessingFeeMethod, recommendedAmount: bigint) {
    switch (method) {
      case ProcessingFeeMethod.RECOMMENDED:
        $processingFee = recommendedAmount;

        break;
      case ProcessingFeeMethod.CUSTOM:
        $processingFee = tempprocessingFee;
        // We need to wait for Svelte to set the attribute `disabled` on the input
        // to false to be able to focus it
        tick().then(focusInputBox);
        break;
      case ProcessingFeeMethod.NONE:
        $processingFee = BigInt(0);

        break;
    }
  }

  const handleGasLimitZero = () => {
    $gasLimitZero = !$gasLimitZero;
    if ($gasLimitZero) {
      tempProcessingFeeMethod = ProcessingFeeMethod.NONE;
    } else {
      tempProcessingFeeMethod = ProcessingFeeMethod.RECOMMENDED;
    }
  };

  function unselectNoneIfNotEnoughETH(method: ProcessingFeeMethod, enoughEth: boolean) {
    if (method === ProcessingFeeMethod.NONE && enoughEth === false) {
      $processingFeeMethod = ProcessingFeeMethod.RECOMMENDED;

      // We need to manually trigger this update because we are already in an update
      // cicle, meaning the change above will not start a new one. This is how Svelte
      // works, batching all the changes and kicking off an update cicle. This could
      // also prevent infinite loops. It's safe though to call this function because
      // we're not changing state that could potentially end up in such situation.
      updateProcessingFee($processingFeeMethod, recommendedAmount);
    }
  }

  const onCustomClick = () => {
    inputBox?.setValue(formatEther(recommendedAmount));
  }

  $: {
    updateProcessingFee($processingFeeMethod, recommendedAmount);
  }
  $: unselectNoneIfNotEnoughETH($processingFeeMethod, hasEnoughEth);

  $: manuallyConfirmed = false;

  $: needsConfirmation = tempProcessingFeeMethod !== ProcessingFeeMethod.RECOMMENDED || $gasLimitZero;

  $: confirmDisabled = needsConfirmation && !manuallyConfirmed;
</script>

{#if small}
  <div class="ProcessingFee">
    <div class="f-between-center">
      <span class="text-secondary-content">{$t('processing_fee.title')}</span>
      <span class=" text-primary-content mt-[4px]">
        {#if $calculatingProcessingFee}
          <LoadingText mask="0.0017730224073" /> ETH
        {:else if errorCalculatingRecommendedAmount && $processingFeeMethod === ProcessingFeeMethod.RECOMMENDED}
          <FlatAlert type="warning" message={$t('processing_fee.recommended.error')} />
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
    {#if $calculatingProcessingFee}
      <LoadingText mask="0.0017730224073" />
    {:else if errorCalculatingRecommendedAmount && $processingFeeMethod === ProcessingFeeMethod.RECOMMENDED}
      <span class="text-warning-sentiment">{$t('processing_fee.recommended.error')}</span>
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
        <button class="link" on:click={openModal}>{$t('common.edit')}</button>
      {/if}
    </div>

    <span class="body-small-regular text-secondary-content mt-[4px]">
      {#if $calculatingProcessingFee}
        <LoadingText mask="0.0001" /> ETH
      {:else if errorCalculatingRecommendedAmount && $processingFeeMethod === ProcessingFeeMethod.RECOMMENDED}
        <FlatAlert type="warning" message={$t('processing_fee.recommended.error')} />
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
                  {#if $calculatingProcessingFee}
                    <LoadingText mask="0.0001" /> ETH
                  {:else if errorCalculatingRecommendedAmount}
                    <FlatAlert type="warning" message={$t('processing_fee.recommended.error')} />
                  {:else}
                    {formatEther(recommendedAmount)} ETH
                  {/if}
                </span>
              </div>
              <input
                id="input-recommended"
                class="radio w-6 h-6 checked:bg-primary-interactive-accent hover:border-primary-interactive-hover"
                type="radio"
                disabled={$gasLimitZero}
                value={ProcessingFeeMethod.RECOMMENDED}
                name="processingFeeMethod"
                bind:group={tempProcessingFeeMethod} />
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
                  bind:group={tempProcessingFeeMethod} />
              </div>

              {#if !hasEnoughEth}
                <FlatAlert type="error" message={$t('processing_fee.none.warning')} />
              {:else if tempProcessingFeeMethod === ProcessingFeeMethod.NONE}
                <div class="my-5">
                  <Alert type="warning">
                    <span class="body-small">
                      {$t('processing_fee.none.alert')}
                    </span>
                  </Alert>
                </div>
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
                disabled={$gasLimitZero}
                value={ProcessingFeeMethod.CUSTOM}
                on:change={onCustomClick}
                name="processingFeeMethod"
                bind:group={tempProcessingFeeMethod} />
            </li>
            <div style="display: {tempProcessingFeeMethod === ProcessingFeeMethod.CUSTOM ? 'block' : 'none'}" class="relative f-items-center my-[20px]">
                <InputBox
                  type="number"
                  min="0"
                  disabled={tempProcessingFeeMethod !== ProcessingFeeMethod.CUSTOM}
                  class="w-full input-box p-6 pr-16 title-subsection-bold placeholder:text-tertiary-content"
                  on:input={inputProcessFee}
                  bind:this={inputBox}
                />
                <span class="absolute top-7 right-6 uppercase body-bold text-secondary-content">ETH</span>
            </div>

            {#if tempProcessingFeeMethod === ProcessingFeeMethod.CUSTOM}
              <div class="my-5">
                <Alert type="warning">
                  <span class="body-small">
                    {$t('processing_fee.custom.warning')}
                  </span>
                </Alert>
              </div>
            {/if}

            <div class="f-between-center">
              <div class="f-col mr-[18px]">
                <label for="input-custom" class="body-bold"> {$t('processing_fee.gasLimit.title')}</label>
                <span class="body-small-regular text-secondary-content">{$t('processing_fee.gasLimit.message')}</span>
              </div>
              <input
                type="checkbox"
                checked={$gasLimitZero}
                on:click={handleGasLimitZero}
                class="checkbox checkbox-primary" />
            </div>

            {#if $gasLimitZero}
              <div class="my-5">
                <Alert type="warning">
                  <span class="body-small">
                    {$t('processing_fee.gasLimit.warning.message')}
                  </span>
                </Alert>
              </div>
            {/if}
            {#if needsConfirmation}
              <div class="h-sep" />
              <div class="f-between-center">
                <div class="f-col mr-[18px]">
                  <label for="input-custom" class="body-bold"> Confirm changes</label>
                  <span class="body-small-regular text-secondary-content">"I understand the changes I've made"</span>
                </div>
                <input
                  type="checkbox"
                  checked={manuallyConfirmed}
                  on:click={() => (manuallyConfirmed = !manuallyConfirmed)}
                  class="checkbox checkbox-primary" />
              </div>
              <div class="h-sep" />
            {/if}
            <div class="grid grid-cols-2 gap-[20px]">
              <ActionButton on:click={cancelModal} priority="secondary">
                <span class="body-bold">{$t('common.cancel')}</span>
              </ActionButton>

              <ActionButton priority="primary" on:click={confirmChanges} disabled={confirmDisabled} onPopup>
                <span class="body-bold">{$t('common.confirm')}</span>
              </ActionButton>
            </div>
          </ul>
        </div>
      </div>
    </dialog>
  </div>
{/if}

<RecommendedFee bind:amount={recommendedAmount} bind:error={errorCalculatingRecommendedAmount} />

<NoneOption
  bind:enoughEth={hasEnoughEth}
  bind:calculating={calculatingEnoughEth}
  bind:error={errorCalculatingEnoughEth} />
