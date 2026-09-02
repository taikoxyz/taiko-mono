<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';
  import type { Chain } from 'viem';

  import { chainConfig } from '$chainConfig';
  import { destNetwork } from '$components/Bridge/state';
  import { CloseButton } from '$components/Button';
  import { ActionButton } from '$components/Button';
  import { chains } from '$libs/chain';
  import { closeOnEscapeOrOutsideClick } from '$libs/customActions';
  import { connectedSourceChain } from '$stores/network';

  export let isOpen = false;
  export let value: Maybe<Chain> = null;
  export let switchWallet = false;

  let modalOpen = false;
  const dialogId = `dialog-${crypto.randomUUID()}`;

  const dispatch = createEventDispatcher();

  $: isDestination = !switchWallet;

  $: title = isDestination ? $t('chain_selector.to_placeholder') : $t('chain_selector.from_placeholder');

  let selectedChainId: number | undefined;

  // The picked chain stays local until Confirm: writing it to `value` immediately would
  // show an unconfirmed chain in the pill, even when the dialog is dismissed or the
  // wallet switch is rejected afterwards
  let pendingChain: Maybe<Chain> = null;

  const selectChain = (selectedChain: Chain) => (pendingChain = selectedChain);

  const closeModal = () => {
    modalOpen = false;
    isOpen = false;
  };

  const onConfirmClick = () => {
    if (pendingChain) {
      dispatch('change', { chain: pendingChain, switchWallet });
    }
    closeModal();
  };

  // The reset belongs to the moment the dialog opens, not to every change of `value`: a
  // reactive block referencing both re-ran on a wallet-side chain change while the dialog
  // was open, discarding the chain the user had just picked
  let wasOpen = false;
  $: if (isOpen !== wasOpen) {
    wasOpen = isOpen;
    if (isOpen) {
      pendingChain = null;
      selectedChainId = value?.id;
      modalOpen = true;
    } else {
      closeModal();
    }
  }
</script>

<dialog
  id={dialogId}
  class="modal modal-bottom"
  class:modal-open={modalOpen}
  use:closeOnEscapeOrOutsideClick={{ enabled: isOpen, callback: () => (isOpen = false), uuid: dialogId }}>
  <div class="modal-box relative px-[24px] py-[35px] rounded-0 bg-neutral-background">
    <CloseButton onClick={closeModal} />
    <div class="f-col w-full space-y-[30px]">
      <h3 class="title-body-bold">{title}</h3>
    </div>
    <div class="h-sep !my-[20px]" />
    <ul role="listbox" class="text-white text-sm w-full">
      {#each chains as chain (chain.id)}
        {@const disabled = !isDestination
          ? chain.id === $connectedSourceChain?.id
          : chain.id === $destNetwork?.id || chain.id === $connectedSourceChain?.id}
        {@const icon = chainConfig[Number(chain.id)]?.icon || 'Unknown Chain'}
        <li
          role="menuitem"
          tabindex="0"
          class="h-[64px] rounded-[10px] text-primary-content
          {disabled ? 'opacity-50' : 'hover:bg-primary-brand hover:text-white'}"
          aria-disabled={disabled}>
          <label class="f-row items-center w-full h-full p-[16px] {disabled ? 'cursor-not-allowed' : 'cursor-pointer'}">
            <input
              type="radio"
              name="nft-radio"
              bind:group={selectedChainId}
              value={chain.id}
              class="flex-none mr-[8px] radio radio-secondary"
              {disabled}
              on:change={() => selectChain(chain)} />
            <div class="f-row justify-between w-full">
              <div class="f-items-center gap-2">
                <i role="img" aria-label={chain.name}>
                  <img src={icon} alt="chain-logo" class="rounded-full w-7 h-7" />
                </i>
                <span class="body-bold">{chain.name}</span>
              </div>

              <span class="f-items-center body-regular">{chainConfig[chain.id].type}</span>
            </div>
          </label>
        </li>
      {/each}
    </ul>
    <div class="h-sep !my-[20px]" />
    <ActionButton priority="primary" on:click={() => onConfirmClick()}>
      {$t('common.confirm')}
    </ActionButton>
  </div>

  <button class="overlay-backdrop" data-modal-uuid={dialogId} />
</dialog>
