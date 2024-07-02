<script lang="ts">
  import { t } from 'svelte-i18n';
  import type { Address } from 'viem';

  import { destNetwork, destOwnerAddress } from '$components/Bridge/state';
  import { ActionButton, CloseButton } from '$components/Button';
  import { isSmartContract } from '$libs/util/isSmartContract';

  // import { account } from '$stores/account';
  import AddressInput from '../AddressInput/AddressInput.svelte';

  export let dialogId = `dialog-${crypto.randomUUID()}`;
  export let modalOpen = false;
  export let invalidAddress = false;
  let prevDestOwnerAddress: Maybe<Address> = null;
  export let recipientIsSmartContract = false;

  let addressInput: AddressInput;

  let escKeyListener: (event: KeyboardEvent) => void;

  // const addEscKeyListener = () => {
  //   escKeyListener = (event: KeyboardEvent) => {
  //     if (event.key === 'Escape') {
  //       closeModal();
  //     }
  //   };
  //   window.addEventListener('keydown', escKeyListener);
  // };

  const removeEscKeyListener = () => {
    window.removeEventListener('keydown', escKeyListener);
  };

  function closeModal() {
    modalOpen = false;
  }

  // function openModal() {
  //   modalOpen = true;
  //   addressInput.focus();
  //   addEscKeyListener();
  // }

  function cancelModal() {
    // Revert change of recipient address
    $destOwnerAddress = prevDestOwnerAddress;
    removeEscKeyListener();
    closeModal();
  }

  //TODO finish modal
  // add modal trigger
  // adjust exports

  function modalOpenChange(open: boolean) {
    if (open) {
      // Save it in case we want to cancel
      prevDestOwnerAddress = $destOwnerAddress;
    }
  }

  async function onAddressValidation(event: CustomEvent<{ isValidEthereumAddress: boolean; addr: Address }>) {
    const { isValidEthereumAddress, addr } = event.detail;
    if (isValidEthereumAddress) {
      $destOwnerAddress = addr;
      invalidAddress = false;
      if ($destNetwork?.id && (await isSmartContract(addr, $destNetwork.id))) {
        recipientIsSmartContract = true;
      } else {
        recipientIsSmartContract = false;
      }
    } else {
      invalidAddress = true;
    }
  }
  $: modalOpenChange(modalOpen);

  $: ethereumAddressBinding = $destOwnerAddress || undefined;
</script>

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
