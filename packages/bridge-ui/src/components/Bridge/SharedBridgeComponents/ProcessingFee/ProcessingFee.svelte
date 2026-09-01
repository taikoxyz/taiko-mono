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

  import { parseCustomFeeInput } from './customFee';
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

  /**
   * The zero-gas-limit choice while the dialog is open. It stays local until Confirm for
   * the same reason the method does: writing the committed store on the checkbox meant
   * Cancel left the fee at NONE/0, and the user's next bridge went out with no relayer
   * fee and silent manual claiming - a state they had explicitly cancelled.
   */
  let tempGasLimitZero = $gasLimitZero;

  let tempprocessingFee = $processingFee;

  // Set when the custom fee box holds text that does not parse, so tempprocessingFee
  // still describes whatever was typed before it
  let invalidCustomFee = false;

  // Whether the custom fee box currently holds a fee that can be submitted. An empty box
  // is not an error to report, but it is not a fee either: tempprocessingFee still holds
  // the last value that parsed, so without this, typing a fee and then clearing the box
  // left Confirm enabled and submitted the fee the box no longer shows
  let customFeeUsable = false;

  // Public API
  export function resetProcessingFee() {
    inputBox?.clear();
    $processingFeeMethod = ProcessingFeeMethod.RECOMMENDED;
    // Without this the zero-gas-limit choice outlives the bridge that made it, and the
    // reactive below drags the freshly reset method straight back to NONE
    $gasLimitZero = false;
    tempGasLimitZero = false;
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
    // Committed together: Bridge.sol rejects a zero gas limit carrying a fee, so the two
    // may only ever change as a pair
    $gasLimitZero = tempGasLimitZero;
    if (tempGasLimitZero) {
      $processingFeeMethod = ProcessingFeeMethod.NONE;
      $processingFee = BigInt(0);
    }
    closeModal();
  }

  function closeModal() {
    modalOpen = false;
    manuallyConfirmed = false;
  }

  function openModal() {
    tempProcessingFeeMethod = $processingFeeMethod;
    tempGasLimitZero = $gasLimitZero;
    modalOpen = true;
    manuallyConfirmed = false;
    invalidCustomFee = false;
    // Reopening on an already-committed custom fee starts from that fee rather than an
    // empty box: requiring the amount to be retyped to confirm anything else in the
    // dialog is friction the "must hold a usable fee" rule never meant to add
    // The method is what says a custom fee was committed, not its value: parseCustomFeeInput
    // accepts zero, so gating on a positive amount left a committed zero fee reopening to
    // an empty box with Confirm disabled until it was retyped
    const reopeningOnCustomFee = $processingFeeMethod === ProcessingFeeMethod.CUSTOM;
    customFeeUsable = reopeningOnCustomFee;
    if (reopeningOnCustomFee) {
      tempprocessingFee = $processingFee;
      // The input mounts with the CUSTOM branch, so fill it once it exists
      tick().then(() => inputBox?.setValue(formatEther($processingFee)));
    }
  }

  function cancelModal() {
    inputBox?.clear();
    invalidCustomFee = false;
    customFeeUsable = false;
    // Nothing committed, so nothing to restore - the draft simply goes
    tempGasLimitZero = $gasLimitZero;

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

    const { value } = event.target as HTMLInputElement;
    // Incomplete or invalid input keeps the previous fee; a custom fee below the
    // recommended amount is a deliberate choice the warning below covers
    const parsed = parseCustomFeeInput(value);
    // An empty box is not an error, it is simply not filled in yet - but it is still not
    // something that can be confirmed. Anything else that fails to parse is both.
    invalidCustomFee = parsed === null && value.trim() !== '';
    customFeeUsable = parsed !== null;
    if (parsed === null) return;
    tempprocessingFee = parsed;
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
    tempGasLimitZero = !tempGasLimitZero;
    if (tempGasLimitZero) {
      tempProcessingFeeMethod = ProcessingFeeMethod.NONE;
    } else {
      tempProcessingFeeMethod = ProcessingFeeMethod.RECOMMENDED;
    }
  };

  /**
   * @dev zeroGasLimit is a parameter rather than a `get(gasLimitZero)` read because Svelte
   *      tracks only what the reactive statement itself references, not what the function
   *      it calls reads. Reading the store in here left the guard out of the dependency
   *      list, so turning the zero-gas-limit option back off never re-ran this.
   */
  function unselectNoneIfNotEnoughETH(method: ProcessingFeeMethod, enoughEth: boolean, zeroGasLimit: boolean) {
    // A zero gas limit fixes the fee at zero, so there is nothing to afford and nothing to
    // switch away from. Overriding it here is what let a recommended fee ride along with a
    // zero gas limit, which the bridge rejects outright with B_INVALID_FEE.
    if (zeroGasLimit) return;

    if (method === ProcessingFeeMethod.NONE && enoughEth === false) {
      $processingFeeMethod = ProcessingFeeMethod.RECOMMENDED;

      // We need to manually trigger this update because we are already in an update
      // cycle, meaning the change above will not start a new one. This is how Svelte
      // works, batching all the changes and kicking off an update cycle. This could
      // also prevent infinite loops. It's safe though to call this function because
      // we're not changing state that could potentially end up in such situation.
      updateProcessingFee($processingFeeMethod, recommendedAmount);
    }
  }

  $: {
    updateProcessingFee($processingFeeMethod, recommendedAmount);
  }
  $: unselectNoneIfNotEnoughETH($processingFeeMethod, hasEnoughEth, $gasLimitZero);

  // Bridge.sol rejects a message whose gasLimit is 0 while its fee is not. The pairing is
  // established when the choice is committed in confirmChanges; this only catches a
  // committed state that has drifted since, which the method reset paths can produce.
  $: if ($gasLimitZero && $processingFee !== BigInt(0)) {
    $processingFeeMethod = ProcessingFeeMethod.NONE;
    $processingFee = BigInt(0);
  }

  $: manuallyConfirmed = false;

  $: needsConfirmation = tempProcessingFeeMethod !== ProcessingFeeMethod.RECOMMENDED || tempGasLimitZero;

  // Leaving CUSTOM discards the draft along with its error. This has to follow the
  // dialog's own method: updateProcessingFee runs on the committed $processingFeeMethod,
  // which the radios do not change, so clearing there left the flag set and a
  // CUSTOM -> RECOMMENDED -> CUSTOM round trip came back to an empty but blocked input.
  $: if (tempProcessingFeeMethod !== ProcessingFeeMethod.CUSTOM) {
    invalidCustomFee = false;
    customFeeUsable = false;
  }

  // Covers both ways tempprocessingFee can describe something the box no longer shows:
  // text that never parsed, and a box that has been emptied since it did
  $: customFeeUnusable = tempProcessingFeeMethod === ProcessingFeeMethod.CUSTOM && !customFeeUsable;

  $: confirmDisabled = (needsConfirmation && !manuallyConfirmed) || customFeeUnusable;
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
      use:closeOnEscapeOrOutsideClick={{ enabled: modalOpen, callback: cancelModal, uuid: dialogId }}>
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
                disabled={tempGasLimitZero}
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

              <NoneOption
                bind:enoughEth={hasEnoughEth}
                bind:calculating={calculatingEnoughEth}
                bind:error={errorCalculatingEnoughEth}
                selected={tempProcessingFeeMethod === ProcessingFeeMethod.NONE} />
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
                disabled={tempGasLimitZero}
                value={ProcessingFeeMethod.CUSTOM}
                name="processingFeeMethod"
                bind:group={tempProcessingFeeMethod} />
            </li>

            <div class="relative f-items-center my-[20px]">
              {#if tempProcessingFeeMethod === ProcessingFeeMethod.CUSTOM}
                <InputBox
                  type="number"
                  min="0"
                  placeholder="0.0015"
                  disabled={tempProcessingFeeMethod !== ProcessingFeeMethod.CUSTOM}
                  class="w-full input-box p-6 pr-16 title-subsection-bold placeholder:text-tertiary-content"
                  on:input={inputProcessFee}
                  bind:this={inputBox} />
                <span class="absolute right-6 uppercase body-bold text-secondary-content">ETH</span>
              {/if}
            </div>

            {#if invalidCustomFee}
              <!-- Confirm is disabled either way; without this the reason was invisible -->
              <div class="mb-[20px]">
                <FlatAlert type="error" message={$t('processing_fee.invalid_custom_fee')} />
              </div>
            {/if}

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
                checked={tempGasLimitZero}
                on:click={handleGasLimitZero}
                class="checkbox checkbox-primary" />
            </div>

            {#if tempGasLimitZero}
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

{#if small || textOnly}
  <NoneOption
    bind:enoughEth={hasEnoughEth}
    bind:calculating={calculatingEnoughEth}
    bind:error={errorCalculatingEnoughEth}
    headless />
{/if}
