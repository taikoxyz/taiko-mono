<script lang="ts">
  import { onDestroy } from 'svelte';
  import { t } from 'svelte-i18n';
  import type { Address } from 'viem';

  import { destNetwork, destOwnerAddress, recipientAddress } from '$components/Bridge/state';
  import { ActionButton, CloseButton } from '$components/Button';
  import { Tooltip } from '$components/Tooltip';
  import { isSmartContract } from '$libs/util/isSmartContract';
  import { shortenAddress } from '$libs/util/shortenAddress';
  import { account } from '$stores/account';

  import AddressInput from '../AddressInput/AddressInput.svelte';
  import { addressesEqual, canConfirmRecipient, type ValidatedRecipient } from './recipientValidation';
  // import Alert from '$components/Alert/Alert.svelte';

  // Public API
  export const clearRecipient = () => {
    if (addressInput) addressInput.clearAddress(); // update UI
    $recipientAddress = null; // update state
    validatedRecipient = null;
    recipientIsSmartContract = false;
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
  let prevDestOwnerAddress: Maybe<Address> = null;

  let recipientIsSmartContract = false;
  // let destOwnerIsSmartContract = false;

  // Classifying a recipient needs an RPC round trip. Until it resolves we do not know
  // whether a destination owner is required, so confirming stays blocked; a superseded
  // or failed lookup must never leave a stale classification behind.
  let validatingRecipient = false;
  let recipientValidationGeneration = 0;
  let pendingRecipientLookup: Maybe<string> = null;

  // What was actually validated, rather than a flag some earlier validation set.
  // AddressInput stays silent for a cleared field and for text without a `0x` prefix, so
  // these are compared against the live drafts before Confirm is enabled.
  let validatedRecipient: Maybe<ValidatedRecipient> = null;
  let validatedDestOwner: Maybe<Address> = null;

  // Snapshot of everything Cancel has to restore
  let prevInvalidRecipient = false;
  let prevInvalidDestOwner = false;
  let prevRecipientIsSmartContract = false;
  let prevValidatedRecipient: Maybe<ValidatedRecipient> = null;
  let prevValidatedDestOwner: Maybe<Address> = null;

  function closeModal() {
    modalOpen = false;
  }

  function openModal() {
    modalOpen = true;
    addressInput.focus();
  }

  /** Discard any in-flight classification so its result cannot be committed later */
  function supersedePendingValidation() {
    recipientValidationGeneration++;
    pendingRecipientLookup = null;
    validatingRecipient = false;
  }

  /** Whether the stored classification still describes the live recipient and chain */
  function recipientClassificationIsCurrent(): boolean {
    return (
      !!validatedRecipient &&
      addressesEqual(validatedRecipient.address, $recipientAddress) &&
      validatedRecipient.chainId === $destNetwork?.id
    );
  }

  function cancelModal() {
    supersedePendingValidation();

    // Revert to the state the dialog was opened with, including a previously configured
    // destOwner and the validation flags, so reopening does not show stale controls
    $recipientAddress = prevRecipientAddress;
    $destOwnerAddress = prevDestOwnerAddress;
    invalidRecipient = prevInvalidRecipient;
    invalidDestOwner = prevInvalidDestOwner;
    recipientIsSmartContract = prevRecipientIsSmartContract;
    // The snapshot was taken before a destination-chain change could invalidate it;
    // restoring a classification for a chain we no longer bridge to would make the
    // dialog skip reclassification on reopen while the predicate rejects the mismatch
    validatedRecipient =
      prevValidatedRecipient && prevValidatedRecipient.chainId === $destNetwork?.id ? prevValidatedRecipient : null;
    validatedDestOwner = prevValidatedDestOwner;

    // Assigning a store the value it already holds emits no update, so the reactive
    // bindings below would not re-run and the discarded draft would stay on screen.
    // Restore the local drafts and the inputs themselves explicitly.
    ethereumAddressBinding = prevRecipientAddress ?? undefined;
    destOwnerAddressBinding = prevDestOwnerAddress ?? undefined;
    addressInput?.setAddress(prevRecipientAddress ?? '');
    destOwnerAddressInput?.setAddress(prevDestOwnerAddress ?? '');

    closeModal();
  }

  function modalOpenChange(open: boolean) {
    if (open) {
      // Save them in case we want to cancel
      prevRecipientAddress = $recipientAddress;
      prevDestOwnerAddress = $destOwnerAddress;
      prevInvalidRecipient = invalidRecipient;
      prevInvalidDestOwner = invalidDestOwner;
      prevRecipientIsSmartContract = recipientIsSmartContract;
      prevValidatedRecipient = validatedRecipient;
      prevValidatedDestOwner = validatedDestOwner;

      // AddressInput only dispatches validation on user input, so a pre-filled recipient
      // would otherwise stay unclassified and could be confirmed on a stale answer.
      // A record that does not describe both the current draft and the current
      // destination chain is no better than none: reclassify rather than sit on it.
      if ($recipientAddress && !recipientClassificationIsCurrent()) {
        validateRecipient($recipientAddress);
      }
    }
  }

  async function onRecipientValidation(event: CustomEvent<{ isValidEthereumAddress: boolean; addr: Address }>) {
    const { isValidEthereumAddress, addr } = event.detail;

    if (isValidEthereumAddress) {
      validateRecipient(addr);
    } else {
      // Supersede any in-flight classification so its result cannot arrive later
      supersedePendingValidation();
      validatedRecipient = null;
      recipientIsSmartContract = false;
      invalidRecipient = true;
    }
  }

  const validateRecipient = async (addr: Address) => {
    const generation = ++recipientValidationGeneration;
    const destChainId = $destNetwork?.id;

    pendingRecipientLookup = addr;
    validatingRecipient = true;
    validatedRecipient = null;

    try {
      if (!destChainId) {
        // Without a destination chain the recipient cannot be classified, so it must not
        // be treated as a plain wallet
        return;
      }

      const isContract = await isSmartContract(addr, destChainId);
      if (generation !== recipientValidationGeneration) return;
      // The destination chain decides whether an address is a contract, so an answer for
      // the chain we no longer bridge to says nothing about the one we do
      if (destChainId !== $destNetwork?.id) return;

      // Commit only once the classification for this exact address succeeded
      $recipientAddress = addr;
      recipientIsSmartContract = isContract;
      validatedRecipient = { address: addr, chainId: destChainId };
      invalidRecipient = false;
    } catch (error) {
      if (generation !== recipientValidationGeneration) return;
      // A failed lookup cannot prove the recipient is claimable; leave it unclassified
      // so Confirm stays blocked rather than silently reusing the previous answer
      console.error('Could not determine whether the recipient is a smart contract', error);
    } finally {
      if (generation === recipientValidationGeneration) {
        validatingRecipient = false;
        pendingRecipientLookup = null;
      }
    }
  };

  async function onDestOwnerValidation(event: CustomEvent<{ isValidEthereumAddress: boolean; addr: Address }>) {
    const { isValidEthereumAddress, addr } = event.detail;
    if (isValidEthereumAddress) {
      validateDestOwner(addr);
    } else {
      validatedDestOwner = null;
      invalidDestOwner = true;
    }
  }

  const validateDestOwner = async (addr: Address) => {
    $destOwnerAddress = addr;
    validatedDestOwner = addr;
    invalidDestOwner = false;
    // if ($destNetwork?.id && (await isSmartContract(addr, $destNetwork.id))) {
    //   destOwnerIsSmartContract = true;
    //   // invalidDestOwner = true;
    // } else {
    //   destOwnerIsSmartContract = false;
    // }
  };

  /**
   * The recipient input changed without necessarily dispatching an event (a cleared field
   * and text without a `0x` prefix stay silent), so the draft itself has to retire an
   * answer that no longer describes it.
   */
  function syncRecipientDraft(draft: Maybe<string>) {
    if (pendingRecipientLookup && !addressesEqual(pendingRecipientLookup, draft)) {
      supersedePendingValidation();
    }
    if (validatedRecipient && !addressesEqual(validatedRecipient.address, draft)) {
      validatedRecipient = null;
      recipientIsSmartContract = false;
    }
  }

  /**
   * The committed store, unlike the local draft, only ever holds an address that passed
   * validation - here, in the separate DestOwner editor, or as the connected wallet. So a
   * change to it carries its own provenance and must restore it, whether it came from a
   * remount, from the other editor, or from its reset-to-wallet path. Watching the store
   * rather than the draft is what keeps an unvalidated draft from promoting itself.
   */
  let lastCommittedDestOwner: Maybe<Address> = undefined;
  function onCommittedDestOwnerChanged(committed: Maybe<Address>) {
    if (lastCommittedDestOwner === committed) return;
    lastCommittedDestOwner = committed;
    validatedDestOwner = committed ?? null;
    if (committed) invalidDestOwner = false;
  }

  function syncDestOwnerDraft(draft: Maybe<string>) {
    if (validatedDestOwner && !addressesEqual(validatedDestOwner, draft)) {
      // $destOwnerAddress is deliberately left alone: rewriting it here would feed back
      // into the binding and wipe what the user is typing. Confirm is gated on the
      // validated value matching the draft, so the stale store value cannot be submitted.
      validatedDestOwner = null;
    }
  }

  let lastDestChainId: Maybe<number> = undefined;
  function onDestChainChanged(chainId: Maybe<number>) {
    if (lastDestChainId === chainId) return;
    lastDestChainId = chainId;
    // Any classification or in-flight lookup belongs to the previous destination chain
    supersedePendingValidation();
    validatedRecipient = null;
    recipientIsSmartContract = false;
  }

  // Declared via <svelte:window> so Svelte owns the lifecycle: exactly one listener per
  // component, removed automatically on destroy even if the dialog is unmounted while open
  function onWindowKeydown(event: KeyboardEvent) {
    if (event.key === 'Escape' && modalOpen) {
      // Escape means cancel: unconfirmed edits must not survive, or an invalid recipient /
      // missing destOwner could slip past the Confirm button's validation
      cancelModal();
    }
  }

  onDestroy(() => {
    // The stores outlive this component, so a lookup still in flight must not commit
    supersedePendingValidation();
  });

  $: modalOpenChange(modalOpen);

  $: ethereumAddressBinding = $recipientAddress || undefined;
  $: destOwnerAddressBinding = $destOwnerAddress || undefined;

  $: syncRecipientDraft(ethereumAddressBinding);
  $: onCommittedDestOwnerChanged($destOwnerAddress);
  $: syncDestOwnerDraft(destOwnerAddressBinding);
  $: onDestChainChanged($destNetwork?.id);

  $: displayedRecipient = $recipientAddress || $account?.address;

  $: confirmDisabled = !canConfirmRecipient({
    recipientDraft: ethereumAddressBinding ?? null,
    destOwnerDraft: destOwnerAddressBinding ?? null,
    validatedRecipient,
    validatedDestOwner,
    destChainId: $destNetwork?.id ?? null,
    invalidRecipient,
    invalidDestOwner,
    recipientIsSmartContract,
    validatingRecipient,
  });
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
