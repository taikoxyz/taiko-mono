<script lang="ts">
  import { onDestroy, onMount } from 'svelte';
  import { t } from 'svelte-i18n';

  import { Icon } from '$components/Icon';
  import type { Token } from '$libs/token';
  import { uid } from '$libs/util/uid';

  import DialogView from './DialogView.svelte';
  import DropdownView from './DropdownView.svelte';
  import { symbolToIconMap } from './symbolToIconMap';

  export let tokens: Token[] = [];
  export let value: Maybe<Token> = null;

  let id = `menu-${uid()}`;
  let menuOpen = false;

  // Default to true if globalThis or matchMedia are not available (SSR?).
  // Desktop view looks also good in small screens.
  let isDesktopOrLarger = globalThis?.matchMedia?.('(min-width: 768px)').matches ?? true;

  function closeMenu() {
    menuOpen = false;
  }

  function openMenu(event: Event) {
    // Prevents closing the menu immediately (button click bubbles up to the document)
    event.stopPropagation();
    menuOpen = true;
  }

  function selectToken(token: Token) {
    value = token;
    closeMenu();
  }

  onMount(() => {
    document.addEventListener('click', closeMenu);
  });

  onDestroy(() => {
    closeMenu();
    document.removeEventListener('click', closeMenu);
  });
</script>

<div class="relative">
  <button
    aria-haspopup="listbox"
    aria-controls={id}
    aria-expanded={menuOpen}
    class="f-between-center w-full px-6 py-[14px] input-box"
    on:click={openMenu}
    on:focus={openMenu}>
    <div class="space-x-2">
      {#if !value}
        <span class="title-subsection-bold text-tertiary-content leading-8">{$t('token_dropdown.label')}</span>
      {/if}
      {#if value}
        <div class="flex space-x-2 items-center">
          <i role="img" aria-label={value.name}>
            <svelte:component this={symbolToIconMap[value.symbol]} />
          </i>
          <span class="title-subsection-bold">{value.symbol}</span>
        </div>
      {/if}
    </div>
    <Icon type="chevron-down" />
  </button>

  <!--
    TODO: does not change on resizing, but it's not a big deal since both
          views work well on small and large screens.
  -->
  {#if isDesktopOrLarger}
    <DropdownView {id} {menuOpen} {tokens} {value} {selectToken} />
  {:else}
    <DialogView {id} {menuOpen} {tokens} {value} {selectToken} {closeMenu} />
  {/if}
</div>
