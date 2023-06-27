<script lang="ts">
  import type { ComponentType } from 'svelte';
  import { t } from 'svelte-i18n';

  import { BllIcon, EthIcon, HorseIcon, Icon } from '$components/Icon';

  export let tokens: Token[] = [];
  export let onChange: (token: Token) => void;

  let symbolToIconMap: Record<string, ComponentType> = {
    ETH: EthIcon,
    BLL: BllIcon,
    HORSE: HorseIcon,
  };

  let selectedToken: Token;

  function closeMenu() {
    if (document.activeElement instanceof HTMLElement) {
      document.activeElement.blur();
    }
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
</script>

<div class="dropdown dropdown-end">
  <button aria-haspopup="true" class="w-full flex justify-between items-center px-6 py-[14px] input-box">
    <div class="space-x-2">
      {#if !selectedToken}
        <span class="title-subsection-bold text-tertiary-content leading-8">{$t('bridge.select_token')}…</span>
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

  <ul role="listbox" class="menu dropdown-content w-[265px] p-3 mt-2 rounded-[10px] bg-neutral-background z-10">
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
