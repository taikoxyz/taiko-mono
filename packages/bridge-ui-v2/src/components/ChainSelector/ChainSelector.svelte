<script lang="ts">
  import { type Chain, type GetNetworkResult, switchNetwork } from '@wagmi/core';
  import { onDestroy } from 'svelte';
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';
  import { SwitchChainError, UserRejectedRequestError } from 'viem';

  import { chainConfig } from '$chainConfig';
  import { CloseButton } from '$components/CloseButton';
  import { LoadingMask } from '$components/LoadingMask';
  import { warningToast } from '$components/NotificationToast';
  import { chains } from '$libs/chain';
  import { classNames } from '$libs/util/classNames';
  import { truncateString } from '$libs/util/truncateString';
  import { uid } from '$libs/util/uid';
  import { account } from '$stores/account';

  export let label = '';
  export let value: Maybe<GetNetworkResult['chain']> = null;
  export let switchWallet = false;
  export let readOnly = false;
  export let small = false;
  export let validOptions: Maybe<Chain[]> = chains;

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

  const dispatch = createEventDispatcher();

  let classes = classNames('ChainSelector', $$props.class);
  let buttonClasses = classNames(
    'body-regular bg-neutral-background',
    small ? 'px-2 py-[6px]' : 'px-[24px] py-[10px]',
    small ? 'rounded-md' : 'rounded-[10px]',
    small ? 'w-auto' : 'w-full',
    readOnly ? '' : 'dark:hover:bg-tertiary-interactive-hover',
    'flex justify-start content-center',
  );

  let iconSize = small ? 'w-5 h-5' : 'w-7 h-7';

  let switchingNetwork = false;
  let buttonId = `button-${uid()}`;
  let dialogId = `dialog-${uid()}`;
  let modalOpen = false;

  function closeModal() {
    removeEscKeyListener();
    modalOpen = false;
  }

  async function openModal() {
    if (readOnly) return;
    // We want to inform the user that they need to connect
    // their wallet if they want to change the network
    if (!$account.isConnected) {
      warningToast({title: $t('messages.account.required')});
      return;
    }
    addEscKeyListener();
    modalOpen = true;
  }

  async function selectChain(chain: Chain) {
    if (chain.id === value?.id) return;

    dispatch('change', chain.id);

    if (switchWallet) {
      // We want to switch the wallet to the selected network.
      // This will trigger the network switch in the UI also
      switchingNetwork = true;

      try {
        await switchNetwork({ chainId: chain.id });
        closeModal();
      } catch (err) {
        console.error(err);
        if (err instanceof SwitchChainError) {
          warningToast({title: $t('messages.network.pending')});
        }
        if (err instanceof UserRejectedRequestError) {
          warningToast({title: $t('messages.network.rejected')});
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
            <img src={icon} alt="chain-logo" class="rounded-full {iconSize}" />
          </i>
          <span>{truncateString(value.name, 8)}</span>
        {/if}
      </div>
    </button>
  </div>

  <dialog id={dialogId} class="modal modal-bottom md:modal-middle" class:modal-open={modalOpen}>
    <div class="modal-box relative px-6 py-[35px] md:py-[20px] bg-neutral-background text-primary-content">
      {#if switchingNetwork}
        <LoadingMask spinnerClass="border-white" text={$t('messages.network.switching')} />
      {/if}

      <CloseButton onClick={closeModal} />
      <div class="w-full">
        <h3 class="title-body-bold mb-[20px]">
          {#if switchWallet}
            {$t('chain_selector.from_placeholder')}
          {:else}
            {$t('chain_selector.to_placeholder')}
          {/if}
        </h3>
        <ul role="menu">
          {#each chains as chain (chain.id)}
            {@const disabled =
              (validOptions ? !validOptions.some((validOption) => validOption.id === chain.id) : true) ||
              chain.id === value?.id}
            {@const icon = chainConfig[Number(chain.id)]?.icon || 'Unknown Chain'}
            <li
              role="menuitem"
              tabindex="0"
              class="p-4 rounded-[10px]"
              class:opacity-20={disabled}
              class:hover:bg-primary-background={!disabled}
              class:hover:cursor-pointer={!disabled}
              aria-disabled={disabled}
              on:click={() => {
                if (!disabled) selectChain(chain);
              }}
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
          <!-- Todo: disabled for now -->
          <!-- {#if !small}
            <li role="menuitem" tabindex="0" class="p-4 rounded-[10px]">
              <Alert type="warning" forceColumnFlow>
                <p class="font-bold">{$t('chain_selector.disabled_options.title')}</p>
                <p>{$t('chain_selector.disabled_options.description')}</p>
              </Alert>
            </li>
          {/if} -->
        </ul>
      </div>
    </div>
  </dialog>
</div>
