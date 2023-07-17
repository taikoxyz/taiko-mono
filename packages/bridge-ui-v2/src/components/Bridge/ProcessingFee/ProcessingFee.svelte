<script lang="ts">
  import { onMount, tick } from 'svelte';
  import { t } from 'svelte-i18n';
  import { formatEther, parseUnits } from 'viem';

  import { Icon } from '$components/Icon';
  import { InputBox } from '$components/InputBox';
  import LoadingText from '$components/LoadingText/LoadingText.svelte';
  import { Tooltip } from '$components/Tooltip';
  import { ProcessingFeeMethod } from '$libs/fee';
  import { recommendProcessingFee } from '$libs/fee';
  import type { Token } from '$libs/token';
  import { uid } from '$libs/util/uid';
  import { network } from '$stores/network';

  import { destNetwork, processingFee, selectedToken } from '../state';
  import { parseToWei } from '$libs/util/parseToWei';
  import RecommendedAmount from './RecommendedAmount.svelte';

  let dialogId = `dialog-${uid()}`;
  let selectedFeeMethod = ProcessingFeeMethod.RECOMMENDED;

  let recommendedAmount = BigInt(0);
  let calculatingRecommendedAmount = false;
  let errorCalculatingRecommendedAmount = false;

  let modalOpen = false;
  let customInput: InputBox;

  function closeModal() {
    modalOpen = false;
  }

  function openModal() {
    modalOpen = true;
  }

  function focusCustomInput() {
    customInput?.focus();
  }

  function onCustomInputChange(event: Event) {
    if (selectedFeeMethod !== ProcessingFeeMethod.CUSTOM) return;

    const input = event.target as HTMLInputElement;
    $processingFee = parseToWei(input.value);
  }

  async function onSelectedFeeMethodChanged(method: ProcessingFeeMethod, recommendedAmount: bigint) {
    // customInput?.clear();

    switch (method) {
      case ProcessingFeeMethod.RECOMMENDED:
        $processingFee = recommendedAmount;

        break;
      case ProcessingFeeMethod.CUSTOM:
        // Get a previous value entered if exists, otherwise default to 0
        $processingFee = parseToWei(customInput?.value());

        // We need to wait for Svelte to set the attribute `disabled` on the input
        // to false to be able to focus it
        tick().then(focusCustomInput);
        break;
      case ProcessingFeeMethod.NONE:
        $processingFee = BigInt(0);

        break;
    }
  }

  // TODO: how about using a onClick handler instead of this watcher?
  $: onSelectedFeeMethodChanged(selectedFeeMethod, recommendedAmount);
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

  <dialog id={dialogId} class="modal modal-bottom md:absolute md:px-4 md:pb-4" class:modal-open={modalOpen}>
    <div class="modal-box relative px-6 py-[35px] md:rounded-[20px] bg-neutral-background">
      <button class="absolute right-6 top-[35px]" on:click={closeModal}>
        <Icon type="x-close" fillClass="fill-primary-icon" size={24} />
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
            on:click={closeModal} />
        </li>

        <!-- NONE -->
        <li>
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
              value={ProcessingFeeMethod.NONE}
              name="processingFeeMethod"
              bind:group={selectedFeeMethod}
              on:click={closeModal} />
          </div>
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
  </dialog>
</div>

<RecommendedAmount
  bind:value={recommendedAmount}
  bind:calculating={calculatingRecommendedAmount}
  bind:error={errorCalculatingRecommendedAmount} />
