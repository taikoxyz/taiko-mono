<script lang="ts">
  import { isAddress } from 'ethereum-address';
  import { createEventDispatcher, onDestroy } from 'svelte';
  import { t } from 'svelte-i18n';
  import type { Address } from 'viem';

  import FlatAlert from '$components/Alert/FlatAlert.svelte';
  import { Icon } from '$components/Icon';
  import { withHoverAndFocusListener } from '$libs/customActions';
  import { classNames } from '$libs/util/classNames';
  import { uid } from '$libs/util/uid';

  import { AddressInputState as State } from './state';

  let inputElement: HTMLInputElement;
  let inputId = `input-${uid()}`;
  let isElementFocused = false;
  let isElementHovered = false;

  const dispatch = createEventDispatcher();
  const handleFocusChange = (focused: boolean) => (isElementFocused = focused);
  const handleHoverChange = (hovered: boolean) => (isElementHovered = hovered);

  export let ethereumAddress: Address | string = '';
  export let labelText = $t('inputs.address_input.label.default');
  export let isDisabled = false;
  export let quiet = false;
  export let state: State = State.DEFAULT;

  export let onDialog = false;

  // Validate the Ethereum address
  export const validateAddress = (): void => {
    if (!ethereumAddress) {
      state = State.DEFAULT;
      return;
    }

    if (ethereumAddress.length >= 2 && !ethereumAddress.startsWith('0x')) {
      state = State.INVALID;
      return;
    }

    state = ethereumAddress.length < 42 ? State.TOO_SHORT : isAddress(ethereumAddress) ? State.VALID : State.INVALID;

    dispatch('input', ethereumAddress);
    dispatch('addressvalidation', { isValidEthereumAddress: state === State.VALID, addr: ethereumAddress });
  };

  // Clear the input field
  export const clearAddress = (): void => {
    if (inputElement) inputElement.value = '';
    ethereumAddress = '';
    state = State.DEFAULT;
  };

  export const focus = (): void => inputElement.focus();

  $: defaultBorder = (() => {
    if (!onDialog || isElementFocused || isElementHovered) return '';
    return 'neutral';
  })();

  $: isWrongType = state === State.NOT_ERC20 || state === State.NOT_NFT;
  $: validState = state === State.VALID;
  $: invalidState = state === State.INVALID || isWrongType;

  $: borderState = validState ? 'success' : invalidState ? 'error' : defaultBorder;

  $: classes = classNames($$props.class, borderState);

  onDestroy(() => {
    clearAddress();
  });
</script>

<div class="f-col space-y-2">
  <!-- Input field and label -->
  <div class="f-between-center text-secondary-content">
    <label class="body-regular" for={inputId}>{labelText}</label>
  </div>
  <div class="relative f-items-center">
    <input
      use:withHoverAndFocusListener={{ onFocusChange: handleFocusChange, onHoverChange: handleHoverChange }}
      id={inputId}
      disabled={isDisabled}
      bind:this={inputElement}
      type="string"
      placeholder="0x1B77..."
      bind:value={ethereumAddress}
      on:input={validateAddress}
      class="w-full input-box withValdiation py-6 pr-16 px-[26px] font-bold placeholder:text-tertiary-content {classes}" />
    {#if ethereumAddress}
      <button class="absolute right-6 uppercase body-bold text-secondary-content" on:click={clearAddress}>
        <Icon type="x-close-circle" fillClass="fill-primary-icon" size={24} />
      </button>
    {/if}
  </div>

  <!-- Conditional alerts -->
  {#if !quiet}
    <div class="">
      {#if state === State.INVALID && ethereumAddress}
        <FlatAlert type="error" forceColumnFlow message={$t('inputs.address_input.errors.invalid')} />
      {:else if state === State.TOO_SHORT && ethereumAddress}
        <FlatAlert type="warning" forceColumnFlow message={$t('inputs.address_input.errors.too_short')} />
      {:else if state === State.VALID}
        <FlatAlert type="success" forceColumnFlow message={$t('inputs.address_input.success')} />
      {:else if state === State.NOT_NFT}
        <FlatAlert type="error" forceColumnFlow message={$t('inputs.address_input.errors.not_nft')} />
      {:else if state === State.NOT_ERC20}
        <FlatAlert type="error" forceColumnFlow message={$t('inputs.address_input.errors.not_erc20')} />
      {/if}
    </div>
  {/if}
</div>
