<script lang="ts">
  import { onDestroy } from 'svelte';
  import { t } from 'svelte-i18n';

  import { DesktopOrLarger } from '$components/DesktopOrLarger';
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

  // This will control which view to render depending on the screensize.
  // Since markup will differ, and there is logic running when interacting
  // with this component, it makes more sense to not render the view that's
  // not being used, doing this with JS instead of CSS media queries
  let isDesktopOrLarger: boolean;

  function closeMenu() {
    menuOpen = false;
  }

  function openMenu() {
    menuOpen = true;
  }

  function selectToken(token: Token) {
    value = token;
    closeMenu();
  }

  onDestroy(closeMenu);
</script>

<DesktopOrLarger bind:is={isDesktopOrLarger} />

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

  {#if isDesktopOrLarger}
    <DropdownView {id} {menuOpen} {tokens} {value} {selectToken} {closeMenu} />
  {:else}
    <DialogView {id} {menuOpen} {tokens} {value} {selectToken} {closeMenu} />
  {/if}
</div>
