<script lang="ts">
  import { tick } from 'svelte';
  import { t } from 'svelte-i18n';

  import { Icon } from '$components/Icon';
  import { Tooltip } from '$components/Tooltip';
  import { ProcessingFeeMethod } from '$libs/free';
  import { uid } from '$libs/util/uid';
  import { InputBox } from '$components/InputBox';
  import { recommendProcessingFee } from '$libs/free';

  let dialogId = `dialog-${uid()}`;
  let selectedFeeMethod = ProcessingFeeMethod.RECOMMENDED;

  let recommendedAmount = 0;
  let calculatingRecommendedAmount = false;
  let errorCalculatingRecommendedAmount = false;

  let selectedAmount = 0;
  let modalOpen = false;
  let customInput: InputBox;

  async function calculateRecommendedAmount() {
    calculatingRecommendedAmount = true;
    try {
      recommendedAmount = await recommendProcessingFee();
      errorCalculatingRecommendedAmount = false;
    } catch (error) {
      errorCalculatingRecommendedAmount = true;
      recommendedAmount = 0;
    } finally {
      calculatingRecommendedAmount = false;
    }

    return recommendedAmount;
  }

  function focusCustomInput() {
    customInput?.focus();
  }

  async function onSelectedFeeMethodChanged(method: ProcessingFeeMethod) {
    // customInput?.clear();

    switch (method) {
      case ProcessingFeeMethod.RECOMMENDED:
        // Get the cached value if exists, otherwise calculate it
        selectedAmount = recommendedAmount ? recommendedAmount : await calculateRecommendedAmount();
        break;
      case ProcessingFeeMethod.CUSTOM:
        // Get a previous value entered if exists, otherwise default to 0
        selectedAmount = Number(customInput?.value() ?? 0);

        // We need to wait for Svelte to set the attribute `disabled` on the input
        // to false to be able to focus it
        tick().then(focusCustomInput);
        break;
      case ProcessingFeeMethod.NONE:
        selectedAmount = 0;
        break;
    }
  }

  function onCustomInputChange(event: Event) {
    const { value } = event.target as HTMLInputElement;
    selectedAmount = Number(value);
  }

  function closeModal() {
    modalOpen = false;
  }

  function openModal() {
    modalOpen = true;
  }

  // TODO: some info needs to be passed in in order to calculate the recommended amount
  $: calculateRecommendedAmount();

  // TODO: how about using a onClick handler instead of this watcher?
  $: onSelectedFeeMethodChanged(selectedFeeMethod);
</script>

<div class="ProcessingFee">
  <div class="f-between-center">
    <div class="flex space-x-2">
      <span class="body-small-regular text-secondary-content">{$t('processing_fee.title')}</span>
      <Tooltip>TODO: add description about processing fee</Tooltip>
    </div>
    <button
      class="link-regular text-primary-link underline hover:text-primary-link-hover"
      on:click={openModal}
      on:focus={openModal}>{$t('processing_fee.link')}</button>
  </div>

  <span class="body-small-regular text-secondary-content mt-[6px]">
    {#if calculatingRecommendedAmount}
      {$t('processing_fee.recommended.calculating')}…
    {:else if errorCalculatingRecommendedAmount}
      {$t('processing_fee.recommended.error')}
    {:else}
      {selectedAmount} ETH
    {/if}
  </span>

  <dialog id={dialogId} class="modal absolute modal-bottom px-4 pb-4" class:modal-open={modalOpen}>
    <div class="modal-box relative px-6 py-[30px] bg-neutral-background rounded-2xl">
      <button class="absolute right-6 top-[30px]" on:click={closeModal}>
        <Icon type="x-close" fillClass="fill-primary-icon" />
      </button>

      <h3 class="title-body-bold mb-7">{$t('processing_fee.title')}</h3>

      <ul class="space-y-7 mb-[20px]">
        <!-- RECOMMENDED -->
        <li class="f-between-center">
          <div class="f-col">
            <label for="input-recommended" class="body-bold">
              {$t('processing_fee.recommended.label')}
            </label>
            <span class="body-small-regular text-secondary-content">
              <!-- TODO: think about the UI for this part. Talk to Jane -->
              {#if calculatingRecommendedAmount}
                {$t('processing_fee.recommended.calculating')}
              {:else if errorCalculatingRecommendedAmount}
                {$t('processing_fee.recommended.error')}
              {:else}
                {recommendedAmount} ETH
              {/if}
            </span>
          </div>
          <input
            id="input-recommended"
            class="radio w-6 h-6 checked:bg-primary-interactive-accent hover:border-primary-interactive-hover"
            type="radio"
            value={ProcessingFeeMethod.RECOMMENDED}
            name="processingFeeMethod"
            bind:group={selectedFeeMethod} />
        </li>

        <!-- NONE -->
        <li class="f-between-center">
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
            value={ProcessingFeeMethod.NONE}
            name="processingFeeMethod"
            bind:group={selectedFeeMethod} />
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
      <div class="relative f-items-center">
        <InputBox
          type="number"
          min="0"
          placeholder="0.01"
          disabled={selectedFeeMethod !== ProcessingFeeMethod.CUSTOM}
          class="w-full input-box outline-none p-6 pr-16 title-subsection-bold placeholder:text-tertiary-content"
          on:input={onCustomInputChange}
          bind:this={customInput} />
        <span class="absolute right-6 uppercase body-bold text-secondary-content">ETH</span>
      </div>
    </div>

    <div class="overlay-backdrop" />
  </dialog>
</div>
