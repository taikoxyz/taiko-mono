<script lang="ts">
  import { t } from 'svelte-i18n';
  import type { Address } from 'viem';

  import { destNetwork, destOwnerAddress, recipientAddress } from '$components/Bridge/state';
  import { ActionButton, CloseButton } from '$components/Button';
  import { Tooltip } from '$components/Tooltip';
  import { isSmartContract } from '$libs/util/isSmartContract';
  import { shortenAddress } from '$libs/util/shortenAddress';
  import { account } from '$stores/account';

  import AddressInput from '../AddressInput/AddressInput.svelte';
  // import Alert from '$components/Alert/Alert.svelte';

  // Public API
  export const clearRecipient = () => {
    if (addressInput) addressInput.clearAddress(); // update UI
    $recipientAddress = null; // update state
  };

  export let small = false;
  export let disabled = false;

  let dialogId = `dialog-${crypto.randomUUID()}`;
  let addressInput: AddressInput;
  let destOwnerAddressInput: AddressInput;

  let modalOpen = false;
  let invalidRecipient = false;
  let invalidDestOwner = false;
  let prevRecipientAddress: Maybe<Address> = null;

  let recipientIsSmartContract = false;
  // let destOwnerIsSmartContract = false;

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
    $destOwnerAddress = recipientIsSmartContract ? $account?.address : null;
    removeEscKeyListener();
    closeModal();
  }

  function modalOpenChange(open: boolean) {
    if (open) {
      // Save it in case we want to cancel
      prevRecipientAddress = $recipientAddress;
    }
  }

  async function onRecipientValidation(event: CustomEvent<{ isValidEthereumAddress: boolean; addr: Address }>) {
    const { isValidEthereumAddress, addr } = event.detail;

    if (isValidEthereumAddress) {
      validateRecipient(addr);
    } else {
      invalidRecipient = true;
    }
  }

  const validateRecipient = async (addr: Address) => {
    $recipientAddress = addr;
    invalidRecipient = false;
    if ($destNetwork?.id && (await isSmartContract(addr, $destNetwork.id))) {
      recipientIsSmartContract = true;
    } else {
      recipientIsSmartContract = false;
    }
  };

  async function onDestOwnerValidation(event: CustomEvent<{ isValidEthereumAddress: boolean; addr: Address }>) {
    const { isValidEthereumAddress, addr } = event.detail;
    if (isValidEthereumAddress) {
      validateDestOwner(addr);
    } else {
      invalidDestOwner = true;
    }
  }

  const validateDestOwner = async (addr: Address) => {
    $destOwnerAddress = addr;
    invalidDestOwner = false;
    // if ($destNetwork?.id && (await isSmartContract(addr, $destNetwork.id))) {
    //   destOwnerIsSmartContract = true;
    //   // invalidDestOwner = true;
    // } else {
    //   destOwnerIsSmartContract = false;
    // }
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

  $: ethereumAddressBinding = $recipientAddress || undefined;
  $: destOwnerAddressBinding = $destOwnerAddress || undefined;

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
              on:addressvalidation={onRecipientValidation}
              onDialog
              resettable />
          </div>

          {#if recipientIsSmartContract}
            <p class="body-regular text-secondary-content mb-3">
              You are sending funds to a smart contract. Please provide an alternate address that can manually claim the
              funds if the relayer doesn't or you configured it that way. Ensure this is an address you control, as you
              cannot claim the funds as the smart contract directly.
            </p>
            <div class="relative my-[20px] space-y-4">
              <AddressInput
                bind:this={destOwnerAddressInput}
                bind:ethereumAddress={destOwnerAddressBinding}
                on:addressvalidation={onDestOwnerValidation}
                resettable
                onDialog />
              <!-- {#if destOwnerIsSmartContract}
                <Alert type="warning">{$t('destOwner.alerts.smartContract')}</Alert>
              {/if} -->
            </div>
          {/if}

          <div class="grid grid-cols-2 gap-[20px]">
            <ActionButton on:click={cancelModal} priority="secondary" onPopup>
              <span class="body-bold">{$t('common.cancel')}</span>
            </ActionButton>
            <ActionButton
              priority="primary"
              disabled={invalidRecipient ||
                invalidDestOwner ||
                !ethereumAddressBinding ||
                (recipientIsSmartContract && !destOwnerAddressBinding)}
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
