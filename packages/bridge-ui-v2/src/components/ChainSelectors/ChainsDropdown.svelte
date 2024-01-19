<script lang="ts">
  import { type Chain, type GetNetworkResult, switchNetwork } from '@wagmi/core';
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';
  import { SwitchChainError, UserRejectedRequestError } from 'viem';

  import { chainConfig } from '$chainConfig';
  import { warningToast } from '$components/NotificationToast';
  import { chains } from '$libs/chain';
  import { closeOnEscapeOrOutsideClick } from '$libs/customActions';
  import { classNames } from '$libs/util/classNames';
  import { network } from '$stores/network';

  export let isOpen: boolean;
  export let value: Maybe<GetNetworkResult['chain']> = null;
  export let switchWallet = false;

  export let switchingNetwork = false;

  export let isDest = false;

  const dispatch = createEventDispatcher();

  const closeDropDown = () => {
    isOpen = false;
  };

  async function selectChain(chain: Chain) {
    if (chain.id === value?.id) return;

    dispatch('change', chain.id);

    if (switchWallet) {
      // We want to switch the wallet to the selected network.
      // This will trigger the network switch in the UI also
      switchingNetwork = true;
      closeDropDown();

      try {
        await switchNetwork({ chainId: chain.id });
      } catch (err) {
        console.error(err);
        if (err instanceof SwitchChainError) {
          warningToast({
            title: $t('messages.network.pending.title'),
            message: $t('messages.network.pending.message'),
          });
        }
        if (err instanceof UserRejectedRequestError) {
          warningToast({
            title: $t('messages.network.rejected.title'),
            message: $t('messages.network.rejected.message'),
          });
        }
      } finally {
        switchingNetwork = false;
      }
    } else {
      value = chain;
      closeDropDown();
    }
  }

  function getChainKeydownHandler(chain: Chain) {
    return (event: KeyboardEvent) => {
      if (event.key === 'Enter') {
        selectChain(chain);
      }
    };
  }

  $: menuClasses = classNames(
    `menu absolute right-0 w-full p-3 ${
      isDest ? 'mt-0' : 'mt-1'
    }  rounded-b-[10px] bg-neutral-background z-10  box-shadow-large`,
    isOpen ? 'visible opacity-100' : 'invisible opacity-0',
  );
</script>

<div class={menuClasses}>
  <ul
    role="listbox"
    class="text-white text-sm"
    use:closeOnEscapeOrOutsideClick={{ enabled: isOpen, callback: () => (isOpen = false) }}>
    <!--  -->
    {#each chains as chain (chain.id)}
      {@const disabled = (isDest && chain.id === $network?.id) || chain.id === value?.id}
      {@const icon = chainConfig[Number(chain.id)]?.icon || 'Unknown Chain'}
      <li
        role="menuitem"
        tabindex="0"
        class="rounded-[10px] {disabled
          ? 'opacity-20 pointer-events-none'
          : 'hover:bg-primary-brand hover:cursor-pointer'}"
        aria-disabled={disabled}
        on:click={() => {
          if (!disabled) selectChain(chain);
        }}
        on:keydown={getChainKeydownHandler(chain)}>
        <div class="f-row justify-between">
          <div class="f-items-center gap-2">
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
