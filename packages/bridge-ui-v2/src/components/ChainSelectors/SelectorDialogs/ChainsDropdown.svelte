<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import type { Chain } from 'viem';

  import { chainConfig } from '$chainConfig';
  import { chains } from '$libs/chain';
  import { closeOnClickOrEscape } from '$libs/customActions';
  import { classNames } from '$libs/util/classNames';
  import { connectedSourceChain } from '$stores/network';

  export let isOpen: boolean;
  export let value: Maybe<Chain> = null;

  export let switchWallet = false;
  $: isDestination = !switchWallet;

  const dispatch = createEventDispatcher();

  const closeDropDown = () => (isOpen = false);

  function selectChain(chain: Chain, switchWallet: boolean) {
    if (chain.id === value?.id) return;
    dispatch('change', { chain, switchWallet });
    closeDropDown();
  }

  function getChainKeydownHandler(chain: Chain) {
    return (event: KeyboardEvent) => {
      if (event.key === 'Enter') {
        selectChain(chain, isDestination);
      }
    };
  }

  $: menuClasses = classNames(
    `menu absolute right-0 w-full p-3 z-30 ${
      isDestination ? 'mt-0' : 'mt-1'
    }  rounded-b-[10px] bg-neutral-background box-shadow-large`,
    isOpen ? 'visible opacity-100' : 'invisible opacity-0',
    $$props.class,
  );
</script>

<div class={menuClasses}>
  <ul
    role="listbox"
    class="text-primary-content text-sm"
    use:closeOnClickOrEscape={{ enabled: isOpen, callback: () => (isOpen = false) }}>
    {#each chains as chain (chain.id)}
      {@const disabled = (isDestination && chain.id === $connectedSourceChain?.id) || chain.id === value?.id}
      {@const icon = chainConfig[Number(chain.id)]?.icon || 'Unknown Chain'}
      <li
        role="menuitem"
        tabindex="0"
        class="rounded-[10px] {disabled
          ? 'opacity-20 pointer-events-none'
          : 'hover:bg-secondary-interactive-hover cursor-pointer'}"
        aria-disabled={disabled}
        on:click={() => {
          if (!disabled) selectChain(chain, !isDestination);
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
