<script lang="ts">
  import { isAddress } from 'ethereum-address';
  import { createEventDispatcher, onMount } from 'svelte';
  import { t } from 'svelte-i18n';
  import type { Address } from 'viem';

  import FlatAlert from '$components/Alert/FlatAlert.svelte';
  import { Icon } from '$components/Icon';
  import { uid } from '$libs/util/uid';

  import { AddressInputState as State } from './state';

  export let ethereumAddress: Address | string = '';
  export let labelText = $t('inputs.address_input.label.default');
  export let isDisabled = false;
  export let quiet = false;
  export let state: State = State.DEFAULT;

  export const validateAddress = () => {
    validateEthereumAddress(ethereumAddress);
  };

  export const clearAddress = () => {
    state = State.DEFAULT;
    if (input) input.value = '';
    validateEthereumAddress('');
  };

  export const focus = () => input.focus();

  let input: HTMLInputElement;
  let inputId = `input-${uid()}`;

  const dispatch = createEventDispatcher();

  const validateEthereumAddress = (address: string | EventTarget | null) => {
    let addr: string;
    if (!address) return;

    if (address && address instanceof EventTarget) {
      addr = (address as HTMLInputElement).value;
    } else {
      addr = address as string;
    }
    if (addr.length >= 2 && !addr.startsWith('0x')) {
      state = State.INVALID;
      return;
    }
    if (addr.length < 42) {
      state = State.TOO_SHORT;
    } else {
      if (isAddress(addr)) {
        state = State.VALID;
      } else {
        state = State.INVALID;
      }
      dispatch('input', addr);
    }

    dispatch('addressvalidation', { isValidEthereumAddress: state === State.VALID, addr });
  };

  onMount(() => {
    ethereumAddress = '';
  });

  $: validateEthereumAddress(ethereumAddress);
</script>

<div class="f-col space-y-2">
  <div class="f-between-center text-secondary-content">
    <label class="body-regular" for={inputId}>{labelText}</label>
  </div>
  <div class="relative f-items-center">
    <input
      id={inputId}
      disabled={isDisabled}
      type="string"
      placeholder="0x1B77..."
      bind:value={ethereumAddress}
      on:input={(e) => validateEthereumAddress(e.target)}
      class="w-full input-box withValdiation py-6 pr-16 px-[26px] title-subsection-bold placeholder:text-tertiary-content {$$props.class}
      {state === State.VALID ? 'success' : ethereumAddress && state !== State.VALIDATING ? 'error' : ''}
      " />
    <button class="absolute right-6 uppercase body-bold text-secondary-content" on:click={clearAddress}>
      <Icon type="x-close-circle" fillClass="fill-primary-icon" size={24} />
    </button>
  </div>
</div>

{#if !quiet}
  <div class="min-h-[20px] !mt-3">
    {#if state === State.INVALID && ethereumAddress}
      <FlatAlert type="error" forceColumnFlow message={$t('inputs.address_input.errors.invalid')} />
    {:else if state === State.TOO_SHORT && ethereumAddress}
      <FlatAlert type="warning" forceColumnFlow message={$t('inputs.address_input.errors.too_short')} />
    {:else if state === State.VALID}
      <FlatAlert type="success" forceColumnFlow message={$t('inputs.address_input.success')} />
    {/if}
  </div>
{/if}
