<script lang="ts">
  import { onDestroy } from 'svelte';
  import { t } from 'svelte-i18n';
  import type { Address } from 'viem';

  import { Button } from '$components/Button';
  import { CloseButton } from '$components/CloseButton';
  import { Tooltip } from '$components/Tooltip';
  import { shortenAddress } from '$libs/util/shortenAddress';
  import { uid } from '$libs/util/uid';
  import { account } from '$stores/account';

  import AddressInput from './AddressInput/AddressInput.svelte';
  import { recipientAddress } from './state';

  // Public API
  export const clearRecipient = () => {
    addressInput.clearAddress(); // update UI
    $recipientAddress = null; // update state
  };

  let dialogId = `dialog-${uid()}`;
  let addressInput: AddressInput;

  let modalOpen = false;
  let invalidAddress = false;
  let prevRecipientAddress: Maybe<Address> = null;

  function closeModal() {
    modalOpen = false;
  }

  function openModal() {
    modalOpen = true;
    addressInput.focus();
    addEscKeyListener();
  }

  function cancelModal() {
    // Revert change of recipient address
    $recipientAddress = prevRecipientAddress;
    removeEscKeyListener();
    closeModal();
  }

  function modalOpenChange(open: boolean) {
    if (open) {
      // Save it in case we want to cancel
      prevRecipientAddress = $recipientAddress;
    }
  }

  function onAddressValidation(event: CustomEvent<{ isValidEthereumAddress: boolean; addr: Address }>) {
    const { isValidEthereumAddress, addr } = event.detail;
    if (isValidEthereumAddress) {
      $recipientAddress = addr;
      invalidAddress = false;
    } else {
      invalidAddress = true;
    }
  }

  let escKeyListener: (event: KeyboardEvent) => void;

  const addEscKeyListener = () => {
    escKeyListener = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        closeModal();
      }
    };
    window.addEventListener('keydown', escKeyListener);
  };

  const removeEscKeyListener = () => {
    window.removeEventListener('keydown', escKeyListener);
  };

  onDestroy(() => {
    removeEscKeyListener();
  });

  $: modalOpenChange(modalOpen);

  $: ethereumAddressBinding = $recipientAddress || undefined;

  $: displayedRecipient = $recipientAddress || $account?.address;
</script>

<div class="Recipient f-col">
  <div class="f-between-center">
    <div class="flex space-x-2">
      <span class="body-small-bold text-primary-content">{$t('recipient.title')}</span>
      <Tooltip>
        <h2>{$t('recipient.tooltip_title')}</h2>
        {$t('recipient.tooltip')}
      </Tooltip>
    </div>
    <button class="link" on:click={openModal} on:focus={openModal}>{$t('common.edit')}</button>
  </div>

  <span class="body-small-regular text-secondary-content mt-[4px]">
    {#if displayedRecipient}
      {shortenAddress(displayedRecipient, 15, 13)}
      <span class="text-secondary">{$recipientAddress !== $account?.address ? '' : '| Customized'}</span>
    {:else}
      {$t('recipient.placeholder')}
    {/if}
  </span>

  <dialog id={dialogId} class="modal" class:modal-open={modalOpen}>
    <div class="modal-box relative px-6 md:rounded-[20px] bg-neutral-background">
      <CloseButton onClick={closeModal} />

      <div class="w-full">
        <h3 class="title-body-bold mb-7">{$t('recipient.title')}</h3>

        <p class="body-regular text-secondary-content mb-3">{$t('recipient.description')}</p>

        <div class="relative my-[20px]">
          <AddressInput
            bind:this={addressInput}
            bind:ethereumAddress={ethereumAddressBinding}
            on:addressvalidation={onAddressValidation} />
        </div>

        <div class="grid grid-cols-2 gap-[20px]">
          <Button
            on:click={cancelModal}
            type="neutral"
            class="px-[28px] py-[10px] rounded-full w-auto bg-transparent !border border-primary-brand hover:border-primary-interactive-hover">
            <span class="body-bold">{$t('common.cancel')}</span>
          </Button>
          <Button
            type="primary"
            disabled={invalidAddress || !ethereumAddressBinding}
            class="px-[28px] py-[10px] rounded-full w-auto"
            on:click={closeModal}
            hasBorder={true}>
            <span class="body-bold">{$t('common.confirm')}</span>
          </Button>
        </div>
      </div>
    </div>
  </dialog>
</div>
