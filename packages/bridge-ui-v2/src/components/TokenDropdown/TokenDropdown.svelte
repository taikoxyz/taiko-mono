<script lang="ts">
  import { type ComponentType, onDestroy, onMount } from 'svelte';
  import { noop } from 'svelte/internal';
  import { t } from 'svelte-i18n';

  import { BllIcon, EthIcon, HorseIcon, Icon } from '$components/Icon';
  import type { Token } from '$libs/token';
  import { classNames } from '$libs/util/classNames';
  import { uid } from '$libs/util/uid';

  export let tokens: Token[] = [];
  export let onChange: (token: Token) => void = noop;

  let symbolToIconMap: Record<string, ComponentType> = {
    ETH: EthIcon,
    BLL: BllIcon,
    HORSE: HorseIcon,
  };

  let dropdownId = `dropdown-${uid()}`;
  let selectedToken: Token;
  let menuOpen = false;

  $: menuClasses = classNames(
    'menu absolute right-0 w-[265px] p-3 mt-2 rounded-[10px] bg-neutral-background z-10',
    menuOpen ? 'visible opacity-100' : 'invisible opacity-0',
  );

  function closeMenu() {
    menuOpen = false;
  }

  function openMenu(event: Event) {
    // Prevents closing the menu immediately (button click bubbles up to the document)
    event.stopPropagation();
    menuOpen = true;
  }

  function selectToken(token: Token) {
    selectedToken = token;
    onChange?.(token); // TODO: data binding? 🤔
    closeMenu();
  }

  function onTokenKeydown(event: KeyboardEvent, token: Token) {
    if (event.key === 'Enter') {
      selectToken(token);
    }
  }

  onMount(() => {
    document.addEventListener('click', closeMenu);
  });

  onDestroy(() => {
    document.removeEventListener('click', closeMenu);
  });
</script>

<div class="relative">
  <button
    aria-haspopup="listbox"
    aria-controls={dropdownId}
    aria-expanded={menuOpen}
    class="w-full flex justify-between items-center px-6 py-[14px] input-box"
    on:click={openMenu}
    on:focus={openMenu}>
    <div class="space-x-2">
      {#if !selectedToken}
        <span class="title-subsection-bold text-tertiary-content leading-8">{$t('token_dropdown.placeholder')}…</span>
      {/if}
      {#if selectedToken}
        <div class="flex space-x-2 items-center">
          <i role="img" aria-label={selectedToken.name}>
            <svelte:component this={symbolToIconMap[selectedToken.symbol]} />
          </i>
          <span class="title-subsection-bold">{selectedToken.symbol}</span>
        </div>
      {/if}
    </div>
    <Icon type="chevron-down" />
  </button>

  <ul role="listbox" id={dropdownId} class={menuClasses}>
    {#each tokens as token (token.symbol)}
      <li
        role="option"
        tabindex="0"
        aria-selected={token === selectedToken}
        on:click={() => selectToken(token)}
        on:keydown={(event) => onTokenKeydown(event, token)}>
        <div class="p-4">
          <i role="img" aria-label={token.name}>
            <svelte:component this={symbolToIconMap[token.symbol]} />
          </i>
          <span class="body-bold">{token.symbol}</span>
        </div>
      </li>
    {/each}
  </ul>
</div>
