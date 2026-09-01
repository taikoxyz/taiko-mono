<script lang="ts">
  import { onDestroy } from 'svelte';
  import { t } from 'svelte-i18n';
  import type { Address } from 'viem';

  import { destNetwork, destOwnerAddress } from '$components/Bridge/state';
  import { ActionButton, CloseButton } from '$components/Button';
  import { Tooltip } from '$components/Tooltip';
  import { isSmartContract } from '$libs/util/isSmartContract';
  import { shortenAddress } from '$libs/util/shortenAddress';
  import { account } from '$stores/account';

  import AddressInput from '../AddressInput/AddressInput.svelte';
  import { canConfirmDestOwner, type ValidatedRecipient } from './recipientValidation';

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

  /**
   * The destination owner is written to the store by Confirm alone. It used to be committed
   * the moment an address validated, so opening the dialog, typing an address and pressing
   * Escape to abort kept it - for the one address that can claim a `gasLimit: 0` message.
   */
  function closeModal() {
    $destOwnerAddress = (destOwnerDraft as Address) ?? null;
    modalOpen = false;
  }

  function openModal() {
    if (modalOpen) return;
    modalOpen = true;
    addressInput.focus();
  }

  function cancelModal() {
    // Nothing was committed on the way in, but the draft and its classification describe an
    // edit that is being discarded, so both are put back to what the store still holds
    supersedePendingValidation();
    $destOwnerAddress = prevDestOwnerAddress;
    destOwnerDraft = prevDestOwnerAddress ?? undefined;
    if (addressInput) addressInput.setAddress(prevDestOwnerAddress ?? '');
    invalidAddress = false;
    destOwnerIsSmartContract = false;
    validated = prevValidated;
    modalOpen = false;
  }

  function modalOpenChange(open: boolean) {
    if (open) {
      // Saved in case we cancel: the address, and the classification that belongs to it
      prevDestOwnerAddress = $destOwnerAddress;
      prevValidated = validated;
    }
  }

  /**
   * A contract check describes one address on one chain. Without this counter a check for an
   * address typed earlier can resolve after a newer one: type a valid EOA, retype a contract
   * that answers faster, and the EOA's late answer clears the warning and commits the address
   * the box no longer shows.
   */
  let validationGeneration = 0;
  let validating = false;
  let validated: Maybe<ValidatedRecipient> = null;
  let prevValidated: Maybe<ValidatedRecipient> = null;

  function supersedePendingValidation() {
    validationGeneration++;
    validating = false;
  }

  async function onAddressValidation(event: CustomEvent<{ isValidEthereumAddress: boolean; addr: Address }>) {
    const { isValidEthereumAddress, addr } = event.detail;
    supersedePendingValidation();
    const generation = validationGeneration;

    if (!isValidEthereumAddress) {
      invalidAddress = true;
      validated = null;
      destOwnerIsSmartContract = false;
      return;
    }

    invalidAddress = false;
    const chainId = $destNetwork?.id;
    if (!chainId) {
      validated = null;
      return;
    }

    validating = true;
    let isContract: boolean;
    try {
      isContract = await isSmartContract(addr, chainId);
    } catch {
      // An unreadable chain is not a classification. Leaving the previous answer standing
      // would let it speak for an address it never ran against
      if (generation !== validationGeneration) return;
      validating = false;
      validated = null;
      destOwnerIsSmartContract = false;
      return;
    }

    if (generation !== validationGeneration) return;
    validating = false;
    destOwnerIsSmartContract = isContract;
    validated = isContract ? null : { address: addr, chainId };
  }

  /**
   * AddressInput dispatches nothing for a cleared field or for text without a `0x` prefix,
   * so the two-way bound draft is the only signal that an answer no longer describes what is
   * on screen.
   */
  function syncDraft(draft: string | undefined) {
    const current = (draft ?? '').toLowerCase();
    if (validated && validated.address.toLowerCase() !== current) {
      supersedePendingValidation();
      validated = null;
      destOwnerIsSmartContract = false;
      invalidAddress = false;
    }
  }

  // Declared via <svelte:window> so Svelte owns the lifecycle: exactly one listener,
  // removed on destroy. The manual add/remove pair leaked one listener per Escape-close and
  // was armed twice by the trigger's on:click plus on:focus.
  function onWindowKeydown(event: KeyboardEvent) {
    if (event.key === 'Escape' && modalOpen) {
      // Escape means cancel: an unconfirmed destination owner must not survive it
      cancelModal();
    }
  }

  onDestroy(() => {
    // The store outlives this component, so a check still in flight must not commit
    supersedePendingValidation();
  });

  $: modalOpenChange(modalOpen);

  let destOwnerDraft: string | undefined = undefined;
  $: syncDraft(destOwnerDraft);

  $: confirmDisabled = !canConfirmDestOwner({
    draft: destOwnerDraft,
    validated,
    destChainId: $destNetwork?.id ?? null,
    invalidAddress,
    isSmartContract: destOwnerIsSmartContract,
    validating,
  });

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
              bind:ethereumAddress={destOwnerDraft}
              on:addressvalidation={onAddressValidation}
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
            <ActionButton priority="primary" disabled={confirmDisabled} on:click={closeModal} onPopup>
              <span class="body-bold">{$t('common.confirm')}</span>
            </ActionButton>
          </div>
        </div>
      </div>
    </dialog>
  {/if}
</div>

<svelte:window on:keydown={onWindowKeydown} />
