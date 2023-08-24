<script lang="ts">
  import { isAddress } from 'ethereum-address';
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';
  import type { Address } from 'viem';

  import FlatAlert from '$components/Alert/FlatAlert.svelte';
  import { Icon } from '$components/Icon';
  import { uid } from '$libs/util/uid';

  let input: HTMLInputElement;
  let inputId = `input-${uid()}`;
  let showAlert = true;

  export let ethereumAddress: Address | string = '';

  let isValidEthereumAddress = false;
  let tooShort = true;
  const dispatch = createEventDispatcher();

  const validateEthereumAddress = (address: string | EventTarget | null) => {
    if (address && address instanceof EventTarget) {
      address = (address as HTMLInputElement).value;
    }

    const addr = address as string;
    if (addr.length < 42) {
      tooShort = true;
      isValidEthereumAddress = false;
    } else {
      tooShort = false;
      isValidEthereumAddress = isAddress(addr);
      dispatch('input', addr);
    }
    dispatch('addressvalidation', { isValidEthereumAddress, addr });
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
  <div class="relative f-items-center }">
    <input
      bind:this={input}
      id={inputId}
      type="string"
      placeholder="0x1B77..."
      bind:value={ethereumAddress}
      on:input={(e) => validateEthereumAddress(e.target)}
      class="w-full input-box py-6 pr-16 px-[26px] title-subsection-bold placeholder:text-tertiary-content" />
    <button class="absolute right-6 uppercase body-bold text-secondary-content" on:click={clear}>
      <Icon type="x-close-circle" fillClass="fill-primary-icon" size={24} />
    </button>
  </div>
</div>
<div class="mt-3">
  {#if !isValidEthereumAddress && !tooShort}
    <FlatAlert type="error" forceColumnFlow message={$t('inputs.address_input.errors.invalid')} />
  {:else if isValidEthereumAddress && !tooShort && showAlert}
    <FlatAlert type="success" forceColumnFlow message={$t('inputs.address_input.success')} />
  {/if}
</div>
