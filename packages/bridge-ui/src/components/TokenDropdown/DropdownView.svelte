<script lang="ts">
  import { onDestroy, onMount } from 'svelte';
  import { t } from 'svelte-i18n';
  import type { Address } from 'viem';

  import { Icon } from '$components/Icon';
  import Erc20 from '$components/Icon/ERC20.svelte';
  import InputBox from '$components/InputBox/InputBox.svelte';
  import { OnAccount } from '$components/OnAccount';
  import { closeOnEscapeOrOutsideClick } from '$libs/customActions';
  import { tokenService } from '$libs/storage/services';
  import type { Token } from '$libs/token';
  import { classNames } from '$libs/util/classNames';
  import { noop } from '$libs/util/noop';
  import { truncateString } from '$libs/util/truncateString';
  import { account } from '$stores/account';

  import AddCustomErc20 from './AddCustomERC20.svelte';
  import { symbolToIconMap } from './symbolToIconMap';

  export let id: string;
  export let menuOpen = false;
  export let closeMenu: () => void = () => {
    noop();
  };
  export let tokens: Token[] = [];
  export let customTokens: Token[] = [];
  export let value: Maybe<Token> = null;
  export let selectToken: (token: Token) => void = noop;
  export let onlyMintable: boolean = false;

  const handleCloseMenu = () => {
    enteredTokenName = '';
    closeMenu();
  };
  enum TokenTabs {
    TOKEN,
    CUSTOM,
  }
  let addArc20ModalOpen = false;

  const getTokenKeydownHandler = (token: Token) => {
    return (event: KeyboardEvent) => {
      if (event.key === 'Enter') {
        selectToken(token);
      }
    };
  };

  const showAddERC20 = () => (addArc20ModalOpen = true);

  const handleStorageChange = (newTokens: Token[]) => {
    customTokens = newTokens;
  };

  const onAccountChange = () => {
    if ($account?.address) {
      customTokens = tokenService.getTokens($account?.address as Address);
    }
  };

  let activeTab = TokenTabs.TOKEN;
  function setActiveTab(tab: TokenTabs) {
    activeTab = tab;
  }

  const searchToken = (event: Event) => {
    enteredTokenName = (event.target as HTMLInputElement).value;
  };

  const removeToken = async (token: Token) => {
    const address = $account.address;
    tokenService.removeToken(token, address as Address);
    customTokens = tokenService.getTokens(address as Address);
  };

  $: filteredCustomTokens = [] as Token[];
  $: filteredTokens = [] as Token[];
  $: enteredTokenName = '';

  $: if (enteredTokenName !== '') {
    filteredTokens = tokens.filter((token) => {
      return token.name.includes(enteredTokenName) || token.symbol.includes(enteredTokenName);
    });
    filteredCustomTokens = customTokens.filter((token) => {
      return token.name.includes(enteredTokenName) || token.symbol.includes(enteredTokenName);
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
  $: 'tab-active !border-primary-brand !border-b-4';
</script>

<!-- Desktop (or larger) view -->
<div
  {id}
  class={menuClasses}
  use:closeOnEscapeOrOutsideClick={{ enabled: menuOpen, callback: handleCloseMenu, uuid: id }}>
  <div role="tablist" class="relative tabs tabs-bordered f-row align-left">
    <button
      role="tab"
      aria-selected={activeTab === TokenTabs.TOKEN}
      class:tab-active={activeTab === TokenTabs.TOKEN}
      class={classNames("tab !border-color-red'", activeTab === TokenTabs.TOKEN ? 'tab-active ' : '')}
      on:click={() => setActiveTab(TokenTabs.TOKEN)}>
      <span class="text-secondary-content">Tokens</span>
    </button>
    <button
      role="tab"
      aria-selected={activeTab === TokenTabs.CUSTOM}
      class:tab-active={activeTab === TokenTabs.CUSTOM}
      class={classNames(" tab box-content'", activeTab === TokenTabs.CUSTOM ? ' tab-active' : '')}
      on:click={() => setActiveTab(TokenTabs.CUSTOM)}>
      <span class="text-secondary-content"> Custom</span>
    </button>
    <div class="absolut w-full border-b-[1px] box-border border-tertiary-content mb-[2px]" />
  </div>
  <div>
    <InputBox
      {id}
      type="text"
      placeholder={$t('common.search_token')}
      bind:value={enteredTokenName}
      on:input={searchToken}
      class="p-[12px] my-[20px]" />
    <ul role="listbox" {id}>
      {#if activeTab === TokenTabs.TOKEN}
        {#each filteredTokens as t (t.symbol)}
          <li
            role="option"
            tabindex="0"
            aria-selected={t === value}
            on:click={() => selectToken(t)}
            on:keydown={getTokenKeydownHandler(t)}>
            <div class="p-4">
              <!-- Only match icons to configurd tokens -->
              {#if symbolToIconMap[t.symbol] && !t.imported}
                <i role="img" aria-label={t.name}>
                  <svelte:component this={symbolToIconMap[t.symbol]} size={28} />
                </i>
              {:else}
                <i role="img" aria-label={t.symbol}>
                  <svelte:component this={Erc20} size={28} />
                </i>
              {/if}
              <span class="body-bold">{t.symbol}</span>
            </div>
          </li>
        {/each}
      {:else if !onlyMintable}
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
    </ul>
  </div>
</div>
<AddCustomErc20 bind:modalOpen={addArc20ModalOpen} on:tokenRemoved />

<OnAccount change={onAccountChange} />

<style>
  .tab {
    box-sizing: border-box !important;
    padding-bottom: 6px;
  }
  .tab:not(.tab-active) {
    border-color: var(--tertiary-content) !important;
    border-bottom: 1px solid;
    margin-bottom: 2px;
    padding-top: 2px;
  }
  .tab-active {
    border-bottom: 4px solid;
    border-color: var(--primary-brand) !important;
    padding-bottom: 4px;
  }
</style>
