<script lang="ts">
  import { deepEqual } from '@wagmi/core';
  import { createEventDispatcher, onDestroy, onMount } from 'svelte';
  import { t } from 'svelte-i18n';
  import type { Address } from 'viem';

  import { CloseButton } from '$components/Button';
  import { DialogTabs } from '$components/DialogTabs';
  import { Icon } from '$components/Icon';
  import Erc20 from '$components/Icon/ERC20.svelte';
  import { InputBox } from '$components/InputBox';
  import { OnAccount } from '$components/OnAccount';
  import { closeOnEscapeOrOutsideClick } from '$libs/customActions';
  import { tokenService } from '$libs/storage/services';
  import type { NFT, Token } from '$libs/token';
  import { noop } from '$libs/util/noop';
  import { truncateString } from '$libs/util/truncateString';
  import { account } from '$stores/account';

  import { symbolToIconMap } from './symbolToIconMap';
  import { TabTypes, TokenTabs } from './types';

  export let id: string;
  export let tokens: Token[] = [];
  export let customTokens: Token[] = [];
  export let value: Maybe<Token | NFT> = null;
  export let menuOpen = false;
  export let onlyMintable: boolean = false;
  export let selectToken: (token: Token) => void = noop;
  export let closeMenu: () => void = noop;

  export let activeTab: TabTypes = TabTypes.TOKEN;

  const dispatch = createEventDispatcher();

  const searchToken = (event: Event) => {
    enteredTokenName = (event.target as HTMLInputElement).value;
  };

  const handleTabChange = (event: CustomEvent) => {
    activeTab = event.detail.tabId;
  };

  const showAddERC20 = () => {
    menuOpen = false;
    dispatch('openCustomTokenModal');
  };

  const handleStorageChange = (newTokens: Token[]) => {
    customTokens = newTokens;
  };

  const onAccountChange = () => {
    if ($account?.address) {
      customTokens = tokenService.getTokens($account?.address as Address);
    }
  };

  const removeToken = async (token: Token) => {
    dispatch('tokenRemoved', { token });
  };

  const getTokenKeydownHandler = (token: Token) => {
    return (event: KeyboardEvent) => {
      if (event.key === 'Enter') {
        selectToken(token);
      }
      if (event.key === 'Escape') {
        closeMenu();
      }
    };
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

  onMount(() => tokenService.subscribeToChanges(handleStorageChange));

  onDestroy(() => tokenService.unsubscribeFromChanges(handleStorageChange));
</script>

<!-- Mobile view -->
<dialog
  {id}
  class="modal modal-bottom"
  class:modal-open={menuOpen}
  use:closeOnEscapeOrOutsideClick={{ enabled: menuOpen, callback: closeMenu, uuid: id }}>
  <div class="modal-box relative px-6 py-[35px] w-full bg-neutral-background absolute">
    <CloseButton onClick={closeMenu} />

    <div class="w-full">
      <h3 class="title-body-bold mb-7">{$t('token_dropdown.label')}</h3>

      <DialogTabs tabs={TokenTabs} bind:activeTab on:change={handleTabChange} />

      <InputBox
        {id}
        type="text"
        placeholder={$t('common.search_token')}
        bind:value={enteredTokenName}
        on:input={searchToken}
        class="p-[12px] my-[20px]" />
      <ul role="listbox" class="menu p-0">
        {#if activeTab === TabTypes.TOKEN}
          {#each filteredTokens as token (token.symbol)}
            {@const selected = deepEqual(token, value)}
            <!-- svelte-ignore a11y-click-events-have-key-events -->
            <li
              role="option"
              tabindex="0"
              aria-selected={selected}
              class="rounded-[10px]"
              class:bg-tertiary-interactive-accent={selected}
              on:click={() => selectToken(token)}>
              <div class="p-4">
                {#if symbolToIconMap[token.symbol] && !token.imported}
                  <i role="img" aria-label={token.name}>
                    <svelte:component this={symbolToIconMap[token.symbol]} size={28} />
                  </i>
                {:else if token.logoURI}
                  <img src={token.logoURI} alt={token.name} class="w-[28px] h-[28px] rounded-[50%]" />
                {:else}
                  <i role="img" aria-label={token.symbol}>
                    <svelte:component this={Erc20} size={28} />
                  </i>
                {/if}
                <span class="body-bold">{token.symbol}</span>
              </div>
            </li>
          {/each}
        {:else if activeTab === TabTypes.CUSTOM}
          {#if !onlyMintable}
            {#each filteredCustomTokens as ct, index (index)}
              {@const selected = deepEqual(ct, value)}
              <li
                role="option"
                tabindex="0"
                aria-selected={selected}
                class="rounded-[10px]"
                class:bg-tertiary-interactive-accent={selected}
                on:click={() => selectToken(ct)}
                on:keydown={getTokenKeydownHandler(ct)}>
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
            <li class="f-between-center max-h-[42px]">
              <button
                on:click={showAddERC20}
                class="flex w-full hover:bg-dark-5 justify-center items-center rounded-sm">
                <Icon type="plus-circle" fillClass="fill-primary-icon" />
                <span class=" body-bold bg-transparent flex-1 w-[100px] px-0 pl-2">
                  {$t('token_dropdown.add_custom')}
                </span>
              </button>
            </li>
          {/if}
        {/if}
      </ul>
    </div>
  </div>
  <button class="overlay-backdrop" data-modal-uuid={id} />
</dialog>

<OnAccount change={onAccountChange} />
