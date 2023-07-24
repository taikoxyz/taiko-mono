<script lang="ts">
  import { tick } from 'svelte';
  import { t } from 'svelte-i18n';
  import { formatEther } from 'viem';

  import { Alert } from '$components/Alert';
  import { Button } from '$components/Button';
  import { Icon } from '$components/Icon';
  import { InputBox } from '$components/InputBox';
  import { LoadingText } from '$components/LoadingText';
  import { Tooltip } from '$components/Tooltip';
  import { processingFeeComponent } from '$config';
  import { ProcessingFeeMethod } from '$libs/fee';
  import { parseToWei } from '$libs/util/parseToWei';
  import { uid } from '$libs/util/uid';

  import { processingFee } from '../state';
  import NoneOption from './NoneOption.svelte';
  import RecommendedFee from './RecommendedFee.svelte';

  let dialogId = `dialog-${uid()}`;
  let selectedFeeMethod = ProcessingFeeMethod.RECOMMENDED;
  let prevOptionSelected = ProcessingFeeMethod.RECOMMENDED;

  let recommendedAmount = BigInt(0);
  let calculatingRecommendedAmount = false;
  let errorCalculatingRecommendedAmount = false;

  let hasEnoughEth = false;
  let calculatingEnoughEth = false;
  let errorCalculatingEnoughEth = false;

  let modalOpen = false;
  let inputBox: InputBox;

  function closeModal() {
    // Let's check if we are closing with CUSTOM method selected and zero amount entered
    if (selectedFeeMethod === ProcessingFeeMethod.CUSTOM && $processingFee === BigInt(0)) {
      // If so, let's switch to RECOMMENDED method
      selectedFeeMethod = ProcessingFeeMethod.RECOMMENDED;
    }

    modalOpen = false;
  }

  function openModal() {
    // Keep track of the selected method before opening the modal
    // so if we cancel we can go back to the previous method
    prevOptionSelected = selectedFeeMethod;

    modalOpen = true;
  }

  function cancelModal() {
    inputBox.clear();
    selectedFeeMethod = prevOptionSelected;
    closeModal();
  }

  function closeModalWithDelay() {
    // By adding delay there is enough time to see the selected option
    // before closing the modal. Better experience for the user.
    setTimeout(closeModal, processingFeeComponent.closingDelayOptionClick);
  }

  function focusInputBox() {
    inputBox.focus();
  }

  function onInputBoxChange(event: Event) {
    if (selectedFeeMethod !== ProcessingFeeMethod.CUSTOM) return;

    const input = event.target as HTMLInputElement;
    $processingFee = parseToWei(input.value);
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
      selectedFeeMethod = ProcessingFeeMethod.RECOMMENDED;

      // We need to manually trigger this update because we are already in an update
      // cicle, meaning the change above will not start a new one. This is how Svelte
      // works, batching all the changes and kicking off an update cicle. This could
      // also prevent infinite loops. It's safe though to call this function because
      // we're not changing state that could potentially end up in such situation.
      updateProcessingFee(selectedFeeMethod, recommendedAmount);
    }
  }

  $: updateProcessingFee(selectedFeeMethod, recommendedAmount);

  $: unselectNoneIfNotEnoughETH(selectedFeeMethod, hasEnoughEth);
</script>

<div class="ProcessingFee">
  <div class="f-between-center">
    <div class="flex space-x-2">
      <span class="body-small-regular text-secondary-content">{$t('processing_fee.title')}</span>
      <Tooltip>TODO: add description about processing fee</Tooltip>
    </div>
    <button class="link" on:click={openModal} on:focus={openModal}>{$t('processing_fee.link')}</button>
  </div>

  <span class="body-small-regular text-secondary-content mt-[6px]">
    {#if calculatingRecommendedAmount}
      <LoadingText mask="0.0001" /> ETH
    {:else if errorCalculatingRecommendedAmount}
      {$t('processing_fee.recommended.error')}
    {:else}
      {formatEther($processingFee ?? BigInt(0))} ETH
    {/if}
  </span>

  <dialog id={dialogId} class="modal" class:modal-open={modalOpen}>
    <div class="modal-box relative px-6 py-[35px] md:rounded-[20px] bg-neutral-background">
      <button class="absolute right-6 top-[35px]" on:click={closeModal}>
        <Icon type="x-close" fillClass="fill-primary-icon" size={24} />
      </button>

      <h3 class="title-body-bold mb-7">{$t('processing_fee.title')}</h3>

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
            bind:group={selectedFeeMethod}
            on:click={closeModalWithDelay} />
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
              bind:group={selectedFeeMethod}
              on:click={closeModalWithDelay} />
          </div>

          {#if !hasEnoughEth}
            <Alert type="warning">
              {$t('processing_fee.none.warning')}
            </Alert>
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
            bind:group={selectedFeeMethod} />
        </li>
      </ul>

      <div class="relative f-items-center my-[20px]">
        <InputBox
          type="number"
          min="0"
          placeholder="0.01"
          disabled={selectedFeeMethod !== ProcessingFeeMethod.CUSTOM}
          class="w-full input-box outline-none p-6 pr-16 title-subsection-bold placeholder:text-tertiary-content"
          on:input={onInputBoxChange}
          bind:this={inputBox} />
        <span class="absolute right-6 uppercase body-bold text-secondary-content">ETH</span>
      </div>

      <div class="grid grid-cols-2 gap-[20px]">
        <Button
          on:click={cancelModal}
          type="neutral"
          class="px-[28px] py-[10px] rounded-full w-auto bg-transparent !border border-primary-brand hover:border-primary-interactive-hover">
          <span class="body-bold">{$t('processing_fee.button.cancel')}</span>
        </Button>
        <Button type="primary" class="px-[28px] py-[10px] rounded-full w-auto" on:click={closeModal}>
          <span class="body-bold">{$t('processing_fee.button.confirm')}</span>
        </Button>
      </div>
    </div>
  </dialog>
</div>

<RecommendedFee bind:amount={recommendedAmount} />

<NoneOption
  bind:enoughEth={hasEnoughEth}
  bind:calculating={calculatingEnoughEth}
  bind:error={errorCalculatingEnoughEth} />
