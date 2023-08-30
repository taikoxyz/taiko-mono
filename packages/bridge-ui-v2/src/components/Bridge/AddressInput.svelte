<script lang="ts">
  import { isAddress } from 'ethereum-address';
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';
  import type { Address } from 'viem';

  import FlatAlert from '$components/Alert/FlatAlert.svelte';
  import { Icon } from '$components/Icon';
  import { uid } from '$libs/util/uid';

  enum State {
    Valid = 'valid',
    Invalid = 'invalid',
    TooShort = 'too_short',
  }

  let input: HTMLInputElement;
  let inputId = `input-${uid()}`;
  let state: State;

  export let ethereumAddress: Address | string = '';

  const dispatch = createEventDispatcher();

  const validateEthereumAddress = (address: string | EventTarget | null) => {
    let addr: string;

    if (address && address instanceof EventTarget) {
      addr = (address as HTMLInputElement).value;
    } else {
      addr = address as string;
    }
    if (addr.length >= 2 && !addr.startsWith('0x')) {
      state = State.Invalid;
      return;
    }
    if (addr.length < 42) {
      state = State.TooShort;
    } else {
      if (isAddress(addr)) {
        state = State.Valid;
      } else {
        state = State.Invalid;
      }
      dispatch('input', addr);
    }

    dispatch('addressvalidation', { isValidEthereumAddress: state === State.Valid, addr });
  };

  $: validateEthereumAddress(ethereumAddress);

  export const clear = () => {
    input.value = '';
    validateEthereumAddress('');
  };

  export const focus = () => input.focus();
</script>

<div class="f-col space-y-2">
  <div class="f-between-center text-secondary-content">
    <label class="body-regular" for={inputId}>{$t('inputs.address_input.label')}</label>
  </div>
  <div class="relative f-items-center">
    <input
      bind:this={input}
      id={inputId}
      type="string"
      placeholder="0x1B77..."
      bind:value={ethereumAddress}
      on:input={(e) => validateEthereumAddress(e.target)}
      class="w-full input-box withValdiation py-6 pr-16 px-[26px] title-subsection-bold placeholder:text-tertiary-content
      {state === State.Valid ? 'success' : ethereumAddress ? 'error' : ''}
      " />
    <button class="absolute right-6 uppercase body-bold text-secondary-content" on:click={clear}>
      <Icon type="x-close-circle" fillClass="fill-primary-icon" size={24} />
    </button>
  </div>
</div>
<div class="mt-5 min-h-[20px]">
  {#if state === State.Invalid && ethereumAddress}
    <FlatAlert type="error" forceColumnFlow message={$t('inputs.address_input.errors.invalid')} />
  {:else if state === State.TooShort && ethereumAddress}
    <FlatAlert type="warning" forceColumnFlow message={$t('inputs.address_input.errors.too_short')} />
  {:else if state === State.Valid}
    <FlatAlert type="success" forceColumnFlow message={$t('inputs.address_input.success')} />
  {/if}
</div>
