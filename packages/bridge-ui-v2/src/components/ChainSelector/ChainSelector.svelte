<script lang="ts">
  import { type Chain, type GetNetworkResult, switchNetwork } from '@wagmi/core';
  import type { ComponentType } from 'svelte';
  import { onDestroy } from 'svelte/internal';
  import { t } from 'svelte-i18n';
  import { UserRejectedRequestError } from 'viem';

  import { EthIcon, Icon, TaikoIcon } from '$components/Icon';
  import { LoadingMask } from '$components/LoadingMask';
  import { warningToast } from '$components/NotificationToast';
  import { PUBLIC_L1_CHAIN_ID, PUBLIC_L2_CHAIN_ID } from '$env/static/public';
  import { chains } from '$libs/chain';
  import { uid } from '$libs/util/uid';
  import { account } from '$stores/account';

  export let label: string;
  export let value: Maybe<GetNetworkResult['chain']> = null;
  export let switchWallet = false;
  export let readOnly = false;

  let chainToIconMap: Record<string, ComponentType> = {
    [PUBLIC_L1_CHAIN_ID]: EthIcon,
    [PUBLIC_L2_CHAIN_ID]: TaikoIcon,
  };

  let switchingNetwork = false;
  let buttonId = `button-${uid()}`;
  let dialogId = `dialog-${uid()}`;
  let modalOpen = false;

  function closeModal() {
    modalOpen = false;
  }

  function openModal() {
    if (readOnly) return;

    // We want to inform the user that they need to connect
    // their wallet if they want to change the network
    if (!$account.isConnected) {
      warningToast($t('messages.account.required'));
      return;
    }

    modalOpen = true;
  }

  async function selectChain(chain: Chain) {
    if (chain.id === value?.id) return;

    if (switchWallet) {
      // We want to switch the wallet to the selected network.
      // This will trigger the network switch in the UI also
      switchingNetwork = true;

      try {
        await switchNetwork({ chainId: chain.id });
        closeModal();
      } catch (err) {
        console.error(err);

        if (err instanceof UserRejectedRequestError) {
          warningToast($t('messages.network.rejected'));
        }
      } finally {
        switchingNetwork = false;
      }
    } else {
      value = chain;
      closeModal();
    }
  }

  function getChainKeydownHandler(chain: Chain) {
    return (event: KeyboardEvent) => {
      if (event.key === 'Enter') {
        selectChain(chain);
      }
    };
  }

  onDestroy(closeModal);
</script>

<div class="ChainSelector">
  <div class="f-items-center space-x-[10px]">
    <label class="text-secondary-content body-regular" for={buttonId}>{label}:</label>
    <button
      id={buttonId}
      type="button"
      disabled={readOnly}
      aria-haspopup="dialog"
      aria-controls={dialogId}
      aria-expanded={modalOpen}
      class="px-2 py-[6px] body-small-regular bg-neutral-background rounded-md"
      on:click={openModal}>
      <div class="f-items-center space-x-2">
        {#if !value}
          <span>{$t('chain_selector.placeholder')}</span>
        {/if}
        {#if value}
          <i role="img" aria-label={value.name}>
            <svelte:component this={chainToIconMap[value.id]} size={20} />
          </i>
          <span>{value.name}</span>
        {/if}
      </div>
    </button>
  </div>

  <dialog id={dialogId} class="modal modal-bottom md:modal-middle" class:modal-open={modalOpen}>
    <div class="modal-box relative px-6 py-[35px] md:py-[20px] bg-primary-base-background text-primary-base-content">
      {#if switchingNetwork}
        <LoadingMask
          class="bg-grey-0/60"
          spinnerClass="border-primary-base-content"
          text={$t('messages.network.switching')} />
      {/if}

      <button class="absolute right-6 top-[35px] md:top-[20px]" on:click={closeModal}>
        <Icon type="x-close" fillClass="fill-secondary-icon" size={24} />
      </button>
      <h3 class="title-body-bold mb-[20px]">{$t('chain_selector.placeholder')}</h3>
      <ul role="menu" class="space-y-4">
        {#each chains as chain (chain.id)}
          {@const disabled = chain.id === value?.id}
          <li
            role="menuitem"
            tabindex="0"
            class="p-4 rounded-[10px]"
            class:opacity-20={disabled}
            class:hover:bg-grey-10={!disabled}
            class:hover:cursor-pointer={!disabled}
            aria-disabled={disabled}
            on:click={() => selectChain(chain)}
            on:keydown={getChainKeydownHandler(chain)}>
            <!-- TODO: agree on hover:bg color -->
            <div class="f-row justify-between">
              <div class="f-items-center space-x-4">
                <i role="img" aria-label={chain.name}>
                  <svelte:component this={chainToIconMap[chain.id]} size={32} />
                </i>
                <span class="body-bold">{chain.name}</span>
              </div>
              <span class="body-regular">{chain.network}</span>
            </div>
          </li>
        {/each}
      </ul>
    </div>
  </dialog>
</div>
