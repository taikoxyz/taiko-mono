<script lang="ts">
  import { type Address, getNetwork } from '@wagmi/core';
  import { onDestroy } from 'svelte';
  import { t } from 'svelte-i18n';

  import { DesktopOrLarger } from '$components/DesktopOrLarger';
  import { Icon } from '$components/Icon';
  import Erc20 from '$components/Icon/ERC20.svelte';
  import { warningToast } from '$components/NotificationToast';
  import { tokenService } from '$libs/storage/services';
  import { ETHToken, type Token } from '$libs/token';
  import { getCrossChainAddress } from '$libs/token/getCrossChainAddress';
  import { uid } from '$libs/util/uid';
  import { account } from '$stores/account';

  import { destNetwork } from '../Bridge/state';
  import DialogView from './DialogView.svelte';
  import DropdownView from './DropdownView.svelte';
  import { symbolToIconMap } from './symbolToIconMap';

  export let tokens: Token[] = [];
  export let value: Maybe<Token> = null;
  export let onlyMintable: boolean = false;

  let id = `menu-${uid()}`;
  let menuOpen = false;

  const customTokens = tokenService.getTokens($account?.address as Address);
  // This will control which view to render depending on the screensize.
  // Since markup will differ, and there is logic running when interacting
  // with this component, it makes more sense to not render the view that's
  // not being used, doing this with JS instead of CSS media queries
  let isDesktopOrLarger: boolean;

  const closeMenu = () => {
    menuOpen = false;
    removeListener();
  };

  const openMenu = (event: Event) => {
    event.stopPropagation();

    menuOpen = true;

    addListener();
  };

  let escKeyListener: (event: KeyboardEvent) => void;

  const addListener = () => {
    document.addEventListener('click', closeMenu, { once: true });
    escKeyListener = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        closeMenu();
      }
    };
    window.addEventListener('keydown', escKeyListener);
  };

  const removeListener = () => {
    window.removeEventListener('click', closeMenu);
    window.removeEventListener('keydown', escKeyListener);
  };

  const selectToken = async (token: Token) => {
    const { chain } = getNetwork();
    const destChain = $destNetwork;

    // In order to select a token, we only need the source chain to be selected,
    // unless it's an imported token...
    if (!chain) {
      warningToast({title: $t('messages.network.required')});
      return;
    }

    // if it is an imported Token, chances are we do not yet have the bridged address
    // for the destination chain, so we need to fetch it
    if (token.imported) {
      // ... in the case of imported tokens, we also require the destination chain to be selected.    if (!destChain) {
      if (!destChain) {
        warningToast({title: $t('messages.network.required_dest')});
        return;
      }

      let bridgedAddress = null;

      try {
        bridgedAddress = await getCrossChainAddress({
          token,
          srcChainId: chain.id,
          destChainId: destChain.id,
        });
      } catch (error) {
        console.error(error);
      }

      // only update the token if we actually have a new bridged address
      if (bridgedAddress && bridgedAddress !== token.addresses[destChain.id]) {
        token.addresses[destChain.id] = bridgedAddress as Address;

        tokenService.updateToken(token, $account?.address as Address);
      }
    }
    value = token;

    closeMenu();
  };

  const handleTokenRemoved = (event: { detail: { token: Token } }) => {
    // if the selected token is the one that was removed by the user, remove it
    if (event.detail.token === value) {
      value = ETHToken;
    }
  };

  onDestroy(() => closeMenu());
</script>

<DesktopOrLarger bind:is={isDesktopOrLarger} />

<div class="relative">
  <button
    aria-haspopup="listbox"
    aria-controls={id}
    aria-expanded={menuOpen}
    class="f-between-center w-full px-6 py-[14px] input-box bg-neutral-background border-0 shadow-none outline-none"
    on:click={openMenu}
    on:focus={openMenu}>
    <div class="space-x-2">
      {#if !value}
        <span class="title-subsection-bold text-secondary-content">{$t('token_dropdown.label')}</span>
      {/if}
      {#if value}
        <div class="flex space-x-2 items-center">
          <!-- Only match icons to configurd tokens -->
          {#if symbolToIconMap[value.symbol] && !value.imported}
            <i role="img" aria-label={value.name}>
              <svelte:component this={symbolToIconMap[value.symbol]} size={28} />
            </i>
          {:else}
            <i role="img" aria-label={value.symbol}>
              <svelte:component this={Erc20} size={28} />
            </i>
          {/if}
          <span class="title-subsection-bold">{value.symbol}</span>
        </div>
      {/if}
    </div>
    <Icon type="chevron-down" size={24} />
  </button>

  {#if isDesktopOrLarger}
    <DropdownView
      {id}
      {menuOpen}
      {onlyMintable}
      {tokens}
      {customTokens}
      {value}
      {selectToken}
      on:tokenRemoved={handleTokenRemoved} />
  {:else}
    <DialogView {id} {menuOpen} {onlyMintable} {tokens} {customTokens} {value} {selectToken} {closeMenu} />
  {/if}
</div>
