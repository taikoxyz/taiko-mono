<script lang="ts">
  import { onDestroy, onMount } from 'svelte';
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';
  import type { Address } from 'viem';

  import { Icon } from '$components/Icon';
  import Erc20 from '$components/Icon/ERC20.svelte';
  import { OnAccount } from '$components/OnAccount';
  import { tokenService } from '$libs/storage/services';
  import type { Token } from '$libs/token';
  import { noop } from '$libs/util/noop';
  import { account } from '$stores/account';

  import AddCustomErc20 from './AddCustomERC20.svelte';
  import { symbolToIconMap } from './symbolToIconMap';

  export let id: string;
  export let tokens: Token[] = [];
  export let customTokens: Token[] = [];
  export let value: Maybe<Token> = null;
  export let menuOpen = false;
  export let modalOpen = false;
  export let selectToken: (token: Token) => void = noop;
  export let closeMenu: () => void = noop;

  const dispatch = createEventDispatcher();

  const showAddERC20 = () => {
    dispatch('closemenu');
    modalOpen = true;
  };

  const handleStorageChange = (newTokens: Token[]) => {
    customTokens = newTokens;
  };

  const onAccountChange = () => {
    if ($account?.address) {
      customTokens = tokenService.getTokens($account?.address as Address);
    }
  };

  const getTokenKeydownHandler = (token: Token) => {
    return (event: KeyboardEvent) => {
      if (event.key === 'Enter') {
        selectToken(token);
      }
    };
  };

  onMount(() => {
    tokenService.subscribeToChanges(handleStorageChange);
  });

  onDestroy(() => tokenService.unsubscribeFromChanges(handleStorageChange));
</script>

<!-- Mobile view -->
<dialog {id} class="modal modal-bottom" class:modal-open={menuOpen}>
  <div class="modal-box relative px-6 py-[35px] bg-neutral-background">
    <button class="absolute right-6 top-[35px]" on:click={closeMenu}>
      <Icon type="x-close" fillClass="fill-primary-icon" size={24} />
    </button>

    <h3 class="title-body-bold mb-7">{$t('token_dropdown.label')}</h3>

    <ul role="listbox" class="menu p-0 bg-neutral-background box-shadow-small">
      {#each tokens as token (token.symbol)}
        {@const selected = token === value}
        <!-- svelte-ignore a11y-click-events-have-key-events -->
        <li
          role="option"
          tabindex="0"
          aria-selected={selected}
          class="rounded-[10px]"
          class:bg-tertiary-interactive-accent={selected}
          on:click={() => selectToken(token)}>
          <div class="p-4">
            <i role="img" aria-label={token.name}>
              <svelte:component this={symbolToIconMap[token.symbol]} />
            </i>
            <span class="body-bold">{token.symbol}</span>
          </div>
        </li>
      {/each}
      {#each customTokens as token, index (index)}
        <li
          role="option"
          tabindex="0"
          aria-selected={token === value}
          on:click={() => selectToken(token)}
          on:keydown={getTokenKeydownHandler(token)}>
          <div class="p-4">
            <i role="img" aria-label={token.name}>
              <Erc20 />
            </i>
            <span class="body-bold">{token.symbol}</span>
          </div>
        </li>
      {/each}
      <div class="h-sep" />
      <li>
        <button on:click={showAddERC20} class="flex hover:bg-dark-5 justify-center items-center p-4 rounded-sm">
          <Icon type="plus-circle" fillClass="fill-primary-icon" size={20} vWidth={30} vHeight={30} />
          <span
            class="
            body-bold
            bg-transparent
            flex-1
            w-[100px]
            px-0
            pl-2">
            {$t('token_dropdown.add_custom')}
          </span>
        </button>
      </li>
    </ul>
  </div>
</dialog>

<AddCustomErc20 bind:modalOpen on:tokenRemoved />

<!-- <OnNetwork change={onNetworkChange} /> -->
<OnAccount change={onAccountChange} />
