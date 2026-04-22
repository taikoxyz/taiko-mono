<script lang="ts">
  import { t } from 'svelte-i18n';
  import type { Address } from 'viem';

  import { destNetwork, destOwnerAddress } from '$components/Bridge/state';
  import { ActionButton, CloseButton } from '$components/Button';
  import { Tooltip } from '$components/Tooltip';
  import { isSmartContract } from '$libs/util/isSmartContract';
  import { shortenAddress } from '$libs/util/shortenAddress';
  import { account } from '$stores/account';

  import AddressInput from '../AddressInput/AddressInput.svelte';

  // Public API
  export const clearRecipient = () => {
    if (addressInput) addressInput.clearAddress(); // update UI
    $destOwnerAddress = null; // update state
  };

  export let small = false;
  export let disabled = false;

  let dialogId = `dialog-${crypto.randomUUID()}`;
  let addressInput: AddressInput;

  let modalOpen = false;
  let invalidAddress = false;
  let prevDestOwnerAddress: Maybe<Address> = null;

  let destOwnerIsSmartContract = false;

  function closeModal() {
    modalOpen = false;
  }

  function openModal() {
    modalOpen = true;
    addressInput.focus();
    addEscKeyListener();
  }

  function cancelModal() {
    // Revert change of destOwner address
    $destOwnerAddress = prevDestOwnerAddress;
    removeEscKeyListener();
    closeModal();
  }

  function modalOpenChange(open: boolean) {
    if (open) {
      // Save it in case we want to cancel
      prevDestOwnerAddress = $destOwnerAddress;
    }
  }

  async function onAddressValidation(event: CustomEvent<{ isValidEthereumAddress: boolean; addr: Address }>) {
    const { isValidEthereumAddress, addr } = event.detail;
    if (isValidEthereumAddress) {
      invalidAddress = false;
      if ($destNetwork?.id && (await isSmartContract(addr, $destNetwork.id))) {
        destOwnerIsSmartContract = true;
      } else {
        destOwnerIsSmartContract = false;
        $destOwnerAddress = addr;
      }
    } else {
      invalidAddress = true;
    }
  }

  const resetAddress = () => {
    $destOwnerAddress = $account?.address;
    ethereumAddressBinding = undefined;
    destOwnerIsSmartContract = false;
  };

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

  $: ethereumAddressBinding = undefined;

  $: displayedDestOwner = $destOwnerAddress || $account?.address;
</script>

<div class="Recipient f-col">
  {#if small}
    <div class="f-between-center">
      <span class="text-secondary-content">{$t('destOwner.title')}</span>
      {#if displayedDestOwner}
        {shortenAddress(displayedDestOwner, 8, 10)}
        {#if displayedDestOwner !== $account?.address}
          <span class="text-primary-link">| {$t('common.customized')}</span>
        {/if}
      {:else}
        {$t('destOwner.placeholder')}
      {/if}
    </div>
  {:else}
    <div class="f-between-center">
      <div class="flex space-x-2">
        <span class="body-small-bold text-primary-content">{$t('destOwner.title')}</span>
        <Tooltip>
          <h2>{$t('destOwner.tooltip_title')}</h2>
          {$t('destOwner.tooltip')}
        </Tooltip>
      </div>
      {#if !disabled}
        <button class="link" on:click={openModal} on:focus={openModal}>{$t('common.edit')}</button>
      {/if}
    </div>

    <span class="body-small-regular text-secondary-content mt-[4px]">
      {#if displayedDestOwner}
        {shortenAddress(displayedDestOwner, 15, 13)}
        {#if displayedDestOwner !== $account?.address}
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
          <h3 class="title-body-bold mb-7">{$t('destOwner.title')}</h3>

          <p class="body-regular text-secondary-content mb-3">{$t('destOwner.description')}</p>

          <div class="relative my-[20px]">
            <AddressInput
              bind:this={addressInput}
              bind:ethereumAddress={ethereumAddressBinding}
              on:addressvalidation={onAddressValidation}
              on:clearInput={resetAddress}
              onDialog
              resettable />
          </div>

          {#if destOwnerIsSmartContract}
            <p class="body-regular text-secondary-content mb-3">
              You cannot set a smart contract as destination owner.
            </p>
          {/if}

          <div class="grid grid-cols-2 gap-[20px]">
            <ActionButton on:click={cancelModal} priority="secondary" onPopup>
              <span class="body-bold">{$t('common.cancel')}</span>
            </ActionButton>
            <ActionButton
              priority="primary"
              disabled={invalidAddress || !ethereumAddressBinding || destOwnerIsSmartContract}
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
