<script lang="ts">
  import { isAddress } from 'ethereum-address';
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';
  import type { Address } from 'viem';

  import { Alert } from '$components/Alert';
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
  <div class="relative f-items-center">
    <input
      id={inputId}
      type="string"
      placeholder="0x1B77..."
      bind:value={ethereumAddress}
      on:input={(e) => validateEthereumAddress(e.target)}
      class="w-full input-box outline-none py-6 pr-16 px-[26px] title-subsection-bold placeholder:text-tertiary-content" />
  </div>
</div>
<div>
  {#if !isValidEthereumAddress && !tooShort}
    <Alert type="error" forceColumnFlow>
      <!-- TODO: i18n! -->
      <p class="font-bold">Invalid address</p>
      <p>This doesn't seem to be a valid Ethereum address</p>
    </Alert>
  {:else if isValidEthereumAddress && !tooShort && showAlert}
    <Alert type="success">
      <p class="font-bold">Valid address format</p>
    </Alert>
  {/if}
</div>
