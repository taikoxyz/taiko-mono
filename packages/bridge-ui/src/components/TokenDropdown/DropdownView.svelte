<script lang="ts">
  import { deepEqual } from '@wagmi/core';
  import { createEventDispatcher, onDestroy, onMount } from 'svelte';
  import { t } from 'svelte-i18n';
  import type { Address } from 'viem';

  import { DialogTabs } from '$components/DialogTabs';
  import { Icon } from '$components/Icon';
  import Erc20 from '$components/Icon/ERC20.svelte';
  import InputBox from '$components/InputBox/InputBox.svelte';
  import { OnAccount } from '$components/OnAccount';
  import { closeOnEscapeOrOutsideClick } from '$libs/customActions';
  import { tokenService } from '$libs/storage/services';
  import type { NFT, Token } from '$libs/token';
  import { classNames } from '$libs/util/classNames';
  import { noop } from '$libs/util/noop';
  import { truncateString } from '$libs/util/truncateString';
  import { account } from '$stores/account';

  import AddCustomErc20 from './AddCustomERC20.svelte';
  import { symbolToIconMap } from './symbolToIconMap';
  import { TabTypes, TokenTabs } from './types';

  export let id: string;
  export let menuOpen = false;
  export let closeMenu: () => void = () => {
    noop();
  };
  export let tokens: Token[] = [];
  export let customTokens: Token[] = [];
  export let value: Maybe<Token | NFT> = null;
  export let selectToken: (token: Token) => void = noop;
  export let onlyMintable: boolean = false;

  export let activeTab: TabTypes = TabTypes.TOKEN;

  const dispatch = createEventDispatcher();

  const handleCloseMenu = () => {
    enteredTokenName = '';
    closeMenu();
  };

  let addArc20ModalOpen = false;

  const getTokenKeydownHandler = (token: Token) => {
    return (event: KeyboardEvent) => {
      if (event.key === 'Enter') {
        selectToken(token);
      }
    };
  };

  const showAddERC20 = () => dispatch('openCustomTokenModal');

  const handleStorageChange = (newTokens: Token[]) => {
    customTokens = newTokens;
  };

  const onAccountChange = () => {
    if ($account?.address) {
      customTokens = tokenService.getTokens($account?.address as Address);
    }
  };

  const handleTabChange = (event: CustomEvent) => {
    activeTab = event.detail.tabId;
  };

  const searchToken = (event: Event) => {
    enteredTokenName = (event.target as HTMLInputElement).value;
  };

  const removeToken = async (token: Token) => {
    dispatch('tokenRemoved', { token });
  };

  $: filteredCustomTokens = [] as Token[];
  $: filteredTokens = [] as Token[];
  $: enteredTokenName = '';

  $: if (enteredTokenName !== '') {
    filteredTokens = tokens.filter((token) => {
      return (
        token.name.toLowerCase().includes(enteredTokenName.toLowerCase()) ||
        token.symbol.toLowerCase().includes(enteredTokenName.toLowerCase())
      );
    });
    filteredCustomTokens = customTokens.filter((token) => {
      return (
        token.name.toLowerCase().includes(enteredTokenName.toLowerCase()) ||
        token.symbol.includes(enteredTokenName.toLowerCase())
      );
    });
  } else {
    filteredTokens = tokens;
    filteredCustomTokens = customTokens;
  }

  $: menuClasses = classNames(
    'menu absolute right-0 w-[244px] p-3 mt-2 rounded-[10px] bg-neutral-background z-10  box-shadow-small',
    menuOpen ? 'visible opacity-100' : 'invisible opacity-0',
  );

  onMount(() => {
    tokenService.subscribeToChanges(handleStorageChange);
  });

  onDestroy(() => {
    tokenService.unsubscribeFromChanges(handleStorageChange);
  });
</script>

<!-- Desktop (or larger) view -->
<div
  {id}
  class={menuClasses}
  use:closeOnEscapeOrOutsideClick={{ enabled: menuOpen, callback: handleCloseMenu, uuid: id }}>
  <DialogTabs tabs={TokenTabs} bind:activeTab on:change={handleTabChange} />

  <InputBox
    {id}
    type="text"
    placeholder={$t('common.search_token')}
    bind:value={enteredTokenName}
    on:input={searchToken}
    class="p-[12px] my-[20px]" />
  <ul role="listbox" {id} class="gap-2 overflow-y-scroll h-[180px]">
    {#if activeTab === TabTypes.TOKEN}
      {#each filteredTokens as t (t.symbol)}
        {@const selected = deepEqual(t, value)}
        <li
          role="option"
          tabindex="0"
          aria-selected={selected}
          class="rounded-[10px] my-[8px]"
          class:bg-tertiary-interactive-accent={selected}
          on:click={() => selectToken(t)}
          on:keydown={getTokenKeydownHandler(t)}>
          <div class="p-4">
            <!-- Only match icons to configurd tokens -->
            {#if symbolToIconMap[t.symbol] && !t.imported}
              <i role="img" aria-label={t.name}>
                <svelte:component this={symbolToIconMap[t.symbol]} size={28} />
              </i>
            {:else if t.logoURI}
              <img src={t.logoURI} alt={t.name} class="w-[28px] h-[28px] rounded-[50%]" />
            {:else}
              <i role="img" aria-label={t.symbol}>
                <svelte:component this={Erc20} size={28} />
              </i>
            {/if}
            <span class="body-bold">{t.symbol}</span>
          </div>
        </li>
      {/each}
    {:else if activeTab === TabTypes.CUSTOM}
      {#if !onlyMintable}
        {#each filteredCustomTokens as ct, index (index)}
          <li>
            <div class="p-4 flex">
              <i
                role="option"
                tabindex="0"
                aria-selected={ct === value}
                on:click={() => selectToken(ct)}
                on:keydown={getTokenKeydownHandler(ct)}
                aria-label={ct.name}>
                <Erc20 />
              </i>
              <span
                role="option"
                aria-selected={ct === value}
                tabindex="-1"
                on:click={() => selectToken(ct)}
                on:keydown={getTokenKeydownHandler(ct)}
                class="grow body-bold">{truncateString(ct.symbol, 10)}</span>
              <div
                role="button"
                tabindex="-1"
                on:click={() => removeToken(ct)}
                on:keydown={getTokenKeydownHandler(ct)}
                class="cursor-pointer">
                <Icon type="trash" size={25} fillClass="fill-primary-icon" />
              </div>
            </div>
          </li>
        {/each}

        <div class="h-sep my-[8px]" />
        <li>
          <button on:click={showAddERC20} class="flex hover:bg-dark-5 justify-center items-center rounded-lg h-[64px]">
            <Icon type="plus-circle" fillClass="fill-primary-icon" size={32} vWidth={28} vHeight={28} />
            <span
              class="
            body-bold
            bg-transparent
            flex-1
            px-0">
              {$t('token_dropdown.add_custom')}
            </span>
          </button>
        </li>
      {/if}
    {/if}
  </ul>
</div>
<AddCustomErc20 bind:modalOpen={addArc20ModalOpen} on:tokenRemoved />

<OnAccount change={onAccountChange} />
