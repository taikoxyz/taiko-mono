<script lang="ts">
  import { t } from 'svelte-i18n';
  import type { Address } from 'viem';

  import { recipientAddress } from '$components/Bridge/state';
  import { ActionButton, CloseButton } from '$components/Button';
  import { Tooltip } from '$components/Tooltip';
  import { shortenAddress } from '$libs/util/shortenAddress';
  import { uid } from '$libs/util/uid';
  import { account } from '$stores/account';

  import AddressInput from '../AddressInput/AddressInput.svelte';

  // Public API
  export const clearRecipient = () => {
    if (addressInput) addressInput.clearAddress(); // update UI
    $recipientAddress = null; // update state
  };

  export let small = false;
  export let disabled = false;

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

  $: modalOpenChange(modalOpen);

  $: ethereumAddressBinding = $recipientAddress || undefined;

  $: displayedRecipient = $recipientAddress || $account?.address;
</script>

<div class="Recipient f-col">
  {#if small}
    <div class="f-between-center">
      <span class="text-secondary-content">{$t('recipient.title')}</span>
      {#if displayedRecipient}
        {shortenAddress(displayedRecipient, 8, 10)}
        {#if displayedRecipient !== $account?.address}
          <span class="text-primary-link">| {$t('common.customized')}</span>
        {/if}
      {:else}
        {$t('recipient.placeholder')}
      {/if}
    </div>
  {:else}
    <div class="f-between-center">
      <div class="flex space-x-2">
        <span class="body-small-bold text-primary-content">{$t('recipient.title')}</span>
        <Tooltip>
          <h2>{$t('recipient.tooltip_title')}</h2>
          {$t('recipient.tooltip')}
        </Tooltip>
      </div>
      {#if !disabled}
        <button class="link" on:click={openModal} on:focus={openModal}>{$t('common.edit')}</button>
      {/if}
    </div>

    <span class="body-small-regular text-secondary-content mt-[4px]">
      {#if displayedRecipient}
        {shortenAddress(displayedRecipient, 15, 13)}
        {#if displayedRecipient !== $account?.address}
          <span class="text-primary-link">| {$t('common.customized')}</span>
        {/if}
      {:else}
        {$t('recipient.placeholder')}
      {/if}
    </span>

    <dialog id={dialogId} class="modal" class:modal-open={modalOpen}>
      <div class="modal-box relative px-6 md:rounded-[20px] bg-neutral-background">
        <CloseButton onClick={cancelModal} />

        <div class="w-full">
          <h3 class="title-body-bold mb-7">{$t('recipient.title')}</h3>

          <p class="body-regular text-secondary-content mb-3">{$t('recipient.description')}</p>

          <div class="relative my-[20px]">
            <AddressInput
              bind:this={addressInput}
              bind:ethereumAddress={ethereumAddressBinding}
              on:addressvalidation={onAddressValidation}
              onDialog />
          </div>

          <div class="grid grid-cols-2 gap-[20px]">
            <ActionButton on:click={cancelModal} priority="secondary" onPopup>
              <span class="body-bold">{$t('common.cancel')}</span>
            </ActionButton>
            <ActionButton
              priority="primary"
              disabled={invalidAddress || !ethereumAddressBinding}
              on:click={closeModal}
              onPopup>
              <span class="body-bold">{$t('common.confirm')}</span>
            </ActionButton>
          </div>
        </div>
      </div>
    </dialog>
  {/if}
</div>
