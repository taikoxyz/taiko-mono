<script lang="ts">
  import { type Chain, type GetNetworkResult, switchNetwork } from '@wagmi/core';
  import { onDestroy, onMount } from 'svelte';
  import { t } from 'svelte-i18n';
  import { UserRejectedRequestError } from 'viem';

  import { chainConfig } from '$chainConfig';
  import { destNetwork } from '$components/Bridge/state';
  import { Icon } from '$components/Icon';
  import { LoadingMask } from '$components/LoadingMask';
  import { warningToast } from '$components/NotificationToast';
  import { chains } from '$libs/chain';
  import { classNames } from '$libs/util/classNames';
  import { getConnectedWallet } from '$libs/util/getConnectedWallet';
  import { uid } from '$libs/util/uid';
  import { account } from '$stores/account';

  export let label = '';
  export let value: Maybe<GetNetworkResult['chain']> = null;
  export let switchWallet = false;
  export let readOnly = false;
  export let small = false;

  let classes = classNames('ChainSelector', $$props.class);
  let buttonClasses = classNames(
    'body-regular bg-neutral-background',
    small ? 'px-2 py-[6px]' : 'px-6 py-[10px]',
    small ? 'rounded-md' : 'rounded-[10px]',
    small ? 'w-auto' : 'w-full',
    readOnly ? '' : 'hover:bg-tertiary-interactive-hover',
    'flex justify-start content-center body-bold py-2 px-[20px]',
  );

  let switchingNetwork = false;
  let buttonId = `button-${uid()}`;
  let dialogId = `dialog-${uid()}`;
  let modalOpen = false;
  let srcChainId: Maybe<number> = null;

  function closeModal() {
    modalOpen = false;
  }

  async function openModal() {
    if (readOnly) return;
    const wallet = await getConnectedWallet();
    srcChainId = await wallet.getChainId();
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

<div class={classes}>
  <div class="f-items-center space-x-[10px]">
    {#if label}
      <label class="text-secondary-content body-regular" for={buttonId}>{label}:</label>
    {/if}

    <button
      id={buttonId}
      type="button"
      disabled={readOnly}
      aria-haspopup="dialog"
      aria-controls={dialogId}
      aria-expanded={modalOpen}
      class={buttonClasses}
      on:click={openModal}>
      <div class="{small ? 'f-items-center' : 'f-center'} space-x-2 w-full">
        {#if !value}
          <span>{$t('chain_selector.placeholder')}</span>
        {/if}
        {#if value}
          {@const icon = chainConfig[Number(value.id)]?.icon || 'Unknown Chain'}
          <i role="img" aria-label={value.name}>
            <img src={icon} alt="chain-logo" class="rounded-full w-6 h-6" />
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
      <ul role="menu">
        {#each chains as chain (chain.id)}
          {@const disabled =
            chain.id === value?.id ||
            (chain.id === srcChainId && chain.id !== $destNetwork?.id) ||
            (chain.id === $destNetwork?.id && chain.id !== srcChainId)}
          {@const icon = chainConfig[Number(chain.id)]?.icon || 'Unknown Chain'}
          <li
            role="menuitem"
            tabindex="0"
            class="p-4 rounded-[10px]"
            class:opacity-20={disabled}
            class:hover:bg-primary-content={!disabled}
            class:hover:cursor-pointer={!disabled}
            aria-disabled={disabled}
            on:click={() => selectChain(chain)}
            on:keydown={getChainKeydownHandler(chain)}>
            <!-- TODO: agree on hover:bg color -->
            <div class="f-row justify-between">
              <div class="f-items-center space-x-4">
                <i role="img" aria-label={chain.name}>
                  <img src={icon} alt="chain-logo" class="rounded-full w-7 h-7" />
                </i>
                <span class="body-bold">{chain.name}</span>
              </div>
              <span class="f-items-center body-regular">{chainConfig[chain.id].type}</span>
            </div>
          </li>
        {/each}
      </ul>
    </div>
  </dialog>
</div>
